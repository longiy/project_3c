extends CharacterBody3D

@export var speed = 8.0 ## Movement speed (m/s)
@export var jump_velocity = 6 ## Jump initial velocity (m/s)
@export var acceleration = 150.0 ## Acceleration rate (m/s²)
@export var deceleration = 200.0 ## Deceleration rate (m/s²)
@export var gravity_multiplier = 2
@export var coyote_time = 0.1 ## Time after leaving ground you can still jump (seconds)
@export var ground_check_distance = 0.2 ## Distance to check for ground (meters)
@export var max_jumps = 2 ## Total jumps allowed (1 = single, 2 = double, etc.)
@export var rotation_speed = 4.0 ## How fast character rotates to face movement direction
@export var allow_rotation_while_jumping = false ## Enable/disable rotation during jump
@export var maintain_forward_momentum_when_jumping = false ## Auto-forward while jumping vs manual control
@export var sprint_speed = 12.0 ## Sprint speed (m/s)
@export var sprint_acceleration = 200.0 ## Sprint acceleration rate (m/s²)

var base_gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var coyote_timer = 0.0
var jumps_remaining = 0
var jump_forward_direction = Vector3.ZERO
var is_sprinting = false

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
		handle_rotation_and_movement(movement_vector, delta, is_in_air, is_sprinting)
	else:
		handle_movement_only(movement_vector, delta, is_in_air, is_sprinting)
	
	move_and_slide()

func handle_rotation_and_movement(movement_vector: Vector3, delta: float, is_in_air: bool, sprinting: bool):
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

func is_near_ground() -> bool:
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_position, 
		global_position + Vector3.DOWN * ground_check_distance
	)
	var result = space_state.intersect_ray(query)
	return result.size() > 0
