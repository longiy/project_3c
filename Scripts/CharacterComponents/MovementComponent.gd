# MovementComponent.gd
# Handles character physics movement with navigation and rotation

extends Node
class_name MovementComponent

# Movement properties
@export_group("Movement Speeds")
@export var walk_speed: float = 4.0
@export var run_speed: float = 6.0
@export var sprint_speed: float = 8.0

@export_group("Character Rotation")
@export var movement_rotation_speed: float = 8.0
@export var navigation_rotation_speed: float = 5.0
@export var camera_align_rotation_speed: float = 3.0
@export var snap_rotation_threshold: float = 0.1
@export var enable_navigation_rotation: bool = true
@export var enable_direction_snap: bool = false
@export var snap_angle_degrees: float = 45.0

@export_group("Physics")
@export var acceleration: float = 8.0
@export var deceleration: float = 10.0
@export var gravity: float = 9.8
@export var jump_velocity: float = 4.5

@export_group("Navigation")
@export var navigation_speed: float = 6.0
@export var destination_threshold: float = 0.3

# Core references
var character_core: CharacterBody3D
var camera_system: CameraSystem

# Movement state
var current_direction: Vector2 = Vector2.ZERO
var target_direction: Vector2 = Vector2.ZERO
var current_speed: float = 0.0
var target_speed: float = 0.0

# Action states
var is_sprinting: bool = false
var is_walking: bool = false
var is_jumping: bool = false

# Navigation state
var is_navigating: bool = false
var navigation_target: Vector3 = Vector3.ZERO

# Rotation state
var target_character_rotation: float = 0.0
var has_rotation_target: bool = false

func _ready():
	# Get references
	character_core = get_node("../../CharacterCore") as CharacterBody3D
	if not character_core:
		push_error("MovementComponent: CharacterCore not found")
		return
	
	camera_system = get_node("../../../CAMERA") as CameraSystem
	if not camera_system:
		push_error("MovementComponent: CAMERA system not found")
		return
	
	# Connect signals
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
	if is_navigating:
		calculate_navigation_movement(delta)
	else:
		calculate_direct_movement(delta)
	
	# Apply rotation
	if has_rotation_target and enable_navigation_rotation:
		apply_character_rotation(delta)
	
	# Apply movement
	character_core.move_and_slide()

# ===== SIGNAL CONNECTIONS =====
func connect_to_input_signals():
	# Connect to DirectControlComponent
	var direct_control = get_node("../../../CONTROL/ControlComponents/DirectControlComponent")
	if direct_control:
		if not direct_control.movement_command.is_connected(_on_movement_command):
			direct_control.movement_command.connect(_on_movement_command)
		if not direct_control.action_command.is_connected(_on_action_command):
			direct_control.action_command.connect(_on_action_command)
	
	# Connect to TargetControlComponent
	var target_control = get_node("../../../CONTROL/ControlComponents/TargetControlComponent")
	if target_control:
		if not target_control.navigate_command.is_connected(_on_navigate_command):
			target_control.navigate_command.connect(_on_navigate_command)
		if not target_control.character_look_command.is_connected(_on_character_look_command):
			target_control.character_look_command.connect(_on_character_look_command)

# ===== SIGNAL HANDLERS =====
func _on_movement_command(direction: Vector2, magnitude: float):
	target_direction = direction
	target_speed = get_speed_for_state() * magnitude

func _on_action_command(action: String, pressed: bool):
	match action:
		"jump": is_jumping = pressed and character_core.is_on_floor()
		"sprint": is_sprinting = pressed
		"walk": is_walking = pressed
		"reset": if pressed: reset_character_position()

func _on_navigate_command(target_position: Vector3):
	navigation_target = target_position
	is_navigating = true

func _on_character_look_command(target_direction: Vector3):
	if enable_navigation_rotation:
		target_character_rotation = atan2(target_direction.x, target_direction.z)
		has_rotation_target = true

# ===== MOVEMENT CALCULATION =====
func calculate_direct_movement(delta: float):
	# Smooth direction and speed
	current_direction = current_direction.lerp(target_direction, acceleration * delta)
	
	if target_direction.length() > 0:
		current_speed = lerp(current_speed, target_speed, acceleration * delta)
		# Rotate toward actual movement direction
		rotate_toward_movement_direction(delta)
	else:
		current_speed = lerp(current_speed, 0.0, deceleration * delta)
	
	# Apply movement
	var movement_3d = convert_to_world_space(current_direction)
	character_core.velocity.x = movement_3d.x * current_speed
	character_core.velocity.z = movement_3d.z * current_speed

