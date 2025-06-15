extends CharacterBody3D
# ═══════════════════════════════════════════════════════════════════════════════════════════════
# DEBUG SETTINGS
# ═══════════════════════════════════════════════════════════════════════════════════════════════
@export_group("Debug")
@export var reset_position = Vector3(0, 1, 0) ## Position to reset to when pressing reset key
@export var reset_rotation = Vector3(0, 0, 0) ## Rotation to reset to (in degrees)

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# COMPONENTS
# ═══════════════════════════════════════════════════════════════════════════════════════════════
@export_group("Components")
@export var navigation_component: NavigationComponent
@export var animation_controller: AnimationController

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# CAMERA SETTINGS
# ═══════════════════════════════════════════════════════════════════════════════════════════════
@export_group("Camera")
@export var camera: Camera3D ## Camera reference for relative movement
@export var camera_relative_movement = true ## Use camera-relative movement instead of world coordinates

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# MOVEMENT SETTINGS
# ═══════════════════════════════════════════════════════════════════════════════════════════════
@export_group("Movement Speeds")
@export var walk_speed = 3.0 ## Walk speed (m/s) - slower than normal speed
@export var speed = 6.0 ## Normal movement speed (m/s)
@export var sprint_speed = 9.0 ## Sprint speed (m/s)

@export_group("Movement Physics")
@export var walk_acceleration = 50.0 ## Walk acceleration rate (m/s²)
@export var acceleration = 50.0 ## Normal acceleration rate (m/s²)
@export var sprint_acceleration = 50.0 ## Sprint acceleration rate (m/s²)
@export var deceleration = 50.0 ## Deceleration rate (m/s²)
@export var gravity_multiplier = 1 ## Gravity multiplier (1 = normal gravity)

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# ROTATION SETTINGS
# ═══════════════════════════════════════════════════════════════════════════════════════════════
@export_group("Rotation")
@export var rotation_speed = 6 ## How fast character rotates to face movement direction
@export var rotation_snapping = false ## Enable snapping to fixed angles
@export var snap_angle = 45.0 ## Snap angle in degrees (45 = 8 directions, 90 = 4 directions, etc.)

@export_group("Strafing")
@export var enable_strafing = false ## Enable strafing mode (no rotation until speed threshold)
@export var rotation_speed_threshold = 0.8 ## Speed percentage before rotation starts (0.0-1.0)

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# JUMPING SETTINGS
# ═══════════════════════════════════════════════════════════════════════════════════════════════
@export_group("Jumping")
@export var jump_velocity = 6 ## Jump initial velocity (m/s)
@export var max_jumps = 2 ## Total jumps allowed (1 = single, 2 = double, etc.)
@export var coyote_time = 0.1 ## Time after leaving ground you can still jump (seconds)
@export var ground_check_distance = 0.2 ## Distance to check for ground (meters)
@export var allow_rotation_while_jumping = true ## Enable/disable rotation during jump
@export var maintain_forward_momentum_when_jumping = true ## Auto-forward while jumping vs manual control
@export var air_control_strength = 0.3 ## How much control you have in the air (0.0 = none, 1.0 = full)

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# RUNTIME VARIABLES
# ═══════════════════════════════════════════════════════════════════════════════════════════════
var base_gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var coyote_timer = 0.0
var jumps_remaining = 0
var jump_forward_direction = Vector3.ZERO
var is_sprinting = false
var is_walking = false
var last_input_dir = Vector2.ZERO  # Track previous input for snapping
var current_input_dir = Vector2.ZERO  # Current input from InputComponent

func _ready():
	# Connect to new navigation component if assigned
	if navigation_component:
		print("Character: Connected to NavigationComponent")
	else:
		print("Character: No NavigationComponent assigned")
	
	# NEW: Connect to InputManager for WASD input
	if InputManager:
		InputManager.movement_input.connect(_on_movement_input_changed)
		print("Character: Connected to InputManager for WASD input")
	
	# Animation controller will handle its own connections
	if not animation_controller:
		push_warning("No AnimationController assigned - animations will not work")

func _on_movement_input_changed(input_vector: Vector2):
	current_input_dir = input_vector

func is_near_ground() -> bool:
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_position, 
		global_position + Vector3.DOWN * ground_check_distance
	)
	var result = space_state.intersect_ray(query)
	return result.size() > 0

