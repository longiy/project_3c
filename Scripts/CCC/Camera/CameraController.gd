# CameraController.gd - UPDATED: Compatible with new Control module architecture
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

# UPDATED: Input system compatibility
var input_controller: InputController

func _ready():
	setup_camera_controller()
	setup_modules()
	setup_target()
	setup_input_system_integration()
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
	"""Initialize camera controller"""
	current_distance = default_distance
	target_distance = default_distance
	current_fov = default_fov
	target_fov = default_fov
	
	if not spring_arm:
		push_error("SpringArm3D not found! Camera will not work.")
		return
	
	if not camera:
		push_error("Camera3D not found! Camera will not work.")
		return
	
	spring_arm.spring_length = current_distance
	camera.fov = current_fov

func setup_modules():
	"""Create and setup camera modules"""
	# Create input module
	input_module = CameraInput.new()
	input_module.name = "CameraInput"
	input_module.setup_controller_reference(self)
	add_child(input_module)
	
	# Create responder module
	responder_module = CameraResponder.new()
	responder_module.name = "CameraResponder"
	responder_module.setup_controller_reference(self)
	add_child(responder_module)

func setup_target():
	"""Setup target following"""
	if not target_node:
		target_node = get_node_or_null("../CHARACTER")
		if target_node:
			print("✅ CameraController: Auto-detected target: ", target_node.name)
	
	if target_node:
		target_position = target_node.global_position
		global_position = target_position
		target_acquired.emit(target_node)

func setup_input_system_integration():
	"""UPDATED: Setup integration with new input system"""
	input_controller = get_node_or_null("../CHARACTER/InputController") as InputController
	if not input_controller:
		push_warning("CameraController: No InputController found - some features may not work")
		return
	
	print("✅ CameraController: Connected to InputController")

# === CAMERA MODE MANAGEMENT ===

func set_camera_mode(mode: CameraMode):
	"""Set camera mode and handle transitions"""
	if current_mode == mode:
		return
	
	var old_mode = current_mode
	current_mode = mode
	
	# Handle mode-specific setup
	match mode:
		CameraMode.ORBIT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			mouse_mode_changed.emit(true)
		CameraMode.CLICK_NAVIGATION:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			mouse_mode_changed.emit(false)
	
	camera_mode_changed.emit(get_mode_name(mode))
	print("🎥 Camera mode changed: ", get_mode_name(old_mode), " → ", get_mode_name(mode))

func toggle_camera_mode():
	"""Toggle between camera modes"""
	match current_mode:
		CameraMode.ORBIT:
			set_camera_mode(CameraMode.CLICK_NAVIGATION)
		CameraMode.CLICK_NAVIGATION:
			set_camera_mode(CameraMode.ORBIT)

func get_mode_name(mode: CameraMode) -> String:
	"""Get mode name for debugging"""
	match mode:
		CameraMode.ORBIT:
			return "ORBIT"
		CameraMode.CLICK_NAVIGATION:
			return "CLICK_NAVIGATION"
		_:
			return "UNKNOWN"

# === TARGET FOLLOWING ===

func update_target_following(delta: float):
	"""Update camera target following"""
	if not target_node:
		return
	
	var target_pos = target_node.global_position + Vector3(0, follow_height_offset, 0)
	target_position = target_position.lerp(target_pos, follow_smoothing * delta)
	global_position = target_position

# === CAMERA PROPERTIES ===

func update_camera_properties(delta: float):
	"""Update camera distance and FOV smoothing"""
	# Smooth distance
	current_distance = lerp(current_distance, target_distance, distance_smoothing * delta)
	spring_arm.spring_length = current_distance
	
	# Smooth FOV
	current_fov = lerp(current_fov, target_fov, fov_smoothing * delta)
	camera.fov = current_fov

func apply_camera_transforms():
	"""Apply rotation transforms to camera"""
	rotation.y = camera_rotation_y
	spring_arm.rotation.x = camera_rotation_x

# === INPUT HANDLING (Called by CameraInput module) ===

func apply_mouse_orbit(mouse_delta: Vector2, sensitivity: float, invert_y: bool):
	"""Apply mouse orbit movement"""
	var y_modifier = -1.0 if invert_y else 1.0
	
	camera_rotation_y -= mouse_delta.x * sensitivity
	camera_rotation_x = clamp(
		camera_rotation_x + mouse_delta.y * sensitivity * y_modifier,
		deg_to_rad(-80.0),
		deg_to_rad(50.0)
	)

func apply_zoom(zoom_delta: float):
	"""Apply zoom input"""
	target_distance = clamp(
		target_distance + zoom_delta,
		min_distance,
		max_distance
	)

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
	"""Get camera forward direction for character movement"""
	return -camera.global_transform.basis.z

func get_camera_right() -> Vector3:
	"""Get camera right direction for character movement"""
	return camera.global_transform.basis.x

# === UPDATED: Control System Integration ===

func notify_input_system_of_mode_change():
	"""UPDATED: Notify input system of camera mode changes"""
	if input_controller:
		input_controller.set_input_mode(get_mode_name(current_mode).to_lower())

# === STATE RESPONSES (Signal-driven) ===

func set_camera_fov(fov: float, transition_time: float = 0.0):
	"""Set camera FOV with optional transition"""
	target_fov = fov
	if transition_time <= 0:
		current_fov = fov
		camera.fov = fov

func set_camera_distance(distance: float, transition_time: float = 0.0):
	"""Set camera distance with optional transition"""
	target_distance = clamp(distance, min_distance, max_distance)
	if transition_time <= 0:
		current_distance = target_distance
		spring_arm.spring_length = current_distance

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
		"fov": current_fov,
		"input_controller_connected": input_controller != null
	}
