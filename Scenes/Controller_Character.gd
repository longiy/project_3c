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
@export var smooth_rotation = true ## Toggle between smooth and stepped rotation
@export var allow_rotation_while_jumping = false ## Enable/disable rotation during jump
@export var allow_rotation_while_stationary = true ## Enable/disable rotation when not moving
@export var maintain_forward_momentum_when_jumping = false ## Auto-forward while jumping vs manual control
@export var sprint_speed = 12.0 ## Sprint speed (m/s)
@export var sprint_acceleration = 200.0 ## Sprint acceleration rate (m/s²)

var base_gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var coyote_timer = 0.0
var jumps_remaining = 0
var jump_forward_direction = Vector3.ZERO
var is_sprinting = false
var smooth_rotation_angle = 0.0  # Add this line

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= (base_gravity * gravity_multiplier) * delta
	
	if is_on_floor() or is_near_ground():
		coyote_timer = coyote_time
		jumps_remaining = max_jumps
		jump_forward_direction = Vector3.ZERO
	else:
		coyote_timer -= delta
	
	if Input.is_action_just_pressed("jump"):
		if (coyote_timer > 0 and jumps_remaining > 0) or (jumps_remaining > 0 and not is_on_floor()):
			velocity.y = jump_velocity
			jumps_remaining -= 1
			coyote_timer = 0
			
			if maintain_forward_momentum_when_jumping:
				jump_forward_direction = Vector3.FORWARD.rotated(Vector3.UP, rotation.y)
	
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	# Handle sprint input
	is_sprinting = Input.is_action_pressed("sprint")
	
	var is_moving = abs(input_dir.y) > 0.1
	var is_in_air = not is_on_floor()
	var can_rotate = true
	
	if is_in_air and not allow_rotation_while_jumping:
		can_rotate = false
	
	if not is_moving and not allow_rotation_while_stationary:
		can_rotate = false
	
	if can_rotate:
		handle_rotation(input_dir.x, delta)
	
	handle_movement(input_dir, delta, is_in_air)
	move_and_slide()

func handle_movement(input_dir: Vector2, delta: float, is_in_air: bool):
	var movement_input: float
	var forward: Vector3
	
	# Determine current speed and acceleration based on sprint state
	var current_speed = sprint_speed if is_sprinting else speed
	var current_acceleration = sprint_acceleration if is_sprinting else acceleration
	
	if is_in_air and maintain_forward_momentum_when_jumping:
		movement_input = 1.0
		forward = jump_forward_direction
	else:
		movement_input = -input_dir.y
		forward = Vector3.FORWARD.rotated(Vector3.UP, rotation.y)
	
	var direction = (forward * movement_input).normalized()
	
	if abs(movement_input) > 0.1:
		velocity.x = move_toward(velocity.x, direction.x * current_speed, current_acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * current_speed, current_acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0, deceleration * delta)

func handle_rotation(horizontal_input: float, delta: float):
	if abs(horizontal_input) > 0.1:
		var rotation_direction = -sign(horizontal_input)
		
		# Always rotate smoothly internally
		smooth_rotation_angle += rotation_direction * rotation_speed * delta
		
		if smooth_rotation:
			# Smooth mode: use the smooth rotation directly
			rotation.y = smooth_rotation_angle
		else:
			# Stepped mode: snap smooth rotation to nearest 45° increment
			var step_size = deg_to_rad(45)
			var snapped_angle = round(smooth_rotation_angle / step_size) * step_size
			rotation.y = snapped_angle

func is_near_ground() -> bool:
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_position, 
		global_position + Vector3.DOWN * ground_check_distance
	)
	var result = space_state.intersect_ray(query)
	return result.size() > 0
