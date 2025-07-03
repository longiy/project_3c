# MovementComponent.gd
# Handles character physics movement with navigation and rotation
# Cleaned: Export references, organized function order, removed hardcoded paths

extends Node
class_name MovementComponent

# ===== SIGNALS =====
# (Add any signals here if needed in future)

# ===== EXPORTS & CONFIGURATION =====
@export_group("Component References")
@export var direct_control_component: DirectControlComponent
@export var target_control_component: TargetControlComponent
@export var gamepad_control_component: GamepadControlComponent

@export_group("Movement Speeds")
@export var walk_speed: float = 4.0
@export var run_speed: float = 6.0
@export var sprint_speed: float = 8.0

@export_group("Physics")
@export var acceleration: float = 8.0
@export var deceleration: float = 10.0
@export var gravity: float = 9.8
@export var jump_velocity: float = 4.5

@export_group("Character Rotation")
@export var movement_rotation_speed: float = 12
@export var navigation_rotation_speed: float = 12
@export var camera_align_rotation_speed: float = 12
@export var snap_rotation_threshold: float = 0.1
@export var enable_navigation_rotation: bool = true
@export var enable_direction_snap: bool = false
@export var snap_angle_degrees: float = 45.0

@export_group("Navigation")
@export var navigation_speed: float = 6.0
@export var destination_threshold: float = 0.3

# ===== CORE REFERENCES =====
var character_core: CharacterBody3D
var camera_system: CameraSystem

# ===== MOVEMENT STATE =====
var current_direction: Vector2 = Vector2.ZERO
var target_direction: Vector2 = Vector2.ZERO
var current_speed: float = 0.0
var target_speed: float = 0.0

# ===== ACTION STATE =====
var is_sprinting: bool = false
var is_walking: bool = false
var is_jumping: bool = false

# ===== NAVIGATION STATE =====
var is_navigating: bool = false
var navigation_target: Vector3 = Vector3.ZERO

# ===== ROTATION STATE =====
var target_character_rotation: float = 0.0
var has_rotation_target: bool = false

# ===== DRAG STOP STATE =====
var is_stopping_from_drag: bool = false
var is_drag_stopping: bool = false

# ===== INITIALIZATION =====
func _ready():
	if not find_core_references():
		return
	
	call_deferred("connect_to_input_signals")
	print("MovementComponent: Initialized successfully")

func find_core_references() -> bool:
	character_core = get_node("../../CharacterCore") as CharacterBody3D
	if not character_core:
		push_error("MovementComponent: CharacterCore not found")
		return false
	
	camera_system = get_node("../../../CAMERA") as CameraSystem
	if not camera_system:
		push_error("MovementComponent: CAMERA system not found")
		return false
	
	return true

func connect_to_input_signals():
	connect_direct_control_signals()
	connect_target_control_signals()
	connect_gamepad_control_signals()

func connect_direct_control_signals():
	if direct_control_component:
		if not direct_control_component.movement_command.is_connected(_on_movement_command):
			direct_control_component.movement_command.connect(_on_movement_command)
		if not direct_control_component.action_command.is_connected(_on_action_command):
			direct_control_component.action_command.connect(_on_action_command)

func connect_target_control_signals():
	if target_control_component:
		if not target_control_component.navigate_command.is_connected(_on_navigate_command):
			target_control_component.navigate_command.connect(_on_navigate_command)
		if not target_control_component.character_look_command.is_connected(_on_character_look_command):
			target_control_component.character_look_command.connect(_on_character_look_command)
		if not target_control_component.stop_navigation_command.is_connected(_on_stop_navigation_command):
			target_control_component.stop_navigation_command.connect(_on_stop_navigation_command)

func connect_gamepad_control_signals():
	if gamepad_control_component:
		if not gamepad_control_component.movement_command.is_connected(_on_movement_command):
			gamepad_control_component.movement_command.connect(_on_movement_command)
		if not gamepad_control_component.action_command.is_connected(_on_action_command):
			gamepad_control_component.action_command.connect(_on_action_command)

# ===== PHYSICS PROCESSING =====
func _physics_process(delta):
	if not character_core:
		return
	
	apply_gravity(delta)
	handle_jumping()
	calculate_movement(delta)
	apply_rotation(delta)
	character_core.move_and_slide()

func apply_gravity(delta: float):
	if not character_core.is_on_floor():
		character_core.velocity.y -= gravity * delta

func handle_jumping():
	if is_jumping and character_core.is_on_floor():
		character_core.velocity.y = jump_velocity
		is_jumping = false

func calculate_movement(delta: float):
	if is_navigating:
		calculate_navigation_movement(delta)
	else:
		calculate_direct_movement(delta)

func apply_rotation(delta: float):
	if has_rotation_target and enable_navigation_rotation:
		apply_character_rotation(delta)

# ===== MOVEMENT CALCULATION =====
func calculate_direct_movement(delta: float):
	# Smooth direction and speed
	current_direction = current_direction.lerp(target_direction, acceleration * delta)
	
	if target_direction.length() > 0:
		current_speed = lerp(current_speed, target_speed, acceleration * delta)
		rotate_toward_movement_direction(delta)
	else:
		current_speed = lerp(current_speed, 0.0, deceleration * delta)
	
	# Apply movement
	var movement_3d = convert_to_world_space(current_direction)
	character_core.velocity.x = movement_3d.x * current_speed
	character_core.velocity.z = movement_3d.z * current_speed

