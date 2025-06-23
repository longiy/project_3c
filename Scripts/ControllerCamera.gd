# ControllerCamera.gd - Replace hysteresis with simple working delay
extends Node3D

signal mouse_mode_changed(is_captured: bool)

@export_group("Target & Following")
@export var target_character: CharacterBody3D
@export var camera_height = 2.0
@export var follow_smoothing = 8.0

@export_group("Follow Delay")
@export var enable_follow_delay = false
@export var movement_start_delay = 0.3    # Delay before camera starts following
@export var movement_stop_delay = 0.1     # Delay before camera stops following
@export var movement_threshold = 0.2      # Speed threshold to detect movement

# Other export groups remain the same...
@export_group("Camera Offset")
@export var camera_offset = Vector3.ZERO
@export var offset_smoothing = 8.0
@export var enable_dynamic_offset = false

@export_group("Mouse Controls")
@export var mouse_sensitivity = 0.002
@export var enable_mouse_yaw = true
@export var enable_mouse_pitch = true

@export_group("Camera Distance")
@export var enable_scroll_zoom = true
@export var min_distance = 1.0
@export var max_distance = 10.0
@export var scroll_speed = 0.5
@export var distance_smoothing = 8.0

@export_group("Rotation Limits")
@export var vertical_limit_min = -80.0
@export var vertical_limit_max = 50.0

@export_group("State Integration") 
@export var enable_state_overrides = true
@export var state_override_smoothing = 6.0

@onready var spring_arm = $SpringArm3D
@onready var camera = $SpringArm3D/Camera3D

var character: CharacterBody3D
var mouse_delta = Vector2.ZERO
var camera_rotation_x = 0.0
var is_mouse_captured = true
var target_distance = 4.0
var current_distance = 4.0
var current_offset = Vector3.ZERO

var base_target_distance = 4.0
var is_state_controlled = false

# Simple follow delay system
var is_character_moving = false
var was_character_moving = false
var movement_change_time = 0.0
var follow_target_position = Vector3.ZERO
var is_following = true

func _ready():
	character = target_character
	if not character:
		push_error("No target character assigned to camera!")
		return
	
	# Start in mouse capture mode
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	is_mouse_captured = true
	
	# Initialize camera
	camera_rotation_x = deg_to_rad(-20.0)
	target_distance = spring_arm.spring_length
	current_distance = target_distance
	current_offset = camera_offset
	
	if character:
		var initial_pos = character.global_position + Vector3(0, camera_height, 0)
		global_position = initial_pos
		follow_target_position = initial_pos
	
	# Store base values for state system
	base_target_distance = target_distance

func _input(event):
	# Camera-specific inputs
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
	
	# Handle mouse look rotation only when captured
	if is_mouse_captured and mouse_delta.length() > 0:
		if enable_mouse_yaw:
			rotation.y -= mouse_delta.x * mouse_sensitivity
		
		if enable_mouse_pitch:
			camera_rotation_x -= mouse_delta.y * mouse_sensitivity
			camera_rotation_x = clamp(camera_rotation_x, 
				deg_to_rad(vertical_limit_min), 
				deg_to_rad(vertical_limit_max))
		
		mouse_delta = Vector2.ZERO
	
	# Handle follow behavior
	if enable_follow_delay:
		update_follow_with_delay(delta)
	else:
		update_immediate_follow(delta)
	
	# Update SpringArm distance and rotation
	current_distance = lerp(current_distance, target_distance, distance_smoothing * delta)
	spring_arm.spring_length = current_distance
	spring_arm.rotation.x = camera_rotation_x
	
	# Apply camera offset
	var target_offset = camera_offset
	
	# Optional: Dynamic offset based on character movement
	if enable_dynamic_offset and character.velocity.length() > 0.1:
		var movement_dir = Vector2(character.velocity.x, character.velocity.z).normalized()
		target_offset += Vector3(movement_dir.x * 0.3, 0, movement_dir.y * 0.3)
	
	# Smoothly apply offset
	current_offset = current_offset.lerp(target_offset, offset_smoothing * delta)
	
	if spring_arm:
		spring_arm.position = current_offset
		
	# Handle state-based overrides
	if enable_state_overrides:
		handle_state_overrides(delta)

