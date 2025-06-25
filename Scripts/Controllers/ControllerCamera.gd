# ControllerCamera.gd - Modular camera controller with signal-based dependencies
extends Node3D

# Core signals for modular communication
signal mouse_mode_changed(is_captured: bool)
signal camera_state_changed(state_data: Dictionary)
signal follow_mode_changed(mode: int)

@export_group("Target & Following")
@export var target_character: CharacterBody3D
@export var camera_height = 1.6
@export var follow_smoothing = 8.0

@export_subgroup("Follow Behavior")
@export_enum("Immediate", "Delayed", "Manual") var follow_mode = 0
@export var movement_start_delay = 0.0
@export var movement_stop_delay = 0.0
@export var movement_threshold = 0.2
@export var snap_back_speed = 15.0

@export_group("Mouse Controls")
@export var mouse_sensitivity = 0.002

@export_subgroup("Yaw (Horizontal)")
@export var yaw_limit_min = 0.0
@export var yaw_limit_max = 0.0
@export var use_world_space_yaw = false

@export_subgroup("Pitch (Vertical)")
@export var pitch_limit_min = -80.0
@export var pitch_limit_max = 50.0
@export var use_world_space_pitch = false

@export_group("Camera Distance")
@export var enable_scroll_zoom = true
@export var min_distance = 1.0
@export var max_distance = 10.0
@export var scroll_speed = 0.5
@export var distance_smoothing = 8.0

@export_group("Camera Offset")
@export var camera_offset = Vector3.ZERO
@export var offset_smoothing = 0
@export var enable_dynamic_offset = false

@export_group("Modular Components")
@export var enable_camera_controller = true

@onready var spring_arm = $SpringArm3D
@onready var camera = $SpringArm3D/Camera3D

var character: CharacterBody3D
var mouse_delta = Vector2.ZERO
var camera_rotation_x = 0.0
var camera_rotation_y = 0.0
var is_mouse_captured = true
var target_distance = 4.0
var current_distance = 4.0
var current_offset = Vector3.ZERO
var base_target_distance = 4.0

# Modular control flags
var external_control_active = false
var input_override_active = false
var follow_override_active = false

# Follow delay system
var is_character_moving = false
var was_character_moving = false
var movement_change_time = 0.0
var follow_target_position = Vector3.ZERO
var is_following = true
var follow_just_enabled = false

func _ready():
	character = target_character
	if not character:
		push_error("No target character assigned to camera!")
		return
	
	# Initialize mouse capture
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	is_mouse_captured = true
	
	# Initialize camera
	camera_rotation_x = deg_to_rad(-20.0)
	camera_rotation_y = 0.0
	target_distance = spring_arm.spring_length
	current_distance = target_distance
	current_offset = camera_offset
	
	if character:
		var initial_pos = character.global_position + Vector3(0, camera_height, 0)
		global_position = initial_pos
		follow_target_position = initial_pos
	
	base_target_distance = target_distance
	
	# Emit initial state for any listening components
	emit_camera_state()

func _input(event):
	if not enable_camera_controller or input_override_active:
		return
	
	# Toggle mouse capture
	if event.is_action_pressed("toggle_mouse_look"):
		toggle_mouse_mode()
			
	# Zoom control
	if enable_scroll_zoom and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			target_distance = clamp(target_distance - scroll_speed, min_distance, max_distance)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			target_distance = clamp(target_distance + scroll_speed, min_distance, max_distance)
	
	# Mouse look when captured
	if is_mouse_captured and event is InputEventMouseMotion:
		mouse_delta = event.relative

func _physics_process(delta):
	if not character or not enable_camera_controller:
		if not character:
			print("📹 Camera: No character in _physics_process")
		if not enable_camera_controller:
			print("📹 Camera: Controller disabled in _physics_process")
		return
		
	# Handle mouse look rotation
	if is_mouse_captured and mouse_delta.length() > 0 and not input_override_active:
		handle_mouse_look()
		mouse_delta = Vector2.ZERO
	
	# Handle follow behavior
	if not follow_override_active:
		match follow_mode:
			0: # Immediate
				update_immediate_follow(delta)
			1: # Delayed
				update_follow_with_delay(delta)
			2: # Manual
				pass
	
	# Always update camera properties (these work even with overrides)
	update_camera_distance(delta)
	update_camera_offset(delta)
	update_spring_arm_rotation()

# === MODULAR CONTROL API ===

