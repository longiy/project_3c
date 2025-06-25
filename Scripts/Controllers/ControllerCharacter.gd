# ControllerCharacter.gd - Action system version
extends CharacterBody3D

# === INSPECTOR CONFIGURATION === (unchanged)
@export_group("Movement Speeds")
@export var walk_speed = 3.0
@export var run_speed = 6.0
@export var slow_walk_speed = 1.5
@export var air_speed_multiplier = 0.6

@export_group("Physics")
@export var ground_acceleration = 15.0
@export var air_acceleration = 8.0
@export var deceleration = 18.0
@export var gravity_multiplier = 1.0

@export_group("Input Response")
@export var input_deadzone = 0.05
@export var input_smoothing = 12.0
@export var min_input_duration = 0.08
@export var rotation_speed = 12.0

@export_group("Ground Detection")
@export var ground_check_distance = 0.2
@export var slope_limit_degrees = 45.0

@export_group("Components")
@export var animation_controller: AnimationController
@export var camera: Camera3D
@export var input_manager: InputManager
@export var jump_system: JumpSystem
@export var debug_helper: CharacterDebugHelper

# === RUNTIME VARIABLES ===
var base_gravity: float

# Movement modes (now handled by action system)
var is_slow_walking = false
var is_running = false

# State machine - child node
var state_machine: CharacterStateMachine
var action_system: ActionSystem

func _ready():
	setup_character()
	setup_state_machine()

func setup_character():
	"""Initialize character properties"""
	# Initialize gravity safely
	base_gravity = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	if base_gravity <= 0:
		base_gravity = 9.8
	
	if not animation_controller:
		push_warning("No AnimationController assigned")
	if not camera:
		push_warning("No Camera assigned - movement will not be camera-relative")
	if not input_manager:
		push_warning("No InputManager assigned - input will not work")
	if not jump_system:
		push_warning("No JumpSystem assigned - jumping will not work")

func setup_state_machine():
	"""Find and initialize the state machine and action system"""
	# Get state machine
	state_machine = get_node("CharacterStateMachine") as CharacterStateMachine
	if not state_machine:
		push_error("No CharacterStateMachine child node found!")
		return
	
	# Get action system
	action_system = get_node("ActionSystem") as ActionSystem
	if not action_system:
		push_error("No ActionSystem child node found!")
		return
	
	# Validate state machine setup
	if not state_machine.validate_state_setup():
		push_error("State machine validation failed!")

func _input(event):
	# Action system handles all input now through InputManager
	pass

func _physics_process(delta):
	if state_machine:
		state_machine.update(delta)

# === MOVEMENT CALCULATION === (unchanged)

func calculate_movement_vector(input_dir: Vector2) -> Vector3:
	"""Convert 2D input to 3D movement relative to camera"""
	if input_dir.length() == 0:
		return Vector3.ZERO
	
	var movement_vector = Vector3.ZERO
	
	if camera:
		var cam_transform = camera.global_transform.basis
		var cam_forward = Vector3(-cam_transform.z.x, 0, -cam_transform.z.z).normalized()
		var cam_right = Vector3(cam_transform.x.x, 0, cam_transform.x.z).normalized()
		movement_vector = cam_right * input_dir.x + cam_forward * (-input_dir.y)
	else:
		movement_vector = Vector3(input_dir.x, 0, input_dir.y)
	
	return movement_vector.normalized()

func get_target_speed() -> float:
	"""Get target speed based on current movement mode"""
	if is_slow_walking:
		return slow_walk_speed
	elif is_running:
		return run_speed
	else:
		return walk_speed

func get_target_acceleration() -> float:
	"""Get acceleration based on ground state"""
	return ground_acceleration if is_on_floor() else air_acceleration

# === PHYSICS HELPERS === (unchanged)

func apply_gravity(delta: float):
	"""Apply gravity if not grounded"""
	if not is_on_floor():
		velocity.y -= (base_gravity * gravity_multiplier) * delta

func apply_movement(movement_vector: Vector3, target_speed: float, acceleration: float, delta: float):
	"""Apply movement with acceleration"""
	if movement_vector.length() > 0:
		velocity.x = move_toward(velocity.x, movement_vector.x * target_speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, movement_vector.z * target_speed, acceleration * delta)
		rotate_toward_movement(movement_vector, delta)

func apply_deceleration(delta: float):
	"""Apply deceleration when no input"""
	velocity.x = move_toward(velocity.x, 0, deceleration * delta)
	velocity.z = move_toward(velocity.z, 0, deceleration * delta)

func rotate_toward_movement(movement_direction: Vector3, delta: float):
	"""Rotate character to face movement direction"""
	if movement_direction.length() > 0:
		var target_rotation = atan2(movement_direction.x, movement_direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)

func perform_jump(jump_force: float):
	"""Execute a jump - delegated to JumpSystem"""
	if jump_system:
		jump_system.perform_jump(jump_force)

# === GROUND STATE MANAGEMENT ===

func update_ground_state():
	"""Update ground-related timers and jump counts"""
	if jump_system:
		jump_system.update_ground_state()

# === INPUT HELPERS === (delegated to InputManager)

func get_input_duration() -> float:
	return input_manager.get_input_duration() if input_manager else 0.0

func is_input_sustained(min_duration: float = 0.3) -> bool:
	return input_manager.is_input_sustained(min_duration) if input_manager else false

func should_process_input() -> bool:
	return input_manager.should_process_input() if input_manager else false

func get_current_input_direction() -> Vector2:
	"""Get current input direction for animation blend spaces"""
	return get_smoothed_input()

func get_smoothed_input() -> Vector2:
	return input_manager.get_smoothed_input() if input_manager else Vector2.ZERO

# === JUMP HELPERS === (delegated to JumpSystem)

func can_jump() -> bool:
	return jump_system.can_jump() if jump_system else false

func can_air_jump() -> bool:
	return jump_system.can_air_jump() if jump_system else false

# === REMOVED: Old input handling methods ===
# handle_jump_input() - now handled by action system
# try_consume_jump_buffer() - now handled by action system
# cancel_all_input_components() - moved to InputManager

# === UTILITY METHODS ===

func get_movement_speed() -> float:
	"""Get current horizontal movement speed"""
	return Vector3(velocity.x, 0, velocity.z).length()

# === PUBLIC API ===

func get_current_state_name() -> String:
	return state_machine.get_current_state_name() if state_machine else "none"

func get_previous_state_name() -> String:
	return state_machine.get_previous_state_name() if state_machine else "none"

func reset_character():
	"""Reset character - called by action system"""
	if debug_helper:
		debug_helper.reset_character()

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get debug information"""
	if debug_helper:
		return debug_helper.get_comprehensive_debug_info()
	else:
		return {
			"current_state": get_current_state_name(),
			"movement_speed": get_movement_speed(),
			"is_grounded": is_on_floor(),
			"debug_helper_missing": true
		}
