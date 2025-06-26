# CharacterStatesBase.gd - Fixed version with safe signal emission
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
	if not action:
		return false
	
	# Safe action name check
	var action_name = ""
	if action.has_method("get") and "name" in action:
		action_name = action.name
	else:
		return false
	
	match action_name:
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
	if not action:
		push_error("CharacterStateBase: Cannot execute null action")
		return
	
	# Safe action name extraction
	var action_name = ""
	if action.has_method("get") and "name" in action:
		action_name = action.name
	else:
		push_error("CharacterStateBase: Action has no name property")
		return
	
	match action_name:
		# Movement actions
		"move_start":
			handle_move_start_action(action)
		"move_update":
			handle_move_update_action(action)
		"move_end":
			handle_move_end_action(action)
		
		# Mode actions - SAFE SIGNAL EMISSION
		"sprint_start":
			safe_set_character_running(true)
		"sprint_end":
			safe_set_character_running(false)
		"slow_walk_start":
			safe_set_character_slow_walking(true)
		"slow_walk_end":
			safe_set_character_slow_walking(false)
		
		# Look actions
		"look_delta":
			handle_look_action(action)
		
		# Utility actions
		"reset":
			if character and character.has_method("reset_character"):
				character.reset_character()
		
		_:
			push_warning("Unhandled action in ", state_name, ": ", action_name)

# === SAFE CHARACTER PROPERTY SETTERS ===

func safe_set_character_running(value: bool):
	"""Safely set character running state with signal emission"""
	if not character:
		return
	
	# Set property directly
	character.is_running = value
	
	# Emit signal safely
	safe_emit_movement_mode_changes()

func safe_set_character_slow_walking(value: bool):
	"""Safely set character slow walking state with signal emission"""
	if not character:
		return
	
	# Set property directly
	character.is_slow_walking = value
	
	# Emit signal safely
	safe_emit_movement_mode_changes()

func safe_emit_movement_mode_changes():
	"""Safely emit movement mode changes"""
	if not character:
		return
	
	# Method 1: Try dedicated method
	if character.has_method("emit_movement_mode_changes"):
		character.emit_movement_mode_changes()
		return
	
	# Method 2: Try direct signal emission
	if character.has_signal("movement_mode_changed"):
		character.movement_mode_changed.emit(character.is_running, character.is_slow_walking)
		return
	
	# Method 3: Try property setters
	if character.has_method("set_running"):
		character.set_running(character.is_running)
	elif character.has_method("set_slow_walking"):
		character.set_slow_walking(character.is_slow_walking)

# === MOVEMENT ACTION HANDLERS (SAFE VERSION) ===

func handle_move_start_action(action: Action):
	"""Handle start of movement input"""
	if not action:
		return
	
	current_movement_vector = safe_get_movement_vector(action)
	movement_magnitude = safe_get_context_value(action, "magnitude", current_movement_vector.length())
	movement_start_time = Time.get_ticks_msec() / 1000.0
	is_movement_active = true
	
	# SAFE SIGNAL: Character emits, animation receives
	safe_emit_movement_state_changed(true, current_movement_vector, movement_magnitude)
	
	# Child states can override for specific behavior
	on_movement_started(current_movement_vector, movement_magnitude)

func handle_move_update_action(action: Action):
	"""Handle ongoing movement input"""
	if not action:
		return
	
	current_movement_vector = safe_get_movement_vector(action)
	movement_magnitude = safe_get_context_value(action, "magnitude", current_movement_vector.length())
	
	# SAFE SIGNAL: Just emit the change
	safe_emit_movement_state_changed(true, current_movement_vector, movement_magnitude)
	
	# Child states can override for specific behavior
	on_movement_updated(current_movement_vector, movement_magnitude)

func handle_move_end_action(action: Action):
	"""Handle end of movement input"""
	current_movement_vector = Vector2.ZERO
	movement_magnitude = 0.0
	is_movement_active = false
	
	# SAFE SIGNAL: Character emits, animation receives
	safe_emit_movement_state_changed(false, Vector2.ZERO, 0.0)
	
	# Child states can override for specific behavior
	on_movement_ended()

func handle_look_action(action: Action):
	"""Handle look input - delegate to camera system"""
	# Camera system will handle this automatically through ActionSystem
	pass

# === SAFE SIGNAL EMISSION ===

func safe_emit_movement_state_changed(is_moving: bool, direction: Vector2, magnitude: float):
	"""Safely emit movement state changes"""
	if not character:
		return
	
	if character.has_signal("movement_state_changed"):
		character.movement_state_changed.emit(is_moving, direction, magnitude)

# === SAFE ACTION DATA EXTRACTION ===

func safe_get_movement_vector(action: Action) -> Vector2:
	"""Safely extract movement vector from action"""
	if not action:
		return Vector2.ZERO
	
	if action.has_method("get_movement_vector"):
		return action.get_movement_vector()
	
	# Fallback: try context directly
	return safe_get_context_value(action, "direction", Vector2.ZERO)

func safe_get_context_value(action: Action, key: String, default_value):
	"""Safely get value from action context"""
	if not action:
		return default_value
	
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
			print("🔄 Forwarding action ", safe_get_action_name(action), " to new state: ", new_state_name)
			new_state.execute_action(action)

func safe_get_action_name(action: Action) -> String:
	"""Safely get action name"""
	if not action:
		return "null"
	
	if action.has_method("get") and "name" in action:
		return action.name
	
	return "unknown"

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
