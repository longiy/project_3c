# CharacterStateBase.gd - Signal emission cleaned and simplified
class_name CharacterStateBase
extends State

var character: CharacterBody3D
var action_system: ActionSystem

# Movement state (managed through actions)
var current_movement_vector: Vector2 = Vector2.ZERO
var movement_magnitude: float = 0.0
var movement_start_time: float = 0.0
var is_movement_active: bool = false

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
	# States now react to actions instead of polling input

# === ACTION SYSTEM INTERFACE ===

func can_execute_action(action: Action) -> bool:
	"""Override in child states to define what actions can be executed"""
	if not action or not action.has_method("get") or not "name" in action:
		return false
	
	match action.name:
		# Movement actions - available in most states
		"move_start", "move_update", "move_end":
			return can_handle_movement_action(action)
		# Mode actions - usually available
		"sprint_start", "sprint_end", "slow_walk_start", "slow_walk_end":
			return can_handle_mode_action(action)
		# Look actions - usually available
		"look_delta":
			return can_handle_look_action(action)
		# Reset always available
		"reset":
			return true
		_:
			return false

func execute_action(action: Action):
	"""Override in child states to define how actions are executed"""
	if not action or not action.has_method("get") or not "name" in action:
		push_error("CharacterStateBase: Invalid action")
		return
	
	match action.name:
		# Movement actions
		"move_start":
			handle_move_start_action(action)
		"move_update":
			handle_move_update_action(action)
		"move_end":
			handle_move_end_action(action)
		
		# Mode actions - SIMPLIFIED
		"sprint_start":
			set_movement_mode(true, character.is_slow_walking)
		"sprint_end":
			set_movement_mode(false, character.is_slow_walking)
		"slow_walk_start":
			set_movement_mode(character.is_running, true)
		"slow_walk_end":
			set_movement_mode(character.is_running, false)
		
		# Look actions
		"look_delta":
			handle_look_action(action)
		
		# Utility actions
		"reset":
			if character and character.has_method("reset_character"):
				character.reset_character()
		
		_:
			push_warning("Unhandled action in ", state_name, ": ", action.name)

# === SIMPLIFIED SIGNAL EMISSION (2 methods instead of 6) ===

func set_movement_mode(running: bool, slow_walking: bool):
	"""UNIFIED method for setting movement modes with signal emission"""
	if not character:
		return
	
	# Set properties directly
	character.is_running = running
	character.is_slow_walking = slow_walking
	
	# Emit signal once
	if character.has_signal("movement_mode_changed"):
		character.movement_mode_changed.emit(running, slow_walking)

func emit_movement_state_change(is_moving: bool, direction: Vector2, magnitude: float):
	"""UNIFIED method for movement state changes"""
	if not character:
		return
	
	if character.has_signal("movement_state_changed"):
		character.movement_state_changed.emit(is_moving, direction, magnitude)

# === MOVEMENT ACTION HANDLERS (SIMPLIFIED) ===

func handle_move_start_action(action: Action):
	"""Handle start of movement input"""
	current_movement_vector = get_movement_vector_from_action(action)
	movement_magnitude = get_context_value(action, "magnitude", current_movement_vector.length())
	movement_start_time = Time.get_ticks_msec() / 1000.0
	is_movement_active = true
	
	# CLEAN SIGNAL EMISSION
	emit_movement_state_change(true, current_movement_vector, movement_magnitude)
	
	# Child states can override for specific behavior
	on_movement_started(current_movement_vector, movement_magnitude)

func handle_move_update_action(action: Action):
	"""Handle ongoing movement input"""
	current_movement_vector = get_movement_vector_from_action(action)
	movement_magnitude = get_context_value(action, "magnitude", current_movement_vector.length())
	
	# CLEAN SIGNAL EMISSION
	emit_movement_state_change(true, current_movement_vector, movement_magnitude)
	
	# Child states can override for specific behavior
	on_movement_updated(current_movement_vector, movement_magnitude)

func handle_move_end_action(action: Action):
	"""Handle end of movement input"""
	current_movement_vector = Vector2.ZERO
	movement_magnitude = 0.0
	is_movement_active = false
	
	# CLEAN SIGNAL EMISSION
	emit_movement_state_change(false, Vector2.ZERO, 0.0)
	
	# Child states can override for specific behavior
	on_movement_ended()

func handle_look_action(action: Action):
	"""Handle look input - delegate to camera system"""
	# Camera system will handle this automatically through ActionSystem
	pass

# === SIMPLIFIED DATA EXTRACTION ===

func get_movement_vector_from_action(action: Action) -> Vector2:
	"""Extract movement vector from action"""
	if action.has_method("get_movement_vector"):
		return action.get_movement_vector()
	return get_context_value(action, "direction", Vector2.ZERO)

func get_context_value(action: Action, key: String, default_value):
	"""Get value from action context"""
	if action.has_method("get") and "context" in action:
		var context = action.context
		if context and context.has(key):
			return context[key]
	return default_value

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

# === MOVEMENT CONDITION HELPERS ===

func can_handle_movement_action(action: Action) -> bool:
	"""Override in child states to restrict movement actions"""
	return true  # Most states can handle movement

func can_handle_mode_action(action: Action) -> bool:
	"""Override in child states to restrict mode changes"""
	return true  # Most states can handle mode changes

func can_handle_look_action(action: Action) -> bool:
	"""Override in child states to restrict look actions"""
	return true  # Most states can handle look

# === MOVEMENT HELPERS (using action-based state) ===

func get_current_movement_input() -> Vector2:
	"""Get current movement input from action state"""
	return current_movement_vector

func get_movement_magnitude() -> float:
	"""Get current movement magnitude"""
	return movement_magnitude

func get_movement_duration() -> float:
	"""Get how long movement has been active"""
	if is_movement_active:
		return (Time.get_ticks_msec() / 1000.0) - movement_start_time
	return 0.0

func is_input_sustained(min_duration: float = 0.3) -> bool:
	"""Check if movement input has been sustained"""
	return get_movement_duration() >= min_duration

func should_process_movement() -> bool:
	"""Check if state should process movement"""
	return is_movement_active and (
		get_movement_duration() >= 0.08 or 
		(character and character.get_movement_speed() > 0.5)
	)

# === UTILITY METHODS ===

func transition_and_forward_action(new_state_name: String, action: Action):
	"""Transition to new state and forward the action to it"""
	change_to(new_state_name)
	
	# Forward action to new state after transition
	if state_machine and state_machine.current_state:
		var new_state = state_machine.current_state
		if new_state != self and new_state.has_method("execute_action"):
			new_state.execute_action(action)

func has_action_system() -> bool:
	return action_system != null

func request_action(action_name: String, context: Dictionary = {}):
	"""Helper to request actions from states"""
	if action_system and action_system.has_method("request_action"):
		action_system.request_action(action_name, context)

func get_recent_actions(count: int = 5) -> Array:
	"""Get recent actions for combo detection, etc."""
	if action_system and action_system.has_method("get_recent_actions"):
		return action_system.get_recent_actions(count)
	return []

func was_action_recently_executed(action_name: String, time_window: float = 1.0) -> bool:
	"""Check if action was executed recently"""
	if not action_system or not action_system.has_method("was_action_recently_executed"):
		return false
	
	return action_system.was_action_recently_executed(action_name, time_window)