func calculate_navigation_movement(delta: float):
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

# ===== ROTATION =====
func rotate_toward_movement_direction(delta: float):
	# Get the actual world movement direction
	var movement_3d = convert_to_world_space(current_direction)
	if movement_3d.length() > 0.1:  # Only rotate if there's meaningful movement
		var target_rotation = atan2(movement_3d.x, movement_3d.z)
		
		# Apply direction snapping if enabled
		if enable_direction_snap:
			target_rotation = snap_to_angle_increments(target_rotation)
			character_core.rotation.y = target_rotation  # Instant snap
		else:
			character_core.rotation.y = lerp_angle(
				character_core.rotation.y,
				target_rotation,
				movement_rotation_speed * delta
			)

func rotate_toward_camera_forward(delta: float):
	# Align character to face camera forward direction
	var camera_forward = -camera_system.get_camera_forward()
	camera_forward.y = 0
	camera_forward = camera_forward.normalized()
	
	var target_rotation = atan2(camera_forward.x, camera_forward.z)
	
	# Apply direction snapping if enabled
	if enable_direction_snap:
		target_rotation = snap_to_angle_increments(target_rotation)
		character_core.rotation.y = target_rotation  # Instant snap
	else:
		character_core.rotation.y = lerp_angle(
			character_core.rotation.y,
			target_rotation,
			camera_align_rotation_speed * delta
		)

func apply_character_rotation(delta: float):
	var current_rotation = character_core.rotation.y
	var rotation_diff = angle_difference(current_rotation, target_character_rotation)
	
	# Apply direction snapping if enabled
	var final_target = target_character_rotation
	if enable_direction_snap:
		final_target = snap_to_angle_increments(target_character_rotation)
		character_core.rotation.y = final_target  # Instant snap
		has_rotation_target = false
	else:
		if abs(rotation_diff) > snap_rotation_threshold:
			var new_rotation = lerp_angle(current_rotation, final_target, navigation_rotation_speed * delta)
			character_core.rotation.y = new_rotation
		else:
			character_core.rotation.y = final_target
			has_rotation_target = false

func snap_to_angle_increments(rotation: float) -> float:
	# Convert angle to radians
	var snap_angle_radians = deg_to_rad(snap_angle_degrees)
	
	# Round to nearest increment
	var snapped = round(rotation / snap_angle_radians) * snap_angle_radians
	
	# Normalize to [-PI, PI] range
	while snapped > PI:
		snapped -= TAU
	while snapped < -PI:
		snapped += TAU
	
	return snapped

func angle_difference(from: float, to: float) -> float:
	var diff = to - from
	while diff > PI: diff -= TAU
	while diff < -PI: diff += TAU
	return diff

# ===== UTILITIES =====
func get_speed_for_state() -> float:
	if is_sprinting: return sprint_speed
	if is_walking: return walk_speed
	return run_speed

func convert_to_world_space(input_direction: Vector2) -> Vector3:
	if not camera_system or input_direction.length() == 0:
		return Vector3.ZERO
	
	var camera_forward = -camera_system.get_camera_forward()
	var camera_right = camera_system.get_camera_right()
	
	camera_forward.y = 0
	camera_right.y = 0
	camera_forward = camera_forward.normalized()
	camera_right = camera_right.normalized()
	
	return (camera_right * input_direction.x + camera_forward * input_direction.y).normalized()

func finish_navigation():
	is_navigating = false
	has_rotation_target = false
	character_core.velocity.x = 0
	character_core.velocity.z = 0
	
	var target_control = get_node("../../../CONTROL/ControlComponents/TargetControlComponent")
	if target_control and target_control.has_method("on_destination_reached"):
		target_control.on_destination_reached()

func reset_character_position():
	character_core.global_position = Vector3.ZERO
	character_core.velocity = Vector3.ZERO
	is_navigating = false
	has_rotation_target = false

# ===== PUBLIC API =====
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

func get_debug_info() -> Dictionary:
	return {
		"current_speed": current_speed,
		"is_moving": get_is_moving(),
		"is_navigating": is_navigating,
		"navigation_target": navigation_target,
		"velocity": character_core.velocity if character_core else Vector3.ZERO,
		"has_rotation_target": has_rotation_target
	}
