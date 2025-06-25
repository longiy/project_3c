# CameraRig.gd - Signal-based autonomous camera controller
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
@export var auto_find_character = true

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

@export_group("Camera Properties")
@export var default_fov = 75.0
@export var fov_smoothing = 5.0

@export_group("Component Control")
@export var enable_camera_rig = true

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
	
	print("📹 CameraRig: Initialized")

func setup_target():
	"""Setup target following"""
	if auto_find_character and not target_node:
		target_node = find_character_in_scene()
	
	if target_node:
		target_position = target_node.global_position + Vector3(0, follow_height_offset, 0)
		global_position = target_position
		target_acquired.emit(target_node)
		print("📹 CameraRig: Target acquired - ", target_node.name)
	else:
		print("📹 CameraRig: No target found")

func connect_signals():
	"""Connect to camera component signals"""
	# Components will connect to our signals in their _ready()
	pass

# === SIGNAL HANDLERS ===

func _on_look_input(delta: Vector2, sensitivity_multiplier: float = 1.0):
	"""Handle look input from action system"""
	if not enable_camera_rig or is_externally_controlled:
		return
	
	if not mouse_captured:
		return
	
	var effective_sensitivity = mouse_sensitivity * sensitivity_multiplier
	var look_delta = delta * effective_sensitivity
	
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

func _on_zoom_input(zoom_delta: float):
	"""Handle zoom input"""
	if not enable_camera_rig or is_externally_controlled:
		return
	
	target_distance = clamp(
		target_distance + zoom_delta,
		min_distance,
		max_distance
	)

func _on_mouse_toggle():
	"""Handle mouse capture toggle"""
	if is_externally_controlled:
		return
		
	mouse_captured = !mouse_captured
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if mouse_captured else Input.MOUSE_MODE_VISIBLE
	mouse_mode_changed.emit(mouse_captured)
	print("📹 CameraRig: Mouse ", "captured" if mouse_captured else "released")

func _on_target_changed(new_target: Node3D):
	"""Handle target change"""
	if target_node == new_target:
		return
		
	var old_target = target_node
	target_node = new_target
	
	if target_node:
		target_acquired.emit(target_node)
		print("📹 CameraRig: Target changed to ", target_node.name)
	else:
		target_lost.emit()
		print("📹 CameraRig: Target lost")

func _on_external_control_requested(active: bool, controller_name: String):
	"""Handle external control requests"""
	if active:
		external_controllers[controller_name] = true
		is_externally_controlled = true
		print("📹 CameraRig: External control taken by ", controller_name)
	else:
		external_controllers.erase(controller_name)
		is_externally_controlled = external_controllers.size() > 0
		if not is_externally_controlled:
			print("📹 CameraRig: External control released")

# === CAMERA PROPERTY CONTROL ===

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

func set_camera_position_override(position: Vector3):
	"""Override target position (for cinematic control)"""
	follow_target_override = position
	use_position_override = true

func clear_position_override():
	"""Clear position override and return to target following"""
	use_position_override = false

# === UPDATE LOOPS ===

func update_target_following(delta: float):
	"""Update camera position to follow target"""
	if is_externally_controlled and use_position_override:
		# Use override position
		global_position = global_position.lerp(follow_target_override, follow_smoothing * delta)
		return
	
	if not target_node:
		return
	
	# Follow target
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

# === UTILITY METHODS ===

func find_character_in_scene() -> Node3D:
	"""Auto-find character node in scene"""
	var scene_root = get_tree().current_scene
	if not scene_root:
		return null
		
	# Look for CharacterBody3D
	for child in scene_root.get_children():
		if child is CharacterBody3D:
			return child
			
	return null

func has_yaw_limits() -> bool:
	"""Check if yaw rotation has limits"""
	return use_rotation_limits and yaw_limit_min != yaw_limit_max

func has_pitch_limits() -> bool:
	"""Check if pitch rotation has limits"""
	return use_rotation_limits and pitch_limit_min != pitch_limit_max

# === PUBLIC API ===

func get_camera() -> Camera3D:
	"""Get camera node"""
	return camera

func get_spring_arm() -> SpringArm3D:
	"""Get spring arm node"""
	return spring_arm

func is_mouse_captured() -> bool:
	"""Check if mouse is captured"""
	return mouse_captured

func get_current_target() -> Node3D:
	"""Get current follow target"""
	return target_node

func set_enabled(enabled: bool):
	"""Enable/disable entire camera rig"""
	enable_camera_rig = enabled
	print("📹 CameraRig: ", "Enabled" if enabled else "Disabled")

func force_mouse_mode(captured: bool):
	"""Force mouse mode (for external controllers)"""
	mouse_captured = captured
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE
	mouse_mode_changed.emit(mouse_captured)

# === STATE EMISSION ===

func emit_camera_state():
	"""Emit current camera state for listeners"""
	var state_data = {
		"position": global_position,
		"rotation": rotation,
		"fov": current_fov,
		"distance": current_distance,
		"target": target_node,
		"mouse_captured": mouse_captured,
		"externally_controlled": is_externally_controlled,
		"active_controllers": external_controllers.keys()
	}
	camera_state_changed.emit(state_data)

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get debug information"""
	return {
		"enabled": enable_camera_rig,
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