func update_immediate_follow(delta):
	"""Original immediate follow behavior"""
	var target_position = character.global_position + Vector3(0, camera_height, 0)
	global_position = global_position.lerp(target_position, follow_smoothing * delta)

func update_follow_with_delay(delta):
	"""Fixed follow delay system - camera stops completely during delays"""
	
	# Check if character is moving
	var character_speed = character.get_movement_speed()
	is_character_moving = character_speed > movement_threshold
	
	# Detect movement state changes
	if is_character_moving != was_character_moving:
		movement_change_time = 0.0
		print("📹 Camera: Character movement changed - moving: ", is_character_moving)
	else:
		movement_change_time += delta
	
	# Determine if we should follow based on current state and delays
	var should_follow = false  # Default to not following
	
	if is_character_moving:
		# Character is moving - only follow if delay has expired
		if was_character_moving:
			# Was already moving - continue following
			should_follow = true
		else:
			# Just started moving - check start delay
			should_follow = movement_change_time >= movement_start_delay
			if should_follow:
				print("📹 Camera: Starting to follow after ", movement_start_delay, "s delay")
	else:
		# Character is not moving - only stop following if delay has expired
		if not was_character_moving:
			# Was already stopped - don't follow
			should_follow = false
		else:
			# Just stopped moving - check stop delay
			should_follow = movement_change_time < movement_stop_delay
			if not should_follow:
				print("📹 Camera: Stopping follow after ", movement_stop_delay, "s delay")
	
	is_following = should_follow
	was_character_moving = is_character_moving
	
	# Update target position ONLY when following
	var immediate_target = character.global_position + Vector3(0, camera_height, 0)
	
	if is_following:
		# Normal following - update target
		follow_target_position = immediate_target
	else:
		# Not following - keep old target (camera stays put)
		pass
	
	# Apply position smoothly to the target (which doesn't update during delays)
	global_position = global_position.lerp(follow_target_position, follow_smoothing * delta)

# === REST OF THE METHODS REMAIN THE SAME ===

func get_camera() -> Camera3D:
	return camera

func set_camera_offset(new_offset: Vector3, transition_time: float = 1.0):
	camera_offset = new_offset
	print("Camera: Setting offset to ", new_offset)

func set_over_shoulder_left(strength: float = 1.0):
	set_camera_offset(Vector3(-0.8 * strength, 0.2 * strength, 0.3 * strength))

func set_over_shoulder_right(strength: float = 1.0):
	set_camera_offset(Vector3(0.8 * strength, 0.2 * strength, 0.3 * strength))

func set_centered_view():
	set_camera_offset(Vector3.ZERO)

func set_combat_offset(target_enemy: Node3D):
	if target_enemy and character:
		var to_enemy = (target_enemy.global_position - character.global_position).normalized()
		var side_offset = Vector3(to_enemy.z, 0, -to_enemy.x) * 0.6
		set_camera_offset(side_offset + Vector3(0, 0.3, 0.2))

func handle_state_overrides(delta):
	pass

func set_state_fov(new_fov: float, transition_speed: float = 2.0):
	if camera and enable_state_overrides:
		is_state_controlled = true

func set_state_distance(new_distance: float, transition_speed: float = 2.0):
	if enable_state_overrides:
		target_distance = new_distance
		is_state_controlled = true

func reset_to_base_values():
	if is_state_controlled:
		target_distance = base_target_distance
		if camera:
			camera.fov = 75.0
		is_state_controlled = false

func get_current_distance() -> float:
	return current_distance

func get_current_fov() -> float:
	return camera.fov if camera else 75.0

func get_camera_debug_info() -> Dictionary:
	return {
		"target_distance": target_distance,
		"current_distance": current_distance,
		"is_state_controlled": is_state_controlled,
		"current_fov": camera.fov if camera else 0.0,
		"mouse_captured": is_mouse_captured,
		"follow_delay_enabled": enable_follow_delay,
		"is_following": is_following,
		"character_moving": is_character_moving,
		"movement_change_time": movement_change_time
	}
