# ControllerCamera.gd - Cleaned rotation limits implementation
extends Node3D

signal mouse_mode_changed(is_captured: bool)

@export_group("Target & Following")
@export var target_character: CharacterBody3D
@export var camera_height = 2.0
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
@export var yaw_limit_min = 0.0  # 0,0 = no limits
@export var yaw_limit_max = 0.0
@export var use_world_space_yaw = false  # true = world space, false = relative to character

@export_subgroup("Pitch (Vertical)")
@export var pitch_limit_min = -80.0  # min,max different = limits active
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
@export var offset_smoothing = 8.0
@export var enable_dynamic_offset = false


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

func _input(event):
	# Toggle mouse capture
	if event.is_action_pressed("toggle_mouse_look"):
		toggle_mouse_mode()
	
	# Mouse look when captured
	if is_mouse_captured and event is InputEventMouseMotion:
		mouse_delta = event.relative
	
	# Zoom control
	if enable_scroll_zoom and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			target_distance = clamp(target_distance - scroll_speed, min_distance, max_distance)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			target_distance = clamp(target_distance + scroll_speed, min_distance, max_distance)

func toggle_mouse_mode():
	is_mouse_captured = !is_mouse_captured
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if is_mouse_captured else Input.MOUSE_MODE_VISIBLE
	mouse_mode_changed.emit(is_mouse_captured)

func _physics_process(delta):
	if not character:
		return
	
	# Handle mouse look rotation
	if is_mouse_captured and mouse_delta.length() > 0:
		handle_mouse_look()
		mouse_delta = Vector2.ZERO
	
	# Handle follow behavior
	match follow_mode:
		0: # Immediate
			update_immediate_follow(delta)
		1: # Delayed
			update_follow_with_delay(delta)
		2: # Manual
			pass # No automatic following
	
	# Update camera properties
	update_camera_distance(delta)
	update_camera_offset(delta)
	update_spring_arm_rotation()

func handle_mouse_look():
	"""Handle mouse look with flexible limits"""
	
	# Handle YAW (horizontal rotation)
	if has_yaw_limits():
		if use_world_space_yaw:
			# World space yaw - absolute world rotation
			var new_world_yaw = rotation.y - mouse_delta.x * mouse_sensitivity
			new_world_yaw = apply_yaw_limits(new_world_yaw)
			rotation.y = new_world_yaw
		else:
			# Relative yaw - relative to character
			camera_rotation_y -= mouse_delta.x * mouse_sensitivity
			camera_rotation_y = apply_yaw_limits(camera_rotation_y)
			rotation.y = camera_rotation_y
	elif not is_yaw_locked():
		# Free yaw rotation
		if use_world_space_yaw:
			rotation.y -= mouse_delta.x * mouse_sensitivity
		else:
			camera_rotation_y -= mouse_delta.x * mouse_sensitivity
			rotation.y = camera_rotation_y
	# If yaw is locked (min == max != 0), do nothing
	
	# Handle PITCH (vertical rotation)
	if has_pitch_limits():
		if use_world_space_pitch:
			# World space pitch - absolute world rotation
			var new_world_pitch = camera_rotation_x - mouse_delta.y * mouse_sensitivity
			camera_rotation_x = apply_pitch_limits(new_world_pitch)
		else:
			# Relative pitch - relative to camera rig
			camera_rotation_x -= mouse_delta.y * mouse_sensitivity
			camera_rotation_x = apply_pitch_limits(camera_rotation_x)
	elif not is_pitch_locked():
		# Free pitch rotation
		camera_rotation_x -= mouse_delta.y * mouse_sensitivity
	# If pitch is locked (min == max), do nothing

# === ROTATION LIMIT HELPERS ===

func has_yaw_limits() -> bool:
	"""Check if yaw has active limits (not 0,0 and not locked)"""
	return yaw_limit_min != yaw_limit_max and not (yaw_limit_min == 0.0 and yaw_limit_max == 0.0)

