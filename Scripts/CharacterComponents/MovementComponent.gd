# MovementComponent.gd
# Handles character physics movement in response to movement commands
# Connects to DirectControlComponent signals and applies movement to CharacterBody3D

extends Node
class_name MovementComponent

# Movement properties
@export_group("Movement Speeds")
@export var walk_speed: float = 4.0
@export var run_speed: float = 6.0
@export var sprint_speed: float = 8.0

@export_group("Physics")
@export var acceleration: float = 8.0
@export var deceleration: float = 10.0
@export var gravity: float = 9.8
@export var jump_velocity: float = 4.5

@export_group("Ground Detection")
@export var floor_max_angle: float = 0.785398  # 45 degrees in radians
@export var floor_snap_length: float = 0.1

# Internal state
var character_core: CharacterBody3D
var current_direction: Vector2 = Vector2.ZERO
var target_direction: Vector2 = Vector2.ZERO
var current_speed: float = 0.0
var target_speed: float = 0.0

# Movement state
var is_sprinting: bool = false
var is_walking: bool = false
var is_jumping: bool = false

# Camera reference for movement direction
var camera_system: CameraSystem

func _ready():
	# Get character core reference
	character_core = get_node("../../CharacterCore") as CharacterBody3D
	if not character_core:
		push_error("MovementComponent: CharacterCore not found")
		return
	
	# Get camera system reference
	camera_system = get_node("../../../CAMERA") as CameraSystem
	if not camera_system:
		push_error("MovementComponent: CAMERA system not found")
		return
	
	# Connect to DirectControlComponent signals
	connect_to_input_signals()
	
	print("MovementComponent: Initialized successfully")

func _physics_process(delta):
	if not character_core:
		return
	
	# Apply gravity
	if not character_core.is_on_floor():
		character_core.velocity.y -= gravity * delta
	
	# Handle jumping
	if is_jumping and character_core.is_on_floor():
		character_core.velocity.y = jump_velocity
		is_jumping = false
	
	# Calculate movement
	calculate_movement(delta)
	
	# Apply movement
	character_core.move_and_slide()

func connect_to_input_signals():
	# Connect to DirectControlComponent signals
	var direct_control = get_node("../../../CONTROL/ControlComponents/DirectControlComponent")
	if direct_control:
		# Connect movement command
		if direct_control.has_signal("movement_command"):
			direct_control.movement_command.connect(_on_movement_command)
			print("MovementComponent: Connected to movement_command")
		
		# Connect action command
		if direct_control.has_signal("action_command"):
			direct_control.action_command.connect(_on_action_command)
			print("MovementComponent: Connected to action_command")
	else:
		push_warning("MovementComponent: DirectControlComponent not found")

func _on_movement_command(direction: Vector2, magnitude: float):
	# Receive movement input from DirectControlComponent
	target_direction = direction
	
	# Set target speed based on movement modifiers
	if is_sprinting:
		target_speed = sprint_speed * magnitude
	elif is_walking:
		target_speed = walk_speed * magnitude
	else:
		target_speed = run_speed * magnitude

func _on_action_command(action: String, pressed: bool):
	# Handle action inputs
	match action:
		"jump":
			if pressed and character_core.is_on_floor():
				is_jumping = true
		"sprint":
			is_sprinting = pressed
		"walk":
			is_walking = pressed
		"reset":
			if pressed:
				reset_character_position()

func calculate_movement(delta: float):
	# Smooth direction changes
	current_direction = current_direction.lerp(target_direction, acceleration * delta)
	
	# Smooth speed changes
	if target_direction.length() > 0:
		current_speed = lerp(current_speed, target_speed, acceleration * delta)
	else:
		current_speed = lerp(current_speed, 0.0, deceleration * delta)
	
	# Convert 2D movement to 3D world space
	var movement_3d = convert_to_world_space(current_direction)
	
	# Apply to character velocity (preserve Y velocity for gravity/jumping)
	character_core.velocity.x = movement_3d.x * current_speed
	character_core.velocity.z = movement_3d.z * current_speed

func convert_to_world_space(input_direction: Vector2) -> Vector3:
	# Convert 2D input to 3D movement relative to camera orientation
	if not camera_system or input_direction.length() == 0:
		return Vector3.ZERO
	
	# Get camera forward and right vectors (flattened to ground plane)
	var camera_forward = -camera_system.get_camera_forward()
	var camera_right = camera_system.get_camera_right()
	
	# Flatten to ground plane
	camera_forward.y = 0
	camera_right.y = 0
	camera_forward = camera_forward.normalized()
	camera_right = camera_right.normalized()
	
	# Calculate movement vector
	var movement_vector = Vector3.ZERO
	movement_vector += camera_right * input_direction.x  # Left/Right
	movement_vector += camera_forward * input_direction.y  # Forward/Back
	
	return movement_vector.normalized()

func reset_character_position():
	# Reset character to origin
	if character_core:
		character_core.global_position = Vector3.ZERO
		character_core.velocity = Vector3.ZERO
		print("MovementComponent: Character position reset")

# Public API for other systems
func get_movement_speed() -> float:
	# Return current movement speed for animation system
	return current_speed / run_speed  # Normalized speed

func get_is_moving() -> bool:
	return current_speed > 0.1

func get_is_grounded() -> bool:
	return character_core.is_on_floor() if character_core else false

func get_movement_direction() -> Vector3:
	return Vector3(character_core.velocity.x, 0, character_core.velocity.z).normalized() if character_core else Vector3.ZERO

# Debug info
func get_debug_info() -> Dictionary:
	return {
		"current_speed": current_speed,
		"target_speed": target_speed,
		"is_grounded": get_is_grounded(),
		"is_moving": get_is_moving(),
		"movement_direction": get_movement_direction(),
		"is_sprinting": is_sprinting,
		"is_walking": is_walking,
		"velocity": character_core.velocity if character_core else Vector3.ZERO
	}
