extends CharacterBody3D

@export var speed = 8.0          ## Movement speed (m/s)
@export var jump_velocity = 6  ## Jump initial velocity (m/s)
@export var acceleration = 150.0  ## Acceleration rate (m/s²)
@export var deceleration = 200.0  ## Deceleration rate (m/s²)
@export var gravity_multiplier = 2
@export var coyote_time = 0.1    ## Time after leaving ground you can still jump (seconds)
@export var ground_check_distance = 0.2  ## Distance to check for ground (meters)
@export var max_jumps = 2        ## Total jumps allowed (1 = single, 2 = double, etc.)
@export var rotation_speed = 4.0  ## How fast character rotates to face movement direction
@export var smooth_rotation = true  ## Toggle between smooth and stepped rotation
@export var mesh_root: Node3D     ## Reference to the visual mesh for rotation
@export var allow_rotation_while_jumping = false  ## Enable/disable rotation during jump
@export var allow_rotation_while_stationary = true  ## Enable/disable rotation when not moving

var base_gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var coyote_timer = 0.0
var jumps_remaining = 0

func _physics_process(delta):
   # Gravity
	if not is_on_floor():
		velocity.y -= (base_gravity * gravity_multiplier) * delta
   
   # Reset jumps when touching or near ground
	if is_on_floor() or is_near_ground():
		coyote_timer = coyote_time
		jumps_remaining = max_jumps
	else:
		coyote_timer -= delta
   
   # Handle jump
	if Input.is_action_just_pressed("jump"):
		if (coyote_timer > 0 and jumps_remaining > 0) or (jumps_remaining > 0 and not is_on_floor()):
			velocity.y = jump_velocity
			jumps_remaining -= 1
			coyote_timer = 0
   
   # Get input
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

	# Check if character is moving
	var is_moving = abs(input_dir.y) > 0.1  # Forward/backward movement
	var is_in_air = not is_on_floor()

	# Handle rotation with conditions
	var can_rotate = true

	# Check jumping condition
	if is_in_air and not allow_rotation_while_jumping:
		can_rotate = false

	# Check stationary condition
	if not is_moving and not allow_rotation_while_stationary:
		can_rotate = false
   
	if can_rotate:
		handle_rotation(input_dir.x, delta)
   
	# Handle movement (always allowed)
	handle_movement(input_dir, delta)

	move_and_slide()

func handle_movement(input_dir: Vector2, delta: float):
   # Get current facing direction
	var current_rotation = mesh_root.rotation.y if mesh_root else rotation.y
	var forward = Vector3.FORWARD.rotated(Vector3.UP, current_rotation)

	# Calculate movement direction (forward/back)
	var movement_input = -input_dir.y  # Forward/backward
	var direction = (forward * movement_input).normalized()
   
	if abs(movement_input) > 0.1:
		velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0, deceleration * delta)

func handle_rotation(horizontal_input: float, delta: float):
   # Only rotate if there's left/right input
	if abs(horizontal_input) > 0.1:
		var rotation_direction = -sign(horizontal_input)  # Right = clockwise, Left = counter-clockwise
	   
		if smooth_rotation:
			# Smooth rotation
			var current_rot = mesh_root.rotation.y if mesh_root else rotation.y
			var target_rotation = current_rot + (rotation_direction * rotation_speed * delta)
			   
			if mesh_root:
				mesh_root.rotation.y = target_rotation
			else:
				rotation.y = target_rotation
		else:
		   # Stepped rotation
			var step_size = deg_to_rad(45)
			var target_rotation = (mesh_root.rotation.y if mesh_root else rotation.y) + (rotation_direction * step_size)
		   
			if mesh_root:
				mesh_root.rotation.y = target_rotation
			else:
					rotation.y = target_rotation

func is_near_ground() -> bool:
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_position, 
		global_position + Vector3.DOWN * ground_check_distance
	)
	var result = space_state.intersect_ray(query)
	return result.size() > 0
