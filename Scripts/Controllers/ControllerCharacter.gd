# ControllerCharacter.gd - Action system version (FIXED)
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

# === NEW SIGNALS (Add after existing exports) ===
signal movement_mode_changed(is_running: bool, is_slow_walking: bool)
signal speed_changed(new_speed: float)
signal ground_state_changed(is_grounded: bool)
signal movement_state_changed(is_moving: bool, direction: Vector2, magnitude: float)
signal jump_performed(jump_force: float, is_air_jump: bool)

# === TRACKING VARIABLES (Add to runtime variables section) ===
var last_emitted_speed: float = 0.0
var last_emitted_grounded: bool = true
var last_emitted_running: bool = false
var last_emitted_slow_walking: bool = false

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
	# TEST: Connect to own signals to verify they work
	movement_mode_changed.connect(_on_movement_mode_changed)
	speed_changed.connect(_on_speed_changed)
	ground_state_changed.connect(_on_ground_state_changed)

func _on_movement_mode_changed(running: bool, slow_walking: bool):
	print("🏃 Mode changed: Running=", running, " SlowWalk=", slow_walking)

func _on_speed_changed(speed: float):
	print("💨 Speed changed: ", speed)

func _on_ground_state_changed(grounded: bool):
	print("🌍 Ground state: ", grounded)

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

		# NEW: Initialize tracking variables
	last_emitted_speed = 0.0
	last_emitted_grounded = is_on_floor()
	last_emitted_running = is_running
	last_emitted_slow_walking = is_slow_walking

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
	# All input now handled by InputManager -> ActionSystem
	pass

# === MODIFY EXISTING _physics_process ===
func _physics_process(delta):
	if state_machine:
		state_machine.update(delta)
	
	# NEW: Emit speed changes
	emit_speed_changes()
	
	# NEW: Emit ground state changes  
	emit_ground_state_changes()

# === NEW EMISSION METHODS ===

func emit_speed_changes():
	"""Emit speed changes when movement speed changes significantly"""
	var current_speed = get_movement_speed()
	if abs(current_speed - last_emitted_speed) > 0.5:  # Threshold to avoid spam
		last_emitted_speed = current_speed
		speed_changed.emit(current_speed)

func emit_ground_state_changes():
	"""Emit ground state changes when character lands/leaves ground"""
	var current_grounded = is_on_floor()
	if current_grounded != last_emitted_grounded:
		last_emitted_grounded = current_grounded
		ground_state_changed.emit(current_grounded)

func emit_movement_mode_changes():
	"""Emit mode changes when sprint/walk modes change"""
	if is_running != last_emitted_running or is_slow_walking != last_emitted_slow_walking:
		last_emitted_running = is_running
		last_emitted_slow_walking = is_slow_walking
		movement_mode_changed.emit(is_running, is_slow_walking)

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
		var was_grounded = is_on_floor()
		jump_system.perform_jump(jump_force)
		
		# NEW: Emit jump event
		jump_performed.emit(jump_force, not was_grounded)

# === GROUND STATE MANAGEMENT ===

func update_ground_state():
	"""Update ground-related timers and jump counts"""
	if jump_system:
		jump_system.update_ground_state()

# === NEW: Action-based input helpers ===

func get_current_input_direction() -> Vector2:
	"""Get current input direction from action system state"""
	if state_machine and state_machine.current_state:
		var current_state = state_machine.current_state
		if current_state.has_method("get_current_movement_input"):
			return current_state.get_current_movement_input()
	return Vector2.ZERO

# === LEGACY API (marked for removal) ===

func get_input_duration() -> float:
	"""LEGACY: Use state machine action state instead"""
	if state_machine and state_machine.current_state:
		var current_state = state_machine.current_state
		if current_state.has_method("get_movement_duration"):
			return current_state.get_movement_duration()
	return 0.0

func is_input_sustained(min_duration: float = 0.3) -> bool:
	"""LEGACY: Use state machine action state instead"""
	if state_machine and state_machine.current_state:
		var current_state = state_machine.current_state
		if current_state.has_method("is_input_sustained"):
			return current_state.is_input_sustained(min_duration)
	return false

func should_process_input() -> bool:
	"""LEGACY: Use state machine action state instead"""
	if state_machine and state_machine.current_state:
		var current_state = state_machine.current_state
		if current_state.has_method("should_process_movement"):
			return current_state.should_process_movement()
	return false

func get_smoothed_input() -> Vector2:
	"""LEGACY: Use get_current_input_direction() instead"""
	return get_current_input_direction()

# === JUMP HELPERS === (delegated to JumpSystem)

func can_jump() -> bool:
	return jump_system.can_jump() if jump_system else false

func can_air_jump() -> bool:
	return jump_system.can_air_jump() if jump_system else false

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
