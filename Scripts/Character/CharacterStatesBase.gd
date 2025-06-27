# CharacterStatesBase.gd - FIXED: Prevent airborne→walking transitions
class_name CharacterStateBase
extends State

var character: CharacterBody3D
var action_system: ActionSystem
var movement_calculator: MovementCalculator
var movement_state_manager: MovementStateManager

# Transition thresholds
var movement_stop_threshold: float = 0.1
var movement_start_threshold: float = 0.05

func enter():
	super.enter()
	character = owner_node as CharacterBody3D
	if not character:
		push_error("CharacterState requires CharacterBody3D owner")
		return
	
	action_system = character.get_node_or_null("ActionSystem")
	movement_calculator = character.get_node_or_null("MovementCalculator")
	movement_state_manager = character.get_node_or_null("MovementStateManager")
	
	if not movement_state_manager:
		push_error("CharacterState requires MovementStateManager component")

func update(delta: float):
	super.update(delta)
	handle_common_transitions()

# === FIXED TRANSITION LOGIC ===

func handle_common_transitions():
	"""Handle transitions with proper air/ground state respect"""
	if not movement_state_manager:
		return
	
	# PRIORITY 1: Air/Ground physics transitions (highest priority)
	if should_transition_to_air():
		change_to("airborne")
		return
	
	if should_transition_to_ground():
		change_to("landing")
		return
	
	# PRIORITY 2: Movement-based transitions (only for ground states)
	if can_do_movement_transitions() and is_grounded_state():
		handle_movement_transitions()

func should_transition_to_air() -> bool:
	"""Check if should transition to airborne state"""
	var ground_states = ["idle", "walking", "running", "landing"]
	return state_name in ground_states and not character.is_on_floor()

func should_transition_to_ground() -> bool:
	"""Check if should transition from air to ground"""
	var air_states = ["jumping", "airborne"]
	return state_name in air_states and character.is_on_floor()

func is_grounded_state() -> bool:
	"""Check if current state is a ground state"""
	var ground_states = ["idle", "walking", "running", "landing"]
	return state_name in ground_states

func is_air_state() -> bool:
	"""Check if current state is an air state"""
	var air_states = ["jumping", "airborne"]
	return state_name in air_states

func can_do_movement_transitions() -> bool:
	"""Check if this state should handle movement-based transitions"""
	var no_movement_transition_states = ["jumping", "landing"]
	return not (state_name in no_movement_transition_states)

func handle_movement_transitions():
	"""FIXED: Handle movement transitions only for ground states"""
	if not movement_state_manager:
		return
	
	# SAFETY CHECK: Only do movement transitions if actually grounded
	if not character.is_on_floor():
		return
	
	# Check if we should transition to a different ground state
	var target_state = movement_state_manager.should_transition_to_state(state_name)
	if target_state != "" and is_valid_ground_transition(target_state):
		change_to(target_state)

func is_valid_ground_transition(target_state: String) -> bool:
	"""Check if transition to target state is valid"""
	var valid_ground_states = ["idle", "walking", "running"]
	return target_state in valid_ground_states and character.is_on_floor()

# === ACTION SYSTEM INTERFACE ===

func can_execute_action(action: Action) -> bool:
	"""Default action handling"""
	match action.name:
		"move_start", "move_update", "move_end":
			return can_handle_movement_action(action)
		"sprint_start", "sprint_end", "slow_walk_start", "slow_walk_end":
			return can_handle_mode_action(action)
		"reset":
			return true
		_:
			return false

func execute_action(action: Action):
	"""Execute actions through state manager"""
	if not movement_state_manager:
		return
	
	match action.name:
		"move_start", "move_update", "move_end":
			movement_state_manager.handle_movement_action(action)
		"sprint_start", "sprint_end", "slow_walk_start", "slow_walk_end":
			movement_state_manager.handle_mode_action(action)
		"reset":
			character.reset_character()
		_:
			push_warning("Unhandled action in ", state_name, ": ", action.name)

# === MOVEMENT EXECUTION ===

func apply_ground_movement(delta: float):
	"""Apply movement while on ground"""
	if not movement_calculator or not movement_state_manager:
		return
	
	if movement_state_manager.is_movement_active and movement_state_manager.current_input_direction.length() > 0:
		var movement_3d = movement_calculator.calculate_movement_vector(movement_state_manager.current_input_direction)
		var target_speed = movement_calculator.get_target_speed(movement_state_manager.is_running, movement_state_manager.is_slow_walking)
		var acceleration = movement_calculator.get_acceleration(character.is_on_floor())
		
		movement_calculator.apply_movement(movement_3d, target_speed, acceleration, delta)
	else:
		movement_calculator.apply_deceleration(delta)

func apply_air_movement(delta: float):
	"""Apply movement while in air"""
	if not movement_calculator or not movement_state_manager:
		return
	
	if movement_state_manager.is_movement_active and movement_state_manager.current_input_direction.length() > 0:
		var movement_3d = movement_calculator.calculate_movement_vector(movement_state_manager.current_input_direction)
		movement_calculator.apply_air_movement(movement_3d, movement_state_manager.is_running, movement_state_manager.is_slow_walking, delta)

# === CONDITION HELPERS ===

func can_handle_movement_action(action: Action) -> bool:
	"""Override in child states to restrict movement actions"""
	return true

func can_handle_mode_action(action: Action) -> bool:
	"""Override in child states to restrict mode changes"""
	return true

# === UTILITY METHODS ===

func transition_and_forward_action(new_state_name: String, action: Action):
	"""Transition to new state and forward the action to it"""
	change_to(new_state_name)
	
	if state_machine and state_machine.current_state:
		var new_state = state_machine.current_state
		if new_state != self and new_state.has_method("execute_action"):
			new_state.execute_action(action)
