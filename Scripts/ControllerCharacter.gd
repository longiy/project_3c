# ControllerCharacter.gd - Refactored with proper input arbitration
extends CharacterBody3D

@export_group("Debug")
@export var reset_position = Vector3(0, 1, 0)
@export var reset_rotation = Vector3(0, 0, 0)

@export_group("Components")
@export var animation_controller: AnimationController
@export var camera: Camera3D

@export_group("Movement Speeds")
@export var slow_walk_speed = 2.0
@export var walk_speed = 3.0
@export var run_speed = 6.0

@export_group("Movement Physics")
@export var slow_walk_acceleration = 50.0
@export var walk_acceleration = 50.0
@export var run_acceleration = 50.0
@export var deceleration = 50.0
@export var gravity_multiplier = 1

@export_group("Rotation")
@export var rotation_speed = 6
@export var camera_relative_movement = true

@export_group("Jumping")
@export var jump_velocity = 6
@export var max_jumps = 2
@export var coyote_time = 0.1
@export var ground_check_distance = 0.2

# Movement duration tracking
var input_start_time = 0.0
var is_input_active = false
var last_input_direction = Vector2.ZERO

# Runtime variables
var base_gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var coyote_timer = 0.0
var jumps_remaining = 0
var is_running = false
var is_slow_walking = false

# Input components - found automatically
var click_navigation_component: ClickNavigationComponent
var input_components: Array[Node] = []

func _ready():
	# Find input components automatically
	click_navigation_component = get_node_or_null("ClickNavigationComponent") as ClickNavigationComponent
	
	# Collect all input components for future extensibility
	for child in get_children():
		if child.has_method("get_movement_input"):
			input_components.append(child)
			print("Character: Found input component: ", child.name)
	
	if not animation_controller:
		push_warning("No AnimationController assigned - animations will not work")

func _physics_process(delta):
	# Apply gravity
	if not is_on_floor():
		velocity.y -= (base_gravity * gravity_multiplier) * delta
	
	
	# Handle coyote time and jump reset
	if is_on_floor():
		coyote_timer = coyote_time
		jumps_remaining = max_jumps
	else:
		coyote_timer -= delta
	
# 	Get input with proper arbitration
	var input_dir = get_current_input()
	
	# Track input duration
	var has_input_now = input_dir.length() > 0.1
	
	if has_input_now and not is_input_active:
		# Input just started
		input_start_time = Time.get_ticks_msec() / 1000.0
		is_input_active = true
	elif not has_input_now and is_input_active:
		# Input just stopped
		is_input_active = false
	
	last_input_direction = input_dir
	# Handle movement mode inputs
	is_slow_walking = Input.is_action_pressed("walk")
	is_running = Input.is_action_pressed("sprint") and not is_slow_walking
	
	# Handle reset
	if Input.is_action_just_pressed("reset"):
		reset_character_transform()
	
	# Handle jumping (immediate response needed)
	if Input.is_action_just_pressed("jump"):
		if (coyote_timer > 0 and jumps_remaining > 0) or (jumps_remaining > 0 and not is_on_floor()):
			velocity.y = jump_velocity
			jumps_remaining -= 1
			coyote_timer = 0
	
	# Calculate movement
	var movement_vector = calculate_movement_vector(input_dir)
	handle_movement_and_rotation(movement_vector, delta)
	
	move_and_slide()

func get_current_input() -> Vector2:
	"""Input arbitration - WASD always wins, then check input components"""
	
	# 1. WASD input has highest priority (immediate override)
	var wasd_input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	if wasd_input.length() > 0.1:
		# WASD overrides everything - tell all input components to cancel
		cancel_all_input_components()
		return wasd_input
	
	# 2. Check input components in order (click nav, gamepad, AI, etc.)
	for component in input_components:
		if component.has_method("is_active") and component.is_active():
			if component.has_method("get_movement_input"):
				return component.get_movement_input()
	
	# 3. No input
	return Vector2.ZERO

func cancel_all_input_components():
	"""Tell all input components to cancel their current actions"""
	for component in input_components:
		if component.has_method("cancel_input"):
			component.cancel_input()

func calculate_movement_vector(input_dir: Vector2) -> Vector3:
	var movement_vector = Vector3.ZERO
	
	if camera_relative_movement and camera:
		# Camera-relative movement
		var cam_transform = camera.global_transform.basis
		var cam_forward = Vector3(-cam_transform.z.x, 0, -cam_transform.z.z).normalized()
		var cam_right = Vector3(cam_transform.x.x, 0, cam_transform.x.z).normalized()
		
		movement_vector = cam_right * input_dir.x + cam_forward * (-input_dir.y)
	else:
		# World-coordinate movement
		movement_vector.x = input_dir.x
		movement_vector.z = input_dir.y
	
	return movement_vector

func handle_movement_and_rotation(movement_vector: Vector3, delta: float):
	# Determine speed and acceleration based on movement mode
	var current_speed: float
	var current_acceleration: float
	
	if is_slow_walking:
		current_speed = slow_walk_speed
		current_acceleration = slow_walk_acceleration
	elif is_running:
		current_speed = run_speed
		current_acceleration = run_acceleration
	else:
		current_speed = walk_speed
		current_acceleration = walk_acceleration
	
	# Apply movement
	var is_moving = movement_vector.length() > 0.1
	
	if is_moving:
		var movement_direction = movement_vector.normalized()
		
		# Apply movement
		velocity.x = move_toward(velocity.x, movement_direction.x * current_speed, current_acceleration * delta)
		velocity.z = move_toward(velocity.z, movement_direction.z * current_speed, current_acceleration * delta)
		
		# Apply rotation
		var target_rotation = atan2(movement_direction.x, movement_direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)
	else:
		# Decelerate
		velocity.x = move_toward(velocity.x, 0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0, deceleration * delta)

func reset_character_transform():
	global_position = reset_position
	rotation_degrees = reset_rotation
	velocity = Vector3.ZERO
	jumps_remaining = max_jumps
	coyote_timer = 0.0
	
	# Cancel all input components
	cancel_all_input_components()
	
	print("Character reset to: ", reset_position)

# PUBLIC METHODS for AnimationController to poll
func get_movement_speed() -> float:
	"""Get current horizontal movement speed"""
	return Vector3(velocity.x, 0, velocity.z).length()

func get_current_input_direction() -> Vector2:
	"""Get current input direction for animation blending"""
	return get_current_input()
	
	# Add public method for camera to check
func get_input_duration() -> float:
	"""Get how long current input has been active"""
	if is_input_active:
		var current_time = Time.get_ticks_msec() / 1000.0
		return current_time - input_start_time
	else:
		return 0.0

func is_input_sustained(min_duration: float = 0.3) -> bool:
	"""Check if input has been active for minimum duration"""
	return get_input_duration() >= min_duration