func has_pitch_limits() -> bool:
	"""Check if pitch has active limits (not equal values)"""
	return pitch_limit_min != pitch_limit_max

func is_yaw_locked() -> bool:
	"""Check if yaw is locked to a specific angle"""
	return yaw_limit_min == yaw_limit_max and yaw_limit_min != 0.0

func is_pitch_locked() -> bool:
	"""Check if pitch is locked to a specific angle"""
	return pitch_limit_min == pitch_limit_max

func apply_yaw_limits(angle: float) -> float:
	"""Apply yaw limits and return clamped angle"""
	return clamp(angle, deg_to_rad(yaw_limit_min), deg_to_rad(yaw_limit_max))

func apply_pitch_limits(angle: float) -> float:
	"""Apply pitch limits and return clamped angle"""
	return clamp(angle, deg_to_rad(pitch_limit_min), deg_to_rad(pitch_limit_max))

func update_camera_distance(delta):
	"""Update SpringArm distance"""
	current_distance = lerp(current_distance, target_distance, distance_smoothing * delta)
	spring_arm.spring_length = current_distance

func update_camera_offset(delta):
	"""Update camera offset with dynamic offset support"""
	var target_offset = camera_offset
	
	# Dynamic offset based on character movement
	if enable_dynamic_offset and character.velocity.length() > 0.1:
		var movement_dir = Vector2(character.velocity.x, character.velocity.z).normalized()
		target_offset += Vector3(movement_dir.x * 0.3, 0, movement_dir.y * 0.3)
	
	current_offset = current_offset.lerp(target_offset, offset_smoothing * delta)
	
	if spring_arm:
		spring_arm.position = current_offset

func update_spring_arm_rotation():
	"""Apply pitch rotation to SpringArm and handle locked rotations"""
	spring_arm.rotation.x = camera_rotation_x
	
	# Handle locked yaw in relative mode
	if is_yaw_locked() and not use_world_space_yaw:
		rotation.y = deg_to_rad(yaw_limit_min)
	
	# Handle locked pitch
	if is_pitch_locked():
		if use_world_space_pitch:
			spring_arm.rotation.x = deg_to_rad(pitch_limit_min)
		else:
			camera_rotation_x = deg_to_rad(pitch_limit_min)
			spring_arm.rotation.x = camera_rotation_x

func update_immediate_follow(delta):
	"""Immediate follow - always tracks character with optional snap-back"""
	var target_position = character.global_position + Vector3(0, camera_height, 0)
	
	# Use faster speed if we just switched from manual mode
	var speed = snap_back_speed if follow_just_enabled else follow_smoothing
	
	global_position = global_position.lerp(target_position, speed * delta)
	
	# Check if snap-back is complete
	if follow_just_enabled and global_position.distance_to(target_position) < 0.5:
		follow_just_enabled = false
		print("📹 Camera: Snap-back complete")

func update_follow_with_delay(delta):
	"""Follow with delay system"""
	var character_speed = character.get_movement_speed()
	is_character_moving = character_speed > movement_threshold
	
	# Detect movement state changes
	if is_character_moving != was_character_moving:
		movement_change_time = 0.0
		print("📹 Camera: Character movement changed - moving: ", is_character_moving)
	else:
		movement_change_time += delta
	
	# Determine if we should follow
	var should_follow = false
	
	if is_character_moving:
		if was_character_moving:
			should_follow = true
		else:
			should_follow = movement_change_time >= movement_start_delay
			if should_follow:
				print("📹 Camera: Starting to follow after ", movement_start_delay, "s delay")
	else:
		if not was_character_moving:
			should_follow = false
		else:
			should_follow = movement_change_time < movement_stop_delay
			if not should_follow:
				print("📹 Camera: Stopping follow after ", movement_stop_delay, "s delay")
	
	is_following = should_follow
	was_character_moving = is_character_moving
	
	# Update target position
	var immediate_target = character.global_position + Vector3(0, camera_height, 0)
	
	if is_following:
		follow_target_position = immediate_target
	
	global_position = global_position.lerp(follow_target_position, follow_smoothing * delta)