func should_allow_rotation(movement_vector: Vector3, walking: bool, sprinting: bool) -> bool:
	# Always allow rotation if strafing is disabled
	if not enable_strafing:
		return true
	
	# Don't rotate if not moving
	if movement_vector.length() < 0.1:
		return false
	
	# Calculate current target speed and threshold based on movement mode
	var target_speed: float
	if walking:
		target_speed = walk_speed
	elif sprinting:
		target_speed = sprint_speed
	else:
		target_speed = speed
	
	var speed_threshold = target_speed * rotation_speed_threshold
	
	# Get horizontal velocity (ignore Y for speed calculation)
	var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
	var current_speed = horizontal_velocity.length()
	
	# Allow rotation only if we've reached the speed threshold
	return current_speed >= speed_threshold

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= (base_gravity * gravity_multiplier) * delta
	
	if is_on_floor() or is_near_ground():
		coyote_timer = coyote_time
		jumps_remaining = max_jumps
		jump_forward_direction = Vector3.ZERO
	else:
		coyote_timer -= delta
	
	# Get input direction - NEW: Check navigation component first, then fallback to old system
	var input_dir = Vector2.ZERO
	
	# Priority 1: New navigation system (if active)
	if navigation_component and navigation_component.is_navigation_active():
		input_dir = navigation_component.get_navigation_direction()
		print("Character: Using navigation input: ", input_dir.length())
	# Priority 2: Current WASD input (from old InputComponent)
	elif current_input_dir.length() > 0.1:
		input_dir = current_input_dir
	# Priority 3: Fallback to direct input if no InputComponent assigned
	else:
		# This covers the case where there's no navigation active and no WASD input
		var direct_input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		if direct_input.length() > 0.1:
			input_dir = direct_input
	
	# Handle movement mode inputs (walk overrides sprint)
	is_walking = Input.is_action_pressed("walk")
	is_sprinting = Input.is_action_pressed("sprint") and not is_walking
	
	# Handle reset input
	if Input.is_action_just_pressed("reset"):
		reset_character_transform()
	
	# Calculate movement vector based on input
	var movement_vector = calculate_movement_vector(input_dir)
	
	# Handle jumping
	if Input.is_action_just_pressed("jump"):
		if (coyote_timer > 0 and jumps_remaining > 0) or (jumps_remaining > 0 and not is_on_floor()):
			velocity.y = jump_velocity
			jumps_remaining -= 1
			coyote_timer = 0
			
			if maintain_forward_momentum_when_jumping:
				jump_forward_direction = movement_vector.normalized()
	
	# Handle movement and rotation
	var is_moving = movement_vector.length() > 0.1
	var is_in_air = not is_on_floor()
	var can_rotate = true
	
	if is_in_air and not allow_rotation_while_jumping:
		can_rotate = false
	
	# Check if we should rotate based on speed threshold (for strafing)
	if can_rotate and enable_strafing:
		can_rotate = should_allow_rotation(movement_vector, is_walking, is_sprinting)
	
	# Apply movement and rotation
	if can_rotate and is_moving:
		handle_rotation_and_movement(movement_vector, delta, is_in_air, is_walking, is_sprinting, input_dir)
	else:
		handle_movement_only(movement_vector, delta, is_in_air, is_walking, is_sprinting)
	
	move_and_slide()

func calculate_movement_vector(input_dir: Vector2) -> Vector3:
	var movement_vector = Vector3.ZERO
	
	if camera_relative_movement and camera:
		# Camera-relative movement (ignore pitch)
		var cam_transform = camera.global_transform.basis
		var cam_forward = Vector3(-cam_transform.z.x, 0, -cam_transform.z.z).normalized()
		var cam_right = Vector3(cam_transform.x.x, 0, cam_transform.x.z).normalized()
		
		movement_vector = cam_right * input_dir.x + cam_forward * (-input_dir.y)
	else:
		# World-coordinate movement
		movement_vector.x = input_dir.x   # A/D input: A = left (-X), D = right (+X)  
		movement_vector.z = input_dir.y   # W/S input: W = forward (-Z), S = backward (+Z)
	
	return movement_vector

