# CameraRig.gd - Hybrid camera controller (Direct Input + Signals)
extends Node3D
class_name CameraRig

# === SIGNALS ===
signal camera_state_changed(camera_data: Dictionary)
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
@export var yaw_limit_min = 0.0
@export var yaw_limit_max = 0.0
@export var use_rotation_limits = false

@export_group("Camera Distance")
@export var default_distance = 4.0
@export var min_distance = 1.0
@export var max_distance = 10.0
@export var distance_smoothing = 8.0
@export var scroll_zoom_speed = 0.5

@export_group("Camera Properties")
@export var default_fov = 75.0
@export var fov_smoothing = 5.0

@export_group("Component Control")
@export var enable_camera_rig = true
@export var enable_direct_input = true

# === INTERNAL STATE ===
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

# Camera transform state
var camera_rotation_x = 0.0  # Pitch
var camera_rotation_y = 0.0  # Yaw
var mouse_captured = false

# Target following
var target_position = Vector3.ZERO
var follow_target_override = Vector3.ZERO
var use_position_override = false

# Camera properties
var current_distance = 4.0
var target_distance = 4.0
var current_fov = 75.0
var target_fov = 75.0

# External control
var external_controllers: Dictionary = {}
var is_externally_controlled = false

func _ready():
	setup_camera_rig()
	setup_target()
	connect_signals()
	
	# DEBUG: Check if everything is working
	print("📹 CameraRig Debug:")
	print("  - Target node: ", target_node)
	print("  - Spring arm: ", spring_arm)
	print("  - Camera: ", camera)
	print("  - Mouse captured: ", mouse_captured)
	print("  - Enable camera rig: ", enable_camera_rig)
	print("  - Enable direct input: ", enable_direct_input)
	
	# Force mouse capture for testing (remove later)
	mouse_captured = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	print("  - Forced mouse capture for testing")

func _input(event):
	"""DIRECT INPUT - Immediate response for mouse controls"""
	if not enable_camera_rig or not enable_direct_input or is_externally_controlled:
		return
	
	# DEBUG: Print input events
	if event is InputEventMouseMotion:
		print("📹 Mouse motion: ", event.relative, " captured: ", mouse_captured)
	
	# Mouse look - IMMEDIATE processing
	if event is InputEventMouseMotion and mouse_captured:
		handle_mouse_look_direct(event.relative)
		print("📹 Processing mouse look: ", event.relative)
	
	# Zoom - IMMEDIATE processing
	elif event is InputEventMouseButton and event.pressed:
		print("📹 Mouse button: ", event.button_index)
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				handle_zoom_direct(-scroll_zoom_speed)
				print("📹 Zoom in")
			MOUSE_BUTTON_WHEEL_DOWN:
				handle_zoom_direct(scroll_zoom_speed)
				print("📹 Zoom out")
	
	# Mouse toggle - IMMEDIATE processing
	elif event.is_action_pressed("toggle_mouse_look"):
		handle_mouse_toggle_direct()
		print("📹 Mouse toggle pressed")

func _physics_process(delta):
	if not enable_camera_rig:
		return
		
	update_target_following(delta)
	update_camera_properties(delta)
	apply_camera_transforms()

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
	
	# Initialize mouse capture
	mouse_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func setup_target():
	"""Setup target following"""
	if target_node:
		target_position = target_node.global_position + Vector3(0, follow_height_offset, 0)
		global_position = target_position
		target_acquired.emit(target_node)

func connect_signals():
	"""Connect to external signals (for reactive responses)"""
	# CameraStateResponder will connect to our signals
	pass

# === DIRECT INPUT HANDLERS (Immediate Response) ===

func handle_mouse_look_direct(mouse_delta: Vector2):
	"""Handle mouse look with immediate response"""
	var effective_sensitivity = mouse_sensitivity
	var look_delta = mouse_delta * effective_sensitivity
	
	if invert_y:
		look_delta.y = -look_delta.y
	
	# Apply yaw (horizontal)
	if not has_yaw_limits():
		camera_rotation_y -= look_delta.x
	else:
		camera_rotation_y = clamp(
			camera_rotation_y - look_delta.x,
			deg_to_rad(yaw_limit_min),
			deg_to_rad(yaw_limit_max)
		)
	
	# Apply pitch (vertical)
	camera_rotation_x = clamp(
		camera_rotation_x - look_delta.y,
		deg_to_rad(pitch_limit_min),
		deg_to_rad(pitch_limit_max)
	)