func set_external_control(active: bool, control_type: String = ""):
	"""Allow external components to take control"""
	print("📹 Camera: set_external_control called - active: ", active, " type: ", control_type)
	
	match control_type:
		"input":
			input_override_active = active
		"follow":
			follow_override_active = active
		"full", "":
			external_control_active = active
			input_override_active = active
			follow_override_active = active
	
	# When releasing control, ensure we restore proper state
	if not active:
		# Force refresh mouse state from actual Input
		var actual_mouse_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		if actual_mouse_captured != is_mouse_captured:
			is_mouse_captured = actual_mouse_captured
			print("📹 Camera: Synced mouse state - captured: ", is_mouse_captured)
			mouse_mode_changed.emit(is_mouse_captured)
		
		# Reset follow mode if it was overridden
		if control_type == "follow" or control_type == "full" or control_type == "":
			follow_just_enabled = true
			print("📹 Camera: Follow re-enabled")
	
	if active:
		print("📹 Camera: External control activated (", control_type, ")")
	else:
		print("📹 Camera: External control released (", control_type, ")")
	
	emit_camera_state()


func is_externally_controlled() -> bool:
	"""Check if camera is under external control"""
	return external_control_active

func get_control_status() -> Dictionary:
	"""Get detailed control status for debugging"""
	return {
		"external_control": external_control_active,
		"input_override": input_override_active,
		"follow_override": follow_override_active,
		"mouse_captured": is_mouse_captured,
		"follow_mode": follow_mode,
		"enabled": enable_camera_controller
	}

# === COMPONENT ENABLE/DISABLE API ===

func set_enabled(enabled: bool):
	"""Enable/disable the entire camera controller"""
	enable_camera_controller = enabled
	if not enabled:
		print("📹 Camera: Controller disabled")
	else:
		print("📹 Camera: Controller enabled")

func is_enabled() -> bool:
	return enable_camera_controller

# === SIGNAL EMISSION HELPERS ===

func refresh_mouse_state():
	"""Refresh mouse capture state - called when external control is released"""
	var new_mouse_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	print("📹 Camera: refresh_mouse_state called - current: ", is_mouse_captured, " actual: ", new_mouse_captured)
	
	if new_mouse_captured != is_mouse_captured:
		is_mouse_captured = new_mouse_captured
		mouse_mode_changed.emit(is_mouse_captured)
		emit_camera_state()
		print("📹 Camera: Refreshed mouse state - captured: ", is_mouse_captured)

func emit_camera_state():
	"""Emit current camera state for listening components"""
	var state_data = {
		"position": global_position,
		"rotation": rotation,
		"fov": camera.fov if camera else 75.0,
		"distance": current_distance,
		"offset": current_offset,
		"follow_mode": follow_mode,
		"external_control": external_control_active,
		"mouse_captured": is_mouse_captured
	}
	camera_state_changed.emit(state_data)

func toggle_mouse_mode():
	is_mouse_captured = !is_mouse_captured
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if is_mouse_captured else Input.MOUSE_MODE_VISIBLE
	mouse_mode_changed.emit(is_mouse_captured)
	emit_camera_state()

# === EXISTING CAMERA LOGIC (unchanged) ===

func handle_mouse_look():
	"""Handle mouse look with flexible limits"""
	
	# Handle YAW (horizontal rotation)
	if has_yaw_limits():
		if use_world_space_yaw:
			var new_world_yaw = rotation.y - mouse_delta.x * mouse_sensitivity
			new_world_yaw = apply_yaw_limits(new_world_yaw)
			rotation.y = new_world_yaw
		else:
			camera_rotation_y -= mouse_delta.x * mouse_sensitivity
			camera_rotation_y = apply_yaw_limits(camera_rotation_y)
			rotation.y = camera_rotation_y
	elif not is_yaw_locked():
		if use_world_space_yaw:
			rotation.y -= mouse_delta.x * mouse_sensitivity
		else:
			camera_rotation_y -= mouse_delta.x * mouse_sensitivity
			rotation.y = camera_rotation_y
	
	# Handle PITCH (vertical rotation)
	if has_pitch_limits():
		if use_world_space_pitch:
			var new_world_pitch = camera_rotation_x - mouse_delta.y * mouse_sensitivity
			camera_rotation_x = apply_pitch_limits(new_world_pitch)
		else:
			camera_rotation_x -= mouse_delta.y * mouse_sensitivity
			camera_rotation_x = apply_pitch_limits(camera_rotation_x)
	elif not is_pitch_locked():
		camera_rotation_x -= mouse_delta.y * mouse_sensitivity

