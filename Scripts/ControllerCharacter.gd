extends CharacterBody3D
@export var camera: Camera3D ## Camera reference for relative movement
@export var camera_relative_movement = true ## Use camera-relative movement instead of world coordinates
@export var speed = 8.0 ## Movement speed (m/s)
@export var rotation_speed = 8 ## How fast character rotates to face movement direction
@export var rotation_snapping = false ## Enable snapping to fixed angles
@export var snap_angle = 45.0 ## Snap angle in degrees (45 = 8 directions, 90 = 4 directions, etc.)
@export var sprint_speed = 12.0 ## Sprint speed (m/s)
@export var sprint_acceleration = 200.0 ## Sprint acceleration rate (m/s²)
@export var acceleration = 150.0 ## Acceleration rate (m/s²)
@export var deceleration = 200.0 ## Deceleration rate (m/s²)
@export var jump_velocity = 6 ## Jump initial velocity (m/s)
@export var max_jumps = 2 ## Total jumps allowed (1 = single, 2 = double, etc.)
@export var gravity_multiplier = 1
@export var coyote_time = 0.1 ## Time after leaving ground you can still jump (seconds)
@export var ground_check_distance = 0.2 ## Distance to check for ground (meters)
@export var allow_rotation_while_jumping = true ## Enable/disable rotation during jump
@export var maintain_forward_momentum_when_jumping = true ## Auto-forward while jumping vs manual control


var base_gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var coyote_timer = 0.0
var jumps_remaining = 0
var jump_forward_direction = Vector3.ZERO
var is_sprinting = false
var last_input_dir = Vector2.ZERO  # Track previous WASD input for snapping

func is_near_ground() -> bool:
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_position, 
		global_position + Vector3.DOWN * ground_check_distance
	)
	var result = space_state.intersect_ray(query)
	return result.size() > 0

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= (base_gravity * gravity_multiplier) * delta
	
	if is_on_floor() or is_near_ground():
		coyote_timer = coyote_time
		jumps_remaining = max_jumps
		jump_forward_direction = Vector3.ZERO
	else:
		coyote_timer -= delta
	
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	# Handle sprint input
	is_sprinting = Input.is_action_pressed("sprint")
	
	# Calculate 8-directional movement
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
	
	if Input.is_action_just_pressed("jump"):
		if (coyote_timer > 0 and jumps_remaining > 0) or (jumps_remaining > 0 and not is_on_floor()):
			velocity.y = jump_velocity
			jumps_remaining -= 1
			coyote_timer = 0
			
			if maintain_forward_momentum_when_jumping:
				jump_forward_direction = movement_vector.normalized()
	
	var is_moving = movement_vector.length() > 0.1
	var is_in_air = not is_on_floor()
	var can_rotate = true
	
	if is_in_air and not allow_rotation_while_jumping:
		can_rotate = false
	
	# Handle rotation and movement
	if can_rotate and is_moving:
		handle_rotation_and_movement(movement_vector, delta, is_in_air, is_sprinting, input_dir)
	else:
		handle_movement_only(movement_vector, delta, is_in_air, is_sprinting)
	
	move_and_slide()

func handle_rotation_and_movement(movement_vector: Vector3, delta: float, is_in_air: bool, sprinting: bool, input_dir: Vector2):
	# Determine speed and acceleration
	var current_speed = sprint_speed if sprinting else speed
	var current_acceleration = sprint_acceleration if sprinting else acceleration
	
	# Handle movement - use stored direction in air if momentum enabled
	var movement_direction: Vector3
	if is_in_air and maintain_forward_momentum_when_jumping:
		movement_direction = jump_forward_direction.normalized()
	else:
		movement_direction = movement_vector.normalized()
	
	# Handle rotation - always use current input for rotation (even in air)
	var rotation_direction = movement_vector.normalized()
	
	# Apply movement
	if movement_direction.length() > 0.1:
		velocity.x = move_toward(velocity.x, movement_direction.x * current_speed, current_acceleration * delta)
		velocity.z = move_toward(velocity.z, movement_direction.z * current_speed, current_acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0, deceleration * delta)
	
	# Apply rotation based on current input (not stored direction)
	if rotation_direction.length() > 0.1:
		var target_rotation = atan2(rotation_direction.x, rotation_direction.z)
		target_rotation = snap_rotation_if_enabled(target_rotation)
		
		# Check if WASD input changed (for snapping logic)
		var input_changed = input_dir.distance_to(last_input_dir) > 0.1
		last_input_dir = input_dir
		
		if rotation_snapping and input_changed:
			# Snap only when WASD input changes
			rotation.y = target_rotation
		else:
			# Smooth rotation when camera moves or snapping disabled
			rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)

func handle_movement_only(movement_vector: Vector3, delta: float, is_in_air: bool, sprinting: bool):
	# Just handle movement without rotation
	var current_speed = sprint_speed if sprinting else speed
	var current_acceleration = sprint_acceleration if sprinting else acceleration
	
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
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_position, 
		global_position + Vector3.DOWN * ground_check_distance
	)
	var result = space_state.intersect_ray(query)
	return result.size() > 0