func handle_rotation_and_movement(movement_vector: Vector3, delta: float, is_in_air: bool, walking: bool, sprinting: bool, input_dir: Vector2):
	# Determine speed and acceleration based on movement mode
	var current_speed: float
	var current_acceleration: float
	
	if walking:
		current_speed = walk_speed
		current_acceleration = walk_acceleration
	elif sprinting:
		current_speed = sprint_speed
		current_acceleration = sprint_acceleration
	else:
		current_speed = speed
		current_acceleration = acceleration
	
	# Handle movement direction
	var movement_direction: Vector3
	if is_in_air and maintain_forward_momentum_when_jumping and jump_forward_direction.length() > 0.1:
		# In air: blend between stored momentum and current input based on air_control_strength
		var current_input = movement_vector.normalized()
		movement_direction = jump_forward_direction.normalized().lerp(current_input, air_control_strength)
		movement_direction = movement_direction.normalized()
	else:
		# On ground: use current input
		movement_direction = movement_vector.normalized()
	
	# Handle rotation direction - always use current input for rotation
	var rotation_direction = movement_vector.normalized()
	
	# Apply movement
	if movement_direction.length() > 0.1:
		# Reduce acceleration in air for more realistic physics
		var effective_acceleration = current_acceleration
		if is_in_air:
			effective_acceleration *= air_control_strength
		
		velocity.x = move_toward(velocity.x, movement_direction.x * current_speed, effective_acceleration * delta)
		velocity.z = move_toward(velocity.z, movement_direction.z * current_speed, effective_acceleration * delta)
	else:
		# Reduce deceleration in air
		var effective_deceleration = deceleration
		if is_in_air:
			effective_deceleration *= air_control_strength
			
		velocity.x = move_toward(velocity.x, 0, effective_deceleration * delta)
		velocity.z = move_toward(velocity.z, 0, effective_deceleration * delta)
	
	# Apply rotation based on current input (not stored direction)
	if rotation_direction.length() > 0.1:
		var target_rotation = atan2(rotation_direction.x, rotation_direction.z)
		target_rotation = snap_rotation_if_enabled(target_rotation)
		
		# Check if input changed (for snapping logic)
		var input_changed = input_dir.distance_to(last_input_dir) > 0.1
		last_input_dir = input_dir
		
		if rotation_snapping and input_changed:
			# Snap only when input changes
			rotation.y = target_rotation
		else:
			# Smooth rotation when camera moves or snapping disabled
			rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)

func handle_movement_only(movement_vector: Vector3, delta: float, is_in_air: bool, walking: bool, sprinting: bool):
	# Determine speed and acceleration based on movement mode
	var current_speed: float
	var current_acceleration: float
	
	if walking:
		current_speed = walk_speed
		current_acceleration = walk_acceleration
	elif sprinting:
		current_speed = sprint_speed
		current_acceleration = sprint_acceleration
	else:
		current_speed = speed
		current_acceleration = acceleration
	
	var final_movement: Vector3
	if is_in_air and maintain_forward_momentum_when_jumping:
		final_movement = jump_forward_direction.normalized()
	else:
		final_movement = movement_vector.normalized()
	
	if final_movement.length() > 0.1:
		velocity.x = move_toward(velocity.x, final_movement.x * current_speed, current_acceleration * delta)
		velocity.z = move_toward(velocity.z, final_movement.z * current_speed, current_acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0, deceleration * delta)

func snap_rotation_if_enabled(target_rotation: float) -> float:
	if not rotation_snapping:
		return target_rotation
	
	# Convert to degrees for easier calculation
	var degrees = rad_to_deg(target_rotation)
	
	# Normalize to 0-360 range
	degrees = fmod(degrees, 360.0)
	if degrees < 0:
		degrees += 360.0
	
	# Snap to nearest angle increment
	var snapped_degrees = round(degrees / snap_angle) * snap_angle
	
	# Handle wrap around (360 = 0)
	if snapped_degrees >= 360.0:
		snapped_degrees = 0.0
	
	# Convert back to radians
	return deg_to_rad(snapped_degrees)

func reset_character_transform():
	# Reset position
	global_position = reset_position
	
	# Reset rotation (convert from degrees to radians)
	rotation_degrees = reset_rotation
	
	# Zero out velocity to prevent unwanted movement after reset
	velocity = Vector3.ZERO
	
	# Reset jump-related variables
	jumps_remaining = max_jumps
	coyote_timer = 0.0
	jump_forward_direction = Vector3.ZERO
	
	# Cancel any click navigation - NEW: use NavigationComponent
	if navigation_component:
		navigation_component.cancel_navigation()
	
	print("Character reset to: ", reset_position)
