# CameraRig.gd - FIXED: Proper mode switching with visual feedback
extends Node3D
class_name CameraRig

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

@export_group("Mouse Look")
@export var mouse_sensitivity = 0.002
@export var invert_y = false

@export_group("Rotation Limits")
@export var pitch_limit_min = -80.0
@export var pitch_limit_max = 50.0

@export_group("Camera Distance")
@export var default_distance = 4.0
@export var min_distance = 1.0
@export var max_distance = 10.0
@export var distance_smoothing = 8.0
@export var scroll_zoom_speed = 0.5

@export_group("Camera Properties")
@export var default_fov = 75.0
@export var fov_smoothing = 5.0

@export_group("Control Modes")
@export var enable_camera_rig = true

# === CAMERA MODES ===
enum CameraMode {
	ORBIT,              # Default: Mouse orbits camera, WASD moves character
	CLICK_NAVIGATION    # Mouse2 toggle: Cursor visible, click to move
}

var current_mode: CameraMode = CameraMode.ORBIT

# === INTERNAL STATE ===
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

# Camera transform state
var camera_rotation_x = 0.0  # Pitch
var camera_rotation_y = 0.0  # Yaw

# Target following
var target_position = Vector3.ZERO

# Camera properties
var current_distance = 4.0
var target_distance = 4.0
var current_fov = 75.0
var target_fov = 75.0

# External control
var external_controllers: Dictionary = {}
var is_externally_controlled = false

# FIXED: Mode switching state
var mode_switch_cooldown = 0.0
var mode_switch_delay = 0.2

func _ready():
	setup_camera_rig()
	setup_target()
	set_camera_mode(CameraMode.ORBIT)

func _input(event):
	"""Handle camera input - FIXED mode switching"""
	if not enable_camera_rig or is_externally_controlled:
		return
	
	# FIXED: Global Mouse2 handling for mode switching
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if mode_switch_cooldown <= 0:
			toggle_camera_mode()
			mode_switch_cooldown = mode_switch_delay
		return
	
	# Process mode-specific input
	match current_mode:
		CameraMode.ORBIT:
			handle_orbit_input(event)
		CameraMode.CLICK_NAVIGATION:
			handle_click_nav_input(event)

func _physics_process(delta):
	if not enable_camera_rig:
		return
	
	# Update cooldown
	if mode_switch_cooldown > 0:
		mode_switch_cooldown -= delta
		
	update_target_following(delta)
	update_camera_properties(delta)
	apply_camera_transforms()

# === CAMERA MODE MANAGEMENT ===

func set_camera_mode(mode: CameraMode):
	"""Switch between camera modes - FIXED"""
	if current_mode == mode:
		return
	
	var old_mode = current_mode
	current_mode = mode
	
	match mode:
		CameraMode.ORBIT:
			setup_orbit_mode()
		CameraMode.CLICK_NAVIGATION:
			setup_click_navigation_mode()
	
	camera_mode_changed.emit(get_mode_name(mode))
	print("📹 Camera mode: ", get_mode_name(old_mode), " → ", get_mode_name(mode))

func toggle_camera_mode():
	"""Toggle between orbit and click navigation modes"""
	match current_mode:
		CameraMode.ORBIT:
			set_camera_mode(CameraMode.CLICK_NAVIGATION)
		CameraMode.CLICK_NAVIGATION:
			set_camera_mode(CameraMode.ORBIT)

func get_mode_name(mode: CameraMode) -> String:
	match mode:
		CameraMode.ORBIT:
			return "orbit"
		CameraMode.CLICK_NAVIGATION:
			return "click_navigation"
		_:
			return "unknown"

func setup_orbit_mode():
	"""Setup orbit camera mode - FIXED"""
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	mouse_mode_changed.emit(true)
	print("📹 ORBIT MODE: Mouse captured, camera orbits")

func setup_click_navigation_mode():
	"""Setup click navigation mode - FIXED"""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	mouse_mode_changed.emit(false)
	print("📹 CLICK NAV MODE: Mouse visible, click to move")

# === ORBIT MODE INPUT ===

func handle_orbit_input(event: InputEvent):
	"""Handle input in orbit mode - mouse captured"""
	# Mouse look for camera orbit
	if event is InputEventMouseMotion:
		handle_mouse_orbit(event.relative)
	
	# Zoom
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				handle_zoom_direct(-scroll_zoom_speed)
			MOUSE_BUTTON_WHEEL_DOWN:
				handle_zoom_direct(scroll_zoom_speed)

func handle_mouse_orbit(mouse_delta: Vector2):
	"""Handle mouse orbit around character"""
	var look_delta = mouse_delta * mouse_sensitivity
	
	if invert_y:
		look_delta.y = -look_delta.y
	
	# Apply rotation
	camera_rotation_y -= look_delta.x
	camera_rotation_x = clamp(
		camera_rotation_x - look_delta.y,
		deg_to_rad(pitch_limit_min),
		deg_to_rad(pitch_limit_max)
	)

# === CLICK NAVIGATION MODE INPUT ===

func handle_click_nav_input(event: InputEvent):
	"""Handle input in click navigation mode - FIXED"""
	# Still allow zoom in click nav mode
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				handle_zoom_direct(-scroll_zoom_speed)
			MOUSE_BUTTON_WHEEL_DOWN:
				handle_zoom_direct(scroll_zoom_speed)
	
	# NOTE: Mouse clicks and motion are now handled by InputManager
	# This method only handles camera-specific input in click nav mode

# === CAMERA CONTROL ===

func handle_zoom_direct(zoom_delta: float):
	"""Handle zoom in any mode"""
	target_distance = clamp(
		target_distance + zoom_delta,
		min_distance,
		max_distance
	)

# === SETUP ===

func setup_camera_rig():
	"""Initialize camera rig components"""
	if not spring_arm or not camera:
		push_error("CameraRig: Missing SpringArm3D or Camera3D children")
		return
	
	# Initialize values
	camera_rotation_x = deg_to_rad(-20.0)  # Start looking slightly down
	camera_rotation_y = 0.0
	
	current_distance = default_distance
	target_distance = default_distance
	spring_arm.spring_length = current_distance
	
	current_fov = default_fov
	target_fov = default_fov
	camera.fov = current_fov

func setup_target():
	"""Setup target following"""
	if target_node:
		target_position = target_node.global_position + Vector3(0, follow_height_offset, 0)
		global_position = target_position
		target_acquired.emit(target_node)

# === UPDATE LOOPS ===

func update_target_following(delta: float):
	"""Update camera position to follow target"""
	if not target_node:
		return
	
	var desired_position = target_node.global_position + Vector3(0, follow_height_offset, 0)
	target_position = target_position.lerp(desired_position, follow_smoothing * delta)
	global_position = target_position

func update_camera_properties(delta: float):
	"""Update camera distance and FOV with smoothing"""
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

# === REACTIVE CONTROL (Signal-Driven) ===

func set_camera_fov(fov: float, transition_time: float = 0.0):
	"""Set camera FOV with optional transition (signal-driven)"""
	target_fov = fov
	if transition_time <= 0:
		current_fov = fov
		camera.fov = fov

func set_camera_distance(distance: float, transition_time: float = 0.0):
	"""Set camera distance with optional transition (signal-driven)"""
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
	"""Get camera forward direction for character movement"""
	return -camera.global_transform.basis.z

func get_camera_right() -> Vector3:
	"""Get camera right direction for character movement"""
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
