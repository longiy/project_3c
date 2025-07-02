# MovementComponent.gd
# Handles character physics movement with simple direct navigation

extends Node
class_name MovementComponent

# Movement properties
@export_group("Movement Speeds")
@export var walk_speed: float = 4.0
@export var run_speed: float = 6.0
@export var sprint_speed: float = 8.0

@export_group("Rotation")
@export var rotation_speed: float = 8.0

@export_group("Physics")
@export var acceleration: float = 8.0
@export var deceleration: float = 10.0
@export var gravity: float = 9.8
@export var jump_velocity: float = 4.5

@export_group("Navigation")
@export var navigation_speed: float = 6.0
@export var destination_threshold: float = 0.3
@export var debug_navigation: bool = true

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
var is_navigating: bool = false

# Navigation properties (simplified)
var navigation_target: Vector3 = Vector3.ZERO

# Camera reference
var camera_system: CameraSystem

func _ready():
	# Get character core reference
	character_core = get_node("../../CharacterCore") as CharacterBody3D
	if not character_core:
		push_error("MovementComponent: CharacterCore not found")
		return
	
	print("MovementComponent: CharacterCore found")
	
	# Get camera system reference
	camera_system = get_node("../../../CAMERA") as CameraSystem
	if not camera_system:
		push_error("MovementComponent: CAMERA system not found")
		return
	
	# Connect to input signals
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
	
	# Calculate movement (navigation or direct input)
	if is_navigating:
		calculate_direct_navigation_movement(delta)
	else:
		calculate_movement(delta)
	
	# Apply movement
	character_core.move_and_slide()

func connect_to_input_signals():
	# Connect to DirectControlComponent signals
	var direct_control = get_node("../../../CONTROL/ControlComponents/DirectControlComponent")
	if direct_control:
		if direct_control.has_signal("movement_command"):
			direct_control.movement_command.connect(_on_movement_command)
		
		if direct_control.has_signal("action_command"):
			direct_control.action_command.connect(_on_action_command)
	else:
		push_warning("MovementComponent: DirectControlComponent not found")
	
	# Connect to TargetControlComponent signals
	var target_control = get_node("../../../CONTROL/ControlComponents/TargetControlComponent")
	if target_control:
		if target_control.has_signal("navigate_command"):
			target_control.navigate_command.connect(_on_navigate_command)
	else:
		push_warning("MovementComponent: TargetControlComponent not found")

func _on_movement_command(direction: Vector2, magnitude: float):
	target_direction = direction
	
	if is_sprinting:
		target_speed = sprint_speed * magnitude
	elif is_walking:
		target_speed = walk_speed * magnitude
	else:
		target_speed = run_speed * magnitude

func _on_action_command(action: String, pressed: bool):
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

func _on_navigate_command(target_position: Vector3):
	navigation_target = target_position
	is_navigating = true

func calculate_movement(delta: float):
	current_direction = current_direction.lerp(target_direction, acceleration * delta)
	
	if target_direction.length() > 0:
		current_speed = lerp(current_speed, target_speed, acceleration * delta)
	else:
		current_speed = lerp(current_speed, 0.0, deceleration * delta)
	
	var movement_3d = convert_to_world_space(current_direction)
	character_core.velocity.x = movement_3d.x * current_speed
	character_core.velocity.z = movement_3d.z * current_speed
	
	# Rotate character toward camera forward direction when moving
	if target_direction.length() > 0:
		# Get camera forward direction (flattened to XZ plane)
		var camera_forward = -camera_system.get_camera_forward()
		camera_forward.y = 0
		camera_forward = camera_forward.normalized()
		
		# Calculate target rotation based on camera forward
		var target_rotation = atan2(camera_forward.x, camera_forward.z)
		
		# Smoothly rotate character toward camera forward
		character_core.rotation.y = lerp_angle(
			character_core.rotation.y,
			target_rotation,
			rotation_speed * delta
		)
	


func calculate_direct_navigation_movement(delta: float):
	if not is_navigating:
		return
	
	var current_position = character_core.global_position
	var distance_to_target = Vector2(
		navigation_target.x - current_position.x,
		navigation_target.z - current_position.z
	).length()
	
	if distance_to_target < destination_threshold:
		finish_navigation()
		return
	
	var direction = (navigation_target - current_position).normalized()
	character_core.velocity.x = direction.x * navigation_speed
	character_core.velocity.z = direction.z * navigation_speed

func finish_navigation():
	is_navigating = false
	character_core.velocity.x = 0
	character_core.velocity.z = 0
	
	var target_control = get_node("../../../CONTROL/ControlComponents/TargetControlComponent")
	if target_control and target_control.has_method("on_destination_reached"):
		target_control.on_destination_reached()

func convert_to_world_space(input_direction: Vector2) -> Vector3:
	if not camera_system or input_direction.length() == 0:
		return Vector3.ZERO
	
	var camera_forward = -camera_system.get_camera_forward()
	var camera_right = camera_system.get_camera_right()
	
	camera_forward.y = 0
	camera_right.y = 0
	camera_forward = camera_forward.normalized()
	camera_right = camera_right.normalized()
	
	var movement_vector = Vector3.ZERO
	movement_vector += camera_right * input_direction.x
	movement_vector += camera_forward * input_direction.y
	
	return movement_vector.normalized()

func reset_character_position():
	if character_core:
		character_core.global_position = Vector3.ZERO
		character_core.velocity = Vector3.ZERO
		is_navigating = false

# Public API
func get_movement_speed() -> float:
	return current_speed / run_speed

func get_is_moving() -> bool:
	return current_speed > 0.1 or is_navigating

func get_is_navigating() -> bool:
	return is_navigating

func get_is_grounded() -> bool:
	return character_core.is_on_floor() if character_core else false

func get_movement_direction() -> Vector3:
	return Vector3(character_core.velocity.x, 0, character_core.velocity.z).normalized() if character_core else Vector3.ZERO

# Debug info
func get_debug_info() -> Dictionary:
	return {
		"current_speed": current_speed,
		"is_moving": get_is_moving(),
		"is_navigating": is_navigating,
		"navigation_target": navigation_target,
		"velocity": character_core.velocity if character_core else Vector3.ZERO
	}