func has_yaw_limits() -> bool:
	return yaw_limit_min != yaw_limit_max and not (yaw_limit_min == 0.0 and yaw_limit_max == 0.0)

func has_pitch_limits() -> bool:
	return pitch_limit_min != pitch_limit_max

func is_yaw_locked() -> bool:
	return yaw_limit_min == yaw_limit_max and yaw_limit_min != 0.0

func is_pitch_locked() -> bool:
	return pitch_limit_min == pitch_limit_max

func apply_yaw_limits(angle: float) -> float:
	return clamp(angle, deg_to_rad(yaw_limit_min), deg_to_rad(yaw_limit_max))

func apply_pitch_limits(angle: float) -> float:
	return clamp(angle, deg_to_rad(pitch_limit_min), deg_to_rad(pitch_limit_max))

func update_camera_distance(delta):
	current_distance = lerp(current_distance, target_distance, distance_smoothing * delta)
	spring_arm.spring_length = current_distance

func update_camera_offset(delta):
	var target_offset = camera_offset
	
	if enable_dynamic_offset and character.velocity.length() > 0.1:
		var movement_dir = Vector2(character.velocity.x, character.velocity.z).normalized()
		target_offset += Vector3(movement_dir.x * 0.3, 0, movement_dir.y * 0.3)
	
	current_offset = current_offset.lerp(target_offset, offset_smoothing * delta)
	
	if spring_arm:
		spring_arm.position = current_offset

func update_spring_arm_rotation():
	spring_arm.rotation.x = camera_rotation_x
	
	if is_yaw_locked() and not use_world_space_yaw:
		rotation.y = deg_to_rad(yaw_limit_min)
	
	if is_pitch_locked():
		if use_world_space_pitch:
			spring_arm.rotation.x = deg_to_rad(pitch_limit_min)
		else:
			camera_rotation_x = deg_to_rad(pitch_limit_min)
			spring_arm.rotation.x = camera_rotation_x

func update_immediate_follow(delta):
	var target_position = character.global_position + Vector3(0, camera_height, 0)
	var speed = snap_back_speed if follow_just_enabled else follow_smoothing
	global_position = global_position.lerp(target_position, speed * delta)
	
	if follow_just_enabled and global_position.distance_to(target_position) < 0.5:
		follow_just_enabled = false

func update_follow_with_delay(delta):
	var character_speed = character.get_movement_speed()
	is_character_moving = character_speed > movement_threshold
	
	if is_character_moving != was_character_moving:
		movement_change_time = 0.0
	else:
		movement_change_time += delta
	
	var should_follow = false
	
	if is_character_moving:
		if was_character_moving:
			should_follow = true
		else:
			should_follow = movement_change_time >= movement_start_delay
	else:
		if not was_character_moving:
			should_follow = false
		else:
			should_follow = movement_change_time < movement_stop_delay
	
	is_following = should_follow
	was_character_moving = is_character_moving
	
	var immediate_target = character.global_position + Vector3(0, camera_height, 0)
	
	if is_following:
		follow_target_position = immediate_target
	
	global_position = global_position.lerp(follow_target_position, follow_smoothing * delta)

# === FOLLOW CONTROL API ===

func set_follow_mode(mode: int):
	var old_mode = follow_mode
	follow_mode = mode
	if old_mode == 2 and mode != 2:
		follow_just_enabled = true
	follow_mode_changed.emit(mode)
	emit_camera_state()

func enable_follow():
	set_follow_mode(0)

func disable_follow():
	set_follow_mode(2)

func toggle_follow():
	match follow_mode:
		0, 1:
			set_follow_mode(2)
		2:
			set_follow_mode(0)

# === UTILITY METHODS ===

func get_camera() -> Camera3D:
	return camera

func get_current_distance() -> float:
	return current_distance

func get_current_fov() -> float:
	return camera.fov if camera else 75.0

func get_camera_debug_info() -> Dictionary:
	var base_info = {
		"follow_mode": ["Immediate", "Delayed", "Manual"][follow_mode],
		"is_following": is_following,
		"character_moving": is_character_moving,
		"mouse_captured": is_mouse_captured,
		"current_distance": current_distance,
		"camera_rotation_x": rad_to_deg(camera_rotation_x),
		"camera_rotation_y": rad_to_deg(camera_rotation_y),
		"enabled": enable_camera_controller
	}
	
	# Add control status
	base_info.merge(get_control_status())
	
	return base_info