# === FOLLOW CONTROL API ===


func toggle_follow():
	"""Toggle between follow modes - cycles through or simple on/off"""
	match follow_mode:
		0, 1: # Immediate or Delayed -> Manual (off)
			follow_mode = 2
			print("📹 Camera: Following disabled (manual)")
		2: # Manual -> Immediate (on)
			follow_just_enabled = true
			follow_mode = 0
			print("📹 Camera: Following enabled (immediate)")

func enable_follow():
	if follow_mode == 2: # Was manual
		follow_just_enabled = true
	follow_mode = 0 # Set to immediate
	print("📹 Camera: Following enabled (immediate)")

func disable_follow():
	follow_mode = 2 # Set to manual
	print("📹 Camera: Following disabled (manual)")

func set_follow_mode(mode: int):
	var old_mode = follow_mode
	follow_mode = mode
	if old_mode == 2 and mode != 2:
		follow_just_enabled = true
	print("📹 Camera: Follow mode changed to ", ["Immediate", "Delayed", "Manual"][mode])

func is_following_character() -> bool:
	return follow_mode != 2 # Not manual

# === CAMERA CONTROL API ===

func get_camera() -> Camera3D:
	return camera

func set_camera_offset(new_offset: Vector3):
	camera_offset = new_offset
	print("📹 Camera: Setting offset to ", new_offset)

func set_over_shoulder_left(strength: float = 1.0):
	set_camera_offset(Vector3(-0.8 * strength, 0.2 * strength, 0.3 * strength))

func set_over_shoulder_right(strength: float = 1.0):
	set_camera_offset(Vector3(0.8 * strength, 0.2 * strength, 0.3 * strength))

func set_centered_view():
	set_camera_offset(Vector3.ZERO)

func reset_camera_rotation():
	"""Reset camera to default rotation"""
	camera_rotation_x = deg_to_rad(-20.0)
	camera_rotation_y = 0.0
	rotation.y = 0.0

# === ROTATION CONTROL API ===

func set_yaw_limits(min_deg: float, max_deg: float, world_space: bool = false):
	"""Set yaw limits at runtime"""
	yaw_limit_min = min_deg
	yaw_limit_max = max_deg
	use_world_space_yaw = world_space

func set_pitch_limits(min_deg: float, max_deg: float, world_space: bool = false):
	"""Set pitch limits at runtime"""
	pitch_limit_min = min_deg
	pitch_limit_max = max_deg
	use_world_space_pitch = world_space

func lock_yaw_at(angle_deg: float, world_space: bool = false):
	"""Lock yaw to a specific angle"""
	set_yaw_limits(angle_deg, angle_deg, world_space)

func lock_pitch_at(angle_deg: float, world_space: bool = false):
	"""Lock pitch to a specific angle"""
	set_pitch_limits(angle_deg, angle_deg, world_space)

func free_yaw():
	"""Remove yaw limits"""
	set_yaw_limits(0.0, 0.0, false)

func free_pitch():
	"""Remove pitch limits (but keep reasonable defaults)"""
	set_pitch_limits(-80.0, 50.0, false)

# === PLACEHOLDER METHODS ===

func get_current_distance() -> float:
	return current_distance

func get_current_fov() -> float:
	return camera.fov if camera else 75.0

func get_camera_debug_info() -> Dictionary:
	return {
		"follow_mode": ["Immediate", "Delayed", "Manual"][follow_mode],
		"is_following": is_following,
		"character_moving": is_character_moving,
		"mouse_captured": is_mouse_captured,
		"current_distance": current_distance,
		"camera_rotation_x": rad_to_deg(camera_rotation_x),
		"camera_rotation_y": rad_to_deg(camera_rotation_y),
		"yaw_limits_active": has_yaw_limits(),
		"pitch_limits_active": has_pitch_limits(),
		"yaw_locked": is_yaw_locked(),
		"pitch_locked": is_pitch_locked()
	}
