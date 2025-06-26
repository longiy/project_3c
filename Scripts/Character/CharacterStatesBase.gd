# CharacterStatesBase.gd - CLEANED: Consolidated transitions, no debug prints
class_name CharacterStateBase
extends State

var character: CharacterBody3D
var action_system: ActionSystem

# Movement state (managed through actions)
var current_movement_vector: Vector2 = Vector2.ZERO
var movement_magnitude: float = 0.0
var movement_start_time: float = 0.0
var is_movement_active: bool = false

# Transition thresholds (configurable per character type)
var movement_stop_threshold: float = 0.1
var movement_start_threshold: float = 0.05

func enter():
	super.enter()
	character = owner_node as CharacterBody3D
	if not character:
		push_error("CharacterState requires CharacterBody3D owner")
		return
	
	# Get action system reference
	action_system = character.get_node_or_null("ActionSystem")
	if not action_system:
		push_warning("No ActionSystem found - actions will not work")

func update(delta: float):
	super.update(delta)
	
	# Handle common transitions that apply to all states
	handle_common_transitions()

# === CONSOLIDATED TRANSITION LOGIC ===

func handle_common_transitions():
	"""Handle transitions common to all states - override in child states to add specific logic"""
	
	# Universal air state transition (applies to all ground states)
	if should_transition_to_air():
		change_to("airborne")
		return
	
	# Ground landing transition (applies when airborne)
	if should_transition_to_ground():
		change_to("landing")
		return
	
	# Movement-based transitions (only for appropriate states)
	if can_do_movement_transitions():
		handle_movement_transitions()

func should_transition_to_air() -> bool:
	"""Check if should transition to airborne state"""
	# Only ground states should check for air transition
	var ground_states = ["idle", "walking", "running", "landing"]
	return state_name in ground_states and not character.is_on_floor()

func should_transition_to_ground() -> bool:
	"""Check if should transition from air to ground"""
	# Only air states should check for ground transition
	var air_states = ["jumping", "airborne"]
	return state_name in air_states and character.is_on_floor()

func can_do_movement_transitions() -> bool:
	"""Check if this state should handle movement-based transitions"""
	# Most states handle movement transitions except jumping/landing
	var no_movement_transition_states = ["jumping", "landing"]
	return not (state_name in no_movement_transition_states)

func handle_movement_transitions():
	"""Handle movement-based state transitions"""
	var current_speed = character.get_movement_speed()
	
	# Movement stopped - transition to idle
	if is_movement_active and current_speed < movement_stop_threshold:
		if can_transition_to_idle():
			change_to("idle")
			return
	
	# Movement started - transition from idle
	if state_name == "idle" and is_movement_active and current_movement_vector.length() > movement_start_threshold:
		var target_state = get_target_movement_state()
		change_to(target_state)
		return
	
	# Movement mode changed - transition between movement states
	if state_name in ["walking", "running"] and is_movement_active:
		var target_state = get_target_movement_state()
		if target_state != state_name:
			change_to(target_state)

func can_transition_to_idle() -> bool:
	"""Check if can transition to idle (override for special cases)"""
	return true

func get_target_movement_state() -> String:
	"""Determine target movement state based on current conditions"""
	if not is_movement_active:
		return "idle"
	
	# Check movement modes
	if character.is_running:
		return "running"
	else:
		return "walking"

# === ACTION SYSTEM INTERFACE ===

func can_execute_action(action: Action) -> bool:
	"""Override in child states to define what actions can be executed"""
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
	"""Override in child states to define how actions are executed"""
	match action.name:
		"move_start":
			handle_move_start_action(action)
		"move_update":
			handle_move_update_action(action)
		"move_end":
			handle_move_end_action(action)
		"sprint_start":
			character.is_running = true
			character.emit_movement_mode_changes()
		"sprint_end":
			character.is_running = false
			character.emit_movement_mode_changes()
		"slow_walk_start":
			character.is_slow_walking = true
			character.emit_movement_mode_changes()
		"slow_walk_end":
			character.is_slow_walking = false
			character.emit_movement_mode_changes()
		"reset":
			character.reset_character()
		_:
			push_warning("Unhandled action in ", state_name, ": ", action.name)

# === MOVEMENT ACTION HANDLERS ===

func handle_move_start_action(action: Action):
	"""Handle start of movement input"""
	current_movement_vector = action.get_movement_vector()
	movement_magnitude = action.context.get("magnitude", current_movement_vector.length())
	movement_start_time = Time.get_ticks_msec() / 1000.0
	is_movement_active = true
	
	character.movement_state_changed.emit(true, current_movement_vector, movement_magnitude)
	on_movement_started(current_movement_vector, movement_magnitude)

func handle_move_update_action(action: Action):
	"""Handle ongoing movement input"""
	current_movement_vector = action.get_movement_vector()
	movement_magnitude = action.context.get("magnitude", current_movement_vector.length())
	
	character.movement_state_changed.emit(true, current_movement_vector, movement_magnitude)
	on_movement_updated(current_movement_vector, movement_magnitude)

func handle_move_end_action(action: Action):
	"""Handle end of movement input"""
	current_movement_vector = Vector2.ZERO
	movement_magnitude = 0.0
	is_movement_active = false
	
	character.movement_state_changed.emit(false, Vector2.ZERO, 0.0)
	on_movement_ended()

# === VIRTUAL METHODS FOR CHILD STATES ===

func on_movement_started(direction: Vector2, magnitude: float):
	"""Override in child states for movement start behavior"""
	pass

func on_movement_updated(direction: Vector2, magnitude: float):
	"""Override in child states for ongoing movement behavior"""
	pass

func on_movement_ended():
	"""Override in child states for movement end behavior"""
	pass

# === CONDITION HELPERS ===

func can_handle_movement_action(action: Action) -> bool:
	"""Override in child states to restrict movement actions"""
	return true

func can_handle_mode_action(action: Action) -> bool:
	"""Override in child states to restrict mode changes"""
	return true

# === MOVEMENT HELPERS ===

func get_current_movement_input() -> Vector2:
	return current_movement_vector

func get_movement_magnitude() -> float:
	return movement_magnitude

func get_movement_duration() -> float:
	if is_movement_active:
		return (Time.get_ticks_msec() / 1000.0) - movement_start_time
	return 0.0

func is_input_sustained(min_duration: float = 0.3) -> bool:
	return get_movement_duration() >= min_duration

func should_process_movement() -> bool:
	return is_movement_active and (
		get_movement_duration() >= 0.08 or 
		character.get_movement_speed() > 0.5
	)

# === UTILITY METHODS ===

func transition_and_forward_action(new_state_name: String, action: Action):
	"""Transition to new state and forward the action to it"""
	change_to(new_state_name)
	
	if state_machine and state_machine.current_state:
		var new_state = state_machine.current_state
		if new_state != self and new_state.has_method("execute_action"):
			new_state.execute_action(action)

func has_action_system() -> bool:
	return action_system != null

func request_action(action_name: String, context: Dictionary = {}):
	if action_system:
		action_system.request_action(action_name, context)

func get_recent_actions(count: int = 5) -> Array:
	if action_system:
		return action_system.executed_actions.slice(-count)
	return []

func was_action_recently_executed(action_name: String, time_window: float = 1.0) -> bool:
	if not action_system:
		return false
	
	var current_time = Time.get_ticks_msec() / 1000.0
	for action in action_system.executed_actions:
		if action.name == action_name and (current_time - action.timestamp) <= time_window:
			return true
	return false
