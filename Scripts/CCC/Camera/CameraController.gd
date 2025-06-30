# CameraController.gd - Main camera coordinator (modular refactor)
extends Node3D
class_name CameraController

# === SIGNALS ===
signal camera_mode_changed(mode: String)
signal mouse_mode_changed(captured: bool)
signal target_lost()
signal target_acquired(target: Node3D)

# === EXPORTS ===
@export_group("Target Following")
@export var target_node: Node3D
@export var follow_height_offset = 1.6
@export var follow_smoothing = 8.0

@export_group("Camera Distance")
@export var default_distance = 4.0
@export var min_distance = 1.0
@export var max_distance = 10.0
@export var distance_smoothing = 8.0

@export_group("Camera Properties")
@export var default_fov = 75.0
@export var fov_smoothing = 5.0

@export_group("Control")
@export var enable_camera_rig = true

# === CAMERA MODES ===
enum CameraMode {
	ORBIT,
	CLICK_NAVIGATION
}

var current_mode: CameraMode = CameraMode.ORBIT

# === COMPONENTS ===
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

var input_module: CameraInput
var responder_module: CameraResponder

# === INTERNAL STATE ===
var camera_rotation_x = 0.0
var camera_rotation_y = 0.0
var target_position = Vector3.ZERO
var current_distance = 4.0
var target_distance = 4.0
var current_fov = 75.0
var target_fov = 75.0

# External control
var external_controllers: Dictionary = {}
var is_externally_controlled = false

# Mode switching state
var mode_switch_cooldown = 0.0
var mode_switch_delay = 0.2

func _ready():
	setup_camera_controller()
	setup_modules()
	setup_target()
	set_camera_mode(CameraMode.ORBIT)

func _input(event):
	if input_module:
		input_module.handle_input(event)

func _process(delta):
	if mode_switch_cooldown > 0:
		mode_switch_cooldown -= delta
	
	update_target_following(delta)
	update_camera_properties(delta)
	apply_camera_transforms()

# === SETUP ===

func setup_camera_controller():
	if not spring_arm or not camera:
		push_error("CameraController: Missing SpringArm3D or Camera3D children")
		return
	
	# Initialize values
	camera_rotation_x = deg_to_rad(-20.0)
	camera_rotation_y = 0.0
	
	current_distance = default_distance
	target_distance = default_distance
	spring_arm.spring_length = current_distance
	
	current_fov = default_fov
	target_fov = default_fov
	camera.fov = current_fov

func setup_modules():
	# Create and add modules
	input_module = CameraInput.new()
	input_module.name = "CameraInput"
	input_module.setup_controller_reference(self)
	add_child(input_module)
	
	responder_module = CameraResponder.new()
	responder_module.name = "CameraResponder"
	responder_module.setup_controller_reference(self)
	add_child(responder_module)

func setup_target():
	if target_node:
		target_position = target_node.global_position + Vector3(0, follow_height_offset, 0)
		global_position = target_position
		target_acquired.emit(target_node)

# === CORE CAMERA LOGIC ===

func update_target_following(delta: float):
	if not target_node:
		return
	
	var desired_position = target_node.global_position + Vector3(0, follow_height_offset, 0)
	target_position = target_position.lerp(desired_position, follow_smoothing * delta)
	global_position = target_position

func update_camera_properties(delta: float):
	# Smooth distance
	current_distance = lerp(current_distance, target_distance, distance_smoothing * delta)
	spring_arm.spring_length = current_distance
	
	# Smooth FOV
	current_fov = lerp(current_fov, target_fov, fov_smoothing * delta)
	camera.fov = current_fov

func apply_camera_transforms():
	rotation.y = camera_rotation_y
	spring_arm.rotation.x = camera_rotation_x

# === MODE MANAGEMENT ===

func toggle_camera_mode():
	if mode_switch_cooldown > 0:
		return
	
	match current_mode:
		CameraMode.ORBIT:
			set_camera_mode(CameraMode.CLICK_NAVIGATION)
		CameraMode.CLICK_NAVIGATION:
			set_camera_mode(CameraMode.ORBIT)
	
	mode_switch_cooldown = mode_switch_delay

func set_camera_mode(mode: CameraMode):
	if current_mode == mode:
		return
	
	var old_mode_name = get_mode_name(current_mode)
	current_mode = mode
	var new_mode_name = get_mode_name(current_mode)
	
	match current_mode:
		CameraMode.ORBIT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			print("📹 CameraController: Switched to ORBIT mode")
		CameraMode.CLICK_NAVIGATION:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			print("📹 CameraController: Switched to CLICK_NAVIGATION mode")
	
	camera_mode_changed.emit(new_mode_name)
	mouse_mode_changed.emit(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)

func get_mode_name(mode: CameraMode) -> String:
	match mode:
		CameraMode.ORBIT:
			return "ORBIT"
		CameraMode.CLICK_NAVIGATION:
			return "CLICK_NAVIGATION"
		_:
			return "UNKNOWN"

# === CAMERA CONTROL API (Called by modules) ===

func apply_mouse_orbit(mouse_delta: Vector2, sensitivity: float, invert_y: bool):
	var look_delta = mouse_delta * sensitivity
	
	if invert_y:
		look_delta.y = -look_delta.y
	
	camera_rotation_y -= look_delta.x
	camera_rotation_x = clamp(
		camera_rotation_x - look_delta.y,
		deg_to_rad(-80.0),
		deg_to_rad(50.0)
	)

func apply_zoom(zoom_delta: float):
	target_distance = clamp(
		target_distance + zoom_delta,
		min_distance,
		max_distance
	)

func set_camera_fov(fov: float, transition_time: float = 0.0):
	target_fov = fov
	if transition_time <= 0:
		current_fov = fov
		camera.fov = fov

func set_camera_distance(distance: float, transition_time: float = 0.0):
	target_distance = clamp(distance, min_distance, max_distance)
	if transition_time <= 0:
		current_distance = target_distance
		spring_arm.spring_length = current_distance

# === PUBLIC API ===

func get_camera() -> Camera3D:
	return camera

func get_current_mode() -> CameraMode:
	return current_mode

func is_in_orbit_mode() -> bool:
	return current_mode == CameraMode.ORBIT

func is_in_click_navigation_mode() -> bool:
	return current_mode == CameraMode.CLICK_NAVIGATION

func get_camera_forward() -> Vector3:
	return -camera.global_transform.basis.z

func get_camera_right() -> Vector3:
	return camera.global_transform.basis.x

# === DEBUG INFO ===

func get_camera_debug_info() -> Dictionary:
	return {
		"enabled": enable_camera_rig,
		"follow_mode": get_mode_name(current_mode),
		"is_following": target_node != null,
		"mouse_captured": Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,
		"current_distance": current_distance,
		"external_control": is_externally_controlled,
		"position": global_position,
		"rotation_deg": Vector2(rad_to_deg(camera_rotation_x), rad_to_deg(camera_rotation_y)),
		"fov": current_fov
	}