func calculate_navigation_movement(delta: float):
	if is_drag_stopping:
		handle_drag_stop_deceleration(delta)
		return
	
	handle_normal_navigation(delta)

func handle_drag_stop_deceleration(delta: float):
	# Smooth deceleration for drag stops
	var current_speed = Vector2(character_core.velocity.x, character_core.velocity.z).length()
	current_speed = lerp(current_speed, 0.0, deceleration * delta)
	
	if current_speed < 0.1:
		stop_character_movement()
	else:
		maintain_deceleration_direction(current_speed)

func stop_character_movement():
	character_core.velocity.x = 0
	character_core.velocity.z = 0
	is_drag_stopping = false
	is_navigating = false

func maintain_deceleration_direction(current_speed: float):
	var direction = Vector2(character_core.velocity.x, character_core.velocity.z).normalized()
	character_core.velocity.x = direction.x * current_speed
	character_core.velocity.z = direction.y * current_speed

func handle_normal_navigation(delta: float):
	var current_position = character_core.global_position
	var distance_to_target = Vector2(
		navigation_target.x - current_position.x,
		navigation_target.z - current_position.z
	).length()
	
	if distance_to_target < destination_threshold:
		finish_navigation()
		return
	
	apply_navigation_velocity(current_position)

func apply_navigation_velocity(current_position: Vector3):
	var direction = (navigation_target - current_position).normalized()
	character_core.velocity.x = direction.x * navigation_speed
	character_core.velocity.z = direction.z * navigation_speed

# ===== ROTATION HANDLING =====
func rotate_toward_movement_direction(delta: float):
	var movement_3d = convert_to_world_space(current_direction)
	if movement_3d.length() > 0.1:
		var target_rotation = atan2(movement_3d.x, movement_3d.z)
		
		if enable_direction_snap:
			apply_snapped_rotation(target_rotation)
		else:
			apply_smooth_movement_rotation(target_rotation, delta)

func apply_snapped_rotation(target_rotation: float):
	target_rotation = snap_to_angle_increments(target_rotation)
	character_core.rotation.y = target_rotation

func apply_smooth_movement_rotation(target_rotation: float, delta: float):
	character_core.rotation.y = lerp_angle(
		character_core.rotation.y, 
		target_rotation, 
		movement_rotation_speed * delta
	)

func apply_character_rotation(delta: float):
	if enable_direction_snap:
		apply_snapped_character_rotation()
	else:
		apply_smooth_character_rotation(delta)

func apply_snapped_character_rotation():
	# Use same snapping logic as movement rotation
	var snapped_rotation = snap_to_angle_increments(target_character_rotation)
	character_core.rotation.y = snapped_rotation
	has_rotation_target = false

func apply_smooth_character_rotation(delta: float):
	character_core.rotation.y = lerp_angle(
		character_core.rotation.y,
		target_character_rotation,
		navigation_rotation_speed * delta
	)
	
	if abs(angle_difference(character_core.rotation.y, target_character_rotation)) < snap_rotation_threshold:
		character_core.rotation.y = target_character_rotation
		has_rotation_target = false

# ===== UTILITY FUNCTIONS =====
func convert_to_world_space(direction: Vector2) -> Vector3:
	if not camera_system or not camera_system.camera_core:
		return Vector3(direction.x, 0, direction.y)
	
	var camera_transform = camera_system.camera_core.global_transform
	var camera_forward = camera_transform.basis.z  # Changed: removed negative sign
	var camera_right = camera_transform.basis.x
	
	camera_forward.y = 0
	camera_right.y = 0
	camera_forward = camera_forward.normalized()
	camera_right = camera_right.normalized()
	
	return (camera_right * direction.x + camera_forward * direction.y).normalized()

func snap_to_angle_increments(angle: float) -> float:
	var snap_radians = deg_to_rad(snap_angle_degrees)
	return round(angle / snap_radians) * snap_radians

func get_speed_for_state() -> float:
	if is_sprinting:
		return sprint_speed
	elif is_walking:
		return walk_speed
	else:
		return run_speed

func finish_navigation():
	is_navigating = false
	navigation_target = Vector3.ZERO
	target_direction = Vector2.ZERO
	target_speed = 0.0

func reset_character_position():
	if character_core:
		character_core.global_position = Vector3.ZERO
		character_core.velocity = Vector3.ZERO

# ===== SIGNAL HANDLERS =====
func _on_movement_command(direction: Vector2, magnitude: float):
	target_direction = direction
	target_speed = get_speed_for_state() * magnitude

func _on_action_command(action: String, pressed: bool):
	match action:
		"jump": 
			is_jumping = pressed and character_core.is_on_floor()
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

func _on_character_look_command(target_direction_3d: Vector3):
	if enable_navigation_rotation:
		target_character_rotation = atan2(target_direction_3d.x, target_direction_3d.z)
		has_rotation_target = true

func _on_stop_navigation_command():
	# This only gets called for drag stops, not normal clicks
	is_drag_stopping = true
	navigation_target = Vector3.ZERO