func handle_zoom_direct(zoom_delta: float):
	"""Handle zoom with immediate response"""
	target_distance = clamp(
		target_distance + zoom_delta,
		min_distance,
		max_distance
	)

func handle_mouse_toggle_direct():
	"""Handle mouse capture toggle with immediate response"""
	mouse_captured = !mouse_captured
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if mouse_captured else Input.MOUSE_MODE_VISIBLE
	mouse_mode_changed.emit(mouse_captured)

# === SIGNAL-BASED HANDLERS (For External Control) ===

func _on_look_input(delta: Vector2, sensitivity_multiplier: float = 1.0):
	"""Handle look input from external systems (legacy API)"""
	if not enable_camera_rig or is_externally_controlled:
		return
	
	# Use the direct handler with sensitivity multiplier
	handle_mouse_look_direct(delta * sensitivity_multiplier)

func _on_zoom_input(zoom_delta: float):
	"""Handle zoom input from external systems (legacy API)"""
	if not enable_camera_rig or is_externally_controlled:
		return
	
	handle_zoom_direct(zoom_delta)

func _on_mouse_toggle():
	"""Handle mouse toggle from external systems (legacy API)"""
	if is_externally_controlled:
		return
	
	handle_mouse_toggle_direct()

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

func set_camera_position_override(position: Vector3):
	"""Override target position (for external control)"""
	follow_target_override = position
	use_position_override = true

func clear_position_override():
	"""Clear position override and return to target following"""
	use_position_override = false

# === UPDATE LOOPS ===

func update_target_following(delta: float):
	"""Update camera position to follow target"""
	if is_externally_controlled and use_position_override:
		global_position = global_position.lerp(follow_target_override, follow_smoothing * delta)
		return
	
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

# === EXTERNAL CONTROL ===

func _on_target_changed(new_target: Node3D):
	"""Handle target change (signal-driven)"""
	if target_node == new_target:
		return
		
	var old_target = target_node
	target_node = new_target
	
	if target_node:
		target_acquired.emit(target_node)
	else:
		target_lost.emit()

func _on_external_control_requested(active: bool, controller_name: String):
	"""Handle external control requests (signal-driven)"""
	if active:
		external_controllers[controller_name] = true
		is_externally_controlled = true
	else:
		external_controllers.erase(controller_name)
		is_externally_controlled = external_controllers.size() > 0

# === UTILITY METHODS ===

func has_yaw_limits() -> bool:
	return use_rotation_limits and yaw_limit_min != yaw_limit_max

func has_pitch_limits() -> bool:
	return use_rotation_limits and pitch_limit_min != pitch_limit_max

# === PUBLIC API ===

func get_camera() -> Camera3D:
	return camera

func get_spring_arm() -> SpringArm3D:
	return spring_arm

func is_mouse_captured() -> bool:
	return mouse_captured

func get_current_target() -> Node3D:
	return target_node

func set_enabled(enabled: bool):
	enable_camera_rig = enabled

func set_direct_input_enabled(enabled: bool):
	"""Enable/disable direct input processing"""
	enable_direct_input = enabled

func force_mouse_mode(captured: bool):
	"""Force mouse mode (for external controllers)"""
	mouse_captured = captured
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE
	mouse_mode_changed.emit(mouse_captured)

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	return {
		"enabled": enable_camera_rig,
		"direct_input": enable_direct_input,
		"target": target_node.name if target_node else "None",
		"mouse_captured": mouse_captured,
		"external_control": is_externally_controlled,
		"controllers": external_controllers.keys(),
		"position": global_position,
		"rotation_deg": Vector2(rad_to_deg(camera_rotation_x), rad_to_deg(camera_rotation_y)),
		"fov": current_fov,
		"distance": current_distance,
		"following_override": use_position_override
	}
