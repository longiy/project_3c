# CameraRig.gd - Enhanced for direct state machine connection
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

@export_group("State Response Values")
@export var idle_fov = 50.0
@export var idle_distance = 4.0
@export var walking_fov = 60.0
@export var walking_distance = 4.0
@export var running_fov = 70.0
@export var running_distance = 4.5
@export var jumping_fov = 85.0
@export var jumping_distance = 4.8
@export var airborne_fov = 90.0
@export var airborne_distance = 5.0
@export var landing_fov = 75.0
@export var landing_distance = 4.0

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

var character_state_machine: CharacterStateMachine

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

# Mode switching state
var mode_switch_cooldown = 0.0
var mode_switch_delay = 0.2

# NEW: State response system
var current_state_tween: Tween

func _ready():
	setup_camera_rig()
	setup_target()
	set_camera_mode(CameraMode.ORBIT)
	connect_to_state_machine()

func _input(event):
	"""Handle camera input"""
	if not enable_camera_rig or is_externally_controlled:
		return
	
	# Handle mode switching
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if mode_switch_cooldown <= 0:
			toggle_camera_mode()
			mode_switch_cooldown = mode_switch_delay
	
	# Handle input based on current mode
	match current_mode:
		CameraMode.ORBIT:
			handle_orbit_input(event)
		CameraMode.CLICK_NAVIGATION:
			handle_click_nav_input(event)

func _process(delta):
	if mode_switch_cooldown > 0:
		mode_switch_cooldown -= delta
	
	update_target_following(delta)
	update_camera_properties(delta)
	apply_camera_transforms()

func connect_to_state_machine():
	"""Find and connect to character state machine"""
	# Try to find automatically
	character_state_machine = get_node_or_null("../CHARACTER/CharacterStateMachine") as CharacterStateMachine
	
	if character_state_machine:
		character_state_machine.state_changed_for_camera.connect(_on_character_state_changed)
		print("✅ CameraRig: Connected to CharacterStateMachine")
	else:
		print("⚠️ CameraRig: CharacterStateMachine not found")
		
func _on_character_state_changed(state_name: String):
	"""Respond to character state changes"""
	var camera_data = get_camera_data_for_state(state_name)
	respond_to_character_state(state_name, camera_data.fov, camera_data.distance, camera_data.transition_time)

func get_camera_data_for_state(state_name: String) -> Dictionary:
	"""Get camera response data for a state"""
	match state_name:
		"idle":
			return {"fov": idle_fov, "distance": idle_distance, "transition_time": 0.3}
		"walking":
			return {"fov": walking_fov, "distance": walking_distance, "transition_time": 0.3}
		"running":
			return {"fov": running_fov, "distance": running_distance, "transition_time": 0.3}
		"jumping":
			return {"fov": jumping_fov, "distance": jumping_distance, "transition_time": 0.1}
		"airborne":
			return {"fov": airborne_fov, "distance": airborne_distance, "transition_time": 0.3}
		"landing":
			return {"fov": landing_fov, "distance": landing_distance, "transition_time": 0.1}
		_:
			return {"fov": default_fov, "distance": default_distance, "transition_time": 0.3}

# === NEW: DIRECT STATE RESPONSE METHODS ===

func respond_to_character_state(state_name: String, fov: float, distance: float, transition_time: float = 0.3):
	"""Respond directly to character state changes"""
	if not enable_camera_rig:
		return
	
	# Cancel any existing state tween
	if current_state_tween:
		current_state_tween.kill()
	
	# Create new tween for state response
	current_state_tween = create_tween()
	current_state_tween.set_parallel(true)
	
	# Tween FOV
	var fov_tween = current_state_tween.tween_method(
		_set_fov_direct,
		current_fov,
		fov,
		transition_time
	)
	fov_tween.set_ease(Tween.EASE_OUT)
	
	# Tween distance
	var distance_tween = current_state_tween.tween_method(
		_set_distance_direct,
		current_distance,
		distance,
		transition_time
	)
	distance_tween.set_ease(Tween.EASE_OUT)
	
	print("📹 CameraRig: State response '", state_name, "' - FOV:", fov, " Distance:", distance)

func tween_to_fov(fov: float, transition_time: float = 0.3):
	"""Tween camera FOV smoothly"""
	if current_state_tween:
		current_state_tween.kill()
	
	current_state_tween = create_tween()
	current_state_tween.tween_method(_set_fov_direct, current_fov, fov, transition_time)

func tween_to_distance(distance: float, transition_time: float = 0.3):
	"""Tween camera distance smoothly"""
	if current_state_tween:
		current_state_tween.kill()
	
	current_state_tween = create_tween()
	current_state_tween.tween_method(_set_distance_direct, current_distance, distance, transition_time)

func _set_fov_direct(fov: float):
	"""Direct FOV setter for tweening"""
	current_fov = fov
	target_fov = fov
	camera.fov = fov

func _set_distance_direct(distance: float):
	"""Direct distance setter for tweening"""
	current_distance = clamp(distance, min_distance, max_distance)
	target_distance = current_distance
	spring_arm.spring_length = current_distance

# === MODE SWITCHING ===

func toggle_camera_mode():
	"""Toggle between orbit and click navigation modes"""
	match current_mode:
		CameraMode.ORBIT:
			set_camera_mode(CameraMode.CLICK_NAVIGATION)
		CameraMode.CLICK_NAVIGATION:
			set_camera_mode(CameraMode.ORBIT)

func set_camera_mode(mode: CameraMode):
	"""Set camera mode and update input handling"""
	if current_mode == mode:
		return
	
	var old_mode_name = get_mode_name(current_mode)
	current_mode = mode
	var new_mode_name = get_mode_name(current_mode)
	
	match current_mode:
		CameraMode.ORBIT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			print("📹 CameraRig: Switched to ORBIT mode - Mouse captured")
		
		CameraMode.CLICK_NAVIGATION:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			print("📹 CameraRig: Switched to CLICK_NAVIGATION mode - Mouse visible")
	
	camera_mode_changed.emit(new_mode_name)
	mouse_mode_changed.emit(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)

func get_mode_name(mode: CameraMode) -> String:
	"""Get string name for camera mode"""
	match mode:
		CameraMode.ORBIT:
			return "ORBIT"
		CameraMode.CLICK_NAVIGATION:
			return "CLICK_NAVIGATION"
		_:
			return "UNKNOWN"

# === INPUT HANDLING ===

func handle_orbit_input(event: InputEvent):
	"""Handle input in orbit mode"""
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		handle_mouse_orbit(event.relative)
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				handle_zoom_direct(-scroll_zoom_speed)
			MOUSE_BUTTON_WHEEL_DOWN:
				handle_zoom_direct(scroll_zoom_speed)

func handle_click_nav_input(event: InputEvent):
	"""Handle input in click navigation mode"""
	if event is InputEventMouseButton and event.pressed:
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
		"fov": current_fov,
		"has_state_tween": current_state_tween != null and current_state_tween.is_valid()
	}
