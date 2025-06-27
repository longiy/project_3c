# ControllerCharacter.gd - FIXED: Using MovementStateManager
extends CharacterBody3D

@export_group("Physics")
@export var gravity_multiplier = 1.0

@export_group("Components")
@export var animation_controller: AnimationController
@export var camera: Camera3D
@export var input_manager: InputManager
@export var jump_system: JumpSystem
@export var debug_helper: CharacterDebugHelper

# === SIGNALS (Forwarded from MovementStateManager) ===
signal ground_state_changed(is_grounded: bool)
signal jump_performed(jump_force: float, is_air_jump: bool)

# Internal state
var last_emitted_grounded: bool = true
var base_gravity: float

var state_machine: CharacterStateMachine
var action_system: ActionSystem
var movement_calculator: MovementCalculator
var movement_state_manager: MovementStateManager

func _ready():
	setup_character()
	setup_state_machine()
	setup_movement_calculator()
	setup_movement_state_manager()

func setup_character():
	base_gravity = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	if base_gravity <= 0:
		base_gravity = 9.8
	
	last_emitted_grounded = is_on_floor()

func setup_state_machine():
	state_machine = get_node("CharacterStateMachine") as CharacterStateMachine
	if not state_machine:
		push_error("No CharacterStateMachine child node found!")
		return
	
	action_system = get_node("ActionSystem") as ActionSystem
	if not action_system:
		push_error("No ActionSystem child node found!")
		return

func setup_movement_calculator():
	movement_calculator = get_node_or_null("MovementCalculator")
	if not movement_calculator:
		movement_calculator = MovementCalculator.new()
		movement_calculator.name = "MovementCalculator"
		add_child(movement_calculator)
	
	if camera:
		movement_calculator.setup_camera_reference(camera)

func setup_movement_state_manager():
	"""Setup centralized movement state manager"""
	movement_state_manager = get_node_or_null("MovementStateManager")
	if not movement_state_manager:
		movement_state_manager = MovementStateManager.new()
		movement_state_manager.name = "MovementStateManager"
		add_child(movement_state_manager)
	
	# Connect to animation controller
	if animation_controller:
		movement_state_manager.movement_state_changed.connect(animation_controller._on_movement_state_changed)
		movement_state_manager.movement_mode_changed.connect(animation_controller._on_movement_mode_changed)
		movement_state_manager.speed_changed.connect(animation_controller._on_speed_changed)

func _physics_process(delta):
	if state_machine:
		state_machine.update(delta)
	
	emit_ground_state_changes()

# === MOVEMENT INTERFACE (Delegates to components) ===

func calculate_movement_vector(input_dir: Vector2) -> Vector3:
	return movement_calculator.calculate_movement_vector(input_dir)

func apply_movement(movement_vector: Vector3, target_speed: float, acceleration: float, delta: float):
	movement_calculator.apply_movement(movement_vector, target_speed, acceleration, delta)

func apply_deceleration(delta: float):
	movement_calculator.apply_deceleration(delta)

func get_target_speed() -> float:
	return movement_calculator.get_target_speed(
		movement_state_manager.is_running if movement_state_manager else false,
		movement_state_manager.is_slow_walking if movement_state_manager else false
	)

func get_target_acceleration() -> float:
	return movement_calculator.get_acceleration(is_on_floor())

func get_movement_speed() -> float:
	return movement_calculator.get_movement_speed()

# === COMPATIBILITY PROPERTIES (For existing code) ===

var is_running: bool:
	get:
		return movement_state_manager.is_running if movement_state_manager else false
	set(value):
		if movement_state_manager:
			movement_state_manager.schedule_mode_change("running", value)

var is_slow_walking: bool:
	get:
		return movement_state_manager.is_slow_walking if movement_state_manager else false
	set(value):
		if movement_state_manager:
			movement_state_manager.schedule_mode_change("slow_walking", value)

# === PHYSICS ===

func apply_gravity(delta: float):
	if not is_on_floor():
		velocity.y -= (base_gravity * gravity_multiplier) * delta

# === JUMP SYSTEM ===

func perform_jump(jump_force: float):
	if jump_system:
		var was_grounded = is_on_floor()
		jump_system.perform_jump(jump_force)
		jump_performed.emit(jump_force, not was_grounded)

func update_ground_state():
	if jump_system:
		jump_system.update_ground_state()

func can_jump() -> bool:
	return jump_system.can_jump() if jump_system else false

func can_air_jump() -> bool:
	return jump_system.can_air_jump() if jump_system else false

# === SIGNAL EMISSION ===

func emit_ground_state_changes():
	var current_grounded = is_on_floor()
	if current_grounded != last_emitted_grounded:
		last_emitted_grounded = current_grounded
		ground_state_changed.emit(current_grounded)

# === DEPRECATED METHODS (For compatibility) ===

func emit_movement_mode_changes():
	"""Deprecated - MovementStateManager handles this now"""
	pass

# === STATE MACHINE INTERFACE ===

func get_current_state_name() -> String:
	return state_machine.get_current_state_name() if state_machine else "none"

func get_previous_state_name() -> String:
	return state_machine.get_previous_state_name() if state_machine else "none"

# === UTILITY METHODS ===

func reset_character():
	if debug_helper:
		debug_helper.reset_character()

func get_debug_info() -> Dictionary:
	if debug_helper:
		return debug_helper.get_comprehensive_debug_info()
	else:
		return {
			"current_state": get_current_state_name(),
			"movement_speed": get_movement_speed(),
			"is_grounded": is_on_floor(),
			"debug_helper_missing": true
		}
