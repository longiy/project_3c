# CharacterStatesBase.gd - Updated for MovementManager
class_name CharacterStateBase
extends State

var character: CharacterBody3D
var movement_manager: MovementManager

# Transition thresholds
var movement_stop_threshold: float = 0.1
var movement_start_threshold: float = 0.05

func enter():
	super.enter()
	character = owner_node as CharacterBody3D
	if not character:
		push_error("CharacterState requires CharacterBody3D owner")
		return
	
	movement_manager = character.get_node_or_null("MovementManager")
	if not movement_manager:
		push_error("CharacterState requires MovementManager component")

func update(delta: float):
	super.update(delta)
	handle_common_transitions()

# === TRANSITION LOGIC ===

func handle_common_transitions():
	"""Handle transitions with proper air/ground state respect"""
	if not movement_manager:
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
	"""Handle movement transitions only for ground states"""
	if not movement_manager:
		return
	
	# SAFETY CHECK: Only do movement transitions if actually grounded
	if not character.is_on_floor():
		return
	
	# Check if we should transition to a different ground state
	var target_state = movement_manager.should_transition_to_state(state_name)
	if target_state != "" and is_valid_ground_transition(target_state):
		change_to(target_state)

func is_valid_ground_transition(target_state: String) -> bool:
	"""Check if transition to target state is valid"""
	var valid_ground_states = ["idle", "walking", "running"]
	return target_state in valid_ground_states and character.is_on_floor()

# === MOVEMENT EXECUTION ===

func apply_ground_movement(delta: float):
	"""Apply movement while on ground"""
	if movement_manager:
		movement_manager.apply_ground_movement(delta)

func apply_air_movement(delta: float):
	"""Apply movement while in air"""
	if movement_manager:
		movement_manager.apply_air_movement(delta)
