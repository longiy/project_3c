# CharacterStatesBase.gd - Enhanced with animation integration
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
	
	# Notify animation system of state change
	request_animation_update()

func update(delta: float):
	super.update(delta)
	# States now react to actions instead of polling input

# === ANIMATION INTEGRATION ===

func request_animation_update():
	"""Request animation system to update based on current state"""
	if action_system:
		# Create animation context based on current state
		var anim_context = {
			"state_name": state_name,
			"movement_active": is_movement_active,
			"movement_vector": current_movement_vector,
			"movement_speed": character.get_movement_speed() if character else 0.0
		}
		
		action_system.request_action("animation_state_change", anim_context)

# === ACTION SYSTEM INTERFACE ===

func can_execute_action(action: Action) -> bool:
	"""Override in child states to define what actions can be executed"""
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
		# Animation actions - internal system
		"animation_state_change", "animation_speed_change":
			return false  # Handled by animation system
		# Reset always available
		"reset":
			return true
		_:
			return false

func execute_action(action: Action):
	"""Override in child states to define how actions are executed"""
	match action.name:
		# Movement actions
		"move_start":
			handle_move_start_action(action)
		"move_update":
			handle_move_update_action(action)
		"move_end":
			handle_move_end_action(action)
		
		# Mode actions
		"sprint_start":
			character.is_running = true
			request_animation_mode_change()
		"sprint_end":
			character.is_running = false
			request_animation_mode_change()
		"slow_walk_start":
			character.is_slow_walking = true
			request_animation_mode_change()
		"slow_walk_end":
			character.is_slow_walking = false
			request_animation_mode_change()
		
		# Look actions
		"look_delta":
			handle_look_action(action)
		
		# Utility actions
		"reset":
			character.reset_character()
		
		_:
			push_warning("Unhandled action in ", state_name, ": ", action.name)

# === MOVEMENT ACTION HANDLERS (Enhanced) ===

func handle_move_start_action(action: Action):
	"""Handle start of movement input"""
	current_movement_vector = action.get_movement_vector()
	movement_magnitude = action.context.get("magnitude", current_movement_vector.length())
	movement_start_time = Time.get_ticks_msec() / 1000.0
	is_movement_active = true
	
	# Request immediate animation update
	request_animation_movement_change()
	
	# Child states can override for specific behavior
	on_movement_started(current_movement_vector, movement_magnitude)

func handle_move_update_action(action: Action):
	"""Handle ongoing movement input"""
	current_movement_vector = action.get_movement_vector()
	movement_magnitude = action.context.get("magnitude", current_movement_vector.length())
	
	# Request animation update for direction changes
	request_animation_movement_change()
	
	# Child states can override for specific behavior
	on_movement_updated(current_movement_vector, movement_magnitude)

func handle_move_end_action(action: Action):
	"""Handle end of movement input"""
	current_movement_vector = Vector2.ZERO
	movement_magnitude = 0.0
	is_movement_active = false
	
	# Request immediate animation update
	request_animation_movement_change()
	
	# Child states can override for specific behavior
	on_movement_ended()

func handle_look_action(action: Action):
	"""Handle look input - delegate to camera system"""
	var look_delta = action.get_look_delta()
	# This will be handled by camera system

# === ANIMATION REQUEST HELPERS ===

func request_animation_movement_change():
	"""Request animation update for movement changes"""
	if action_system:
		var movement_context = {
			"movement_active": is_movement_active,
			"movement_vector": current_movement_vector,
			"movement_magnitude": movement_magnitude,
			"state_name": state_name
		}
		action_system.request_action("animation_movement_change", movement_context)

func request_animation_mode_change():
	"""Request animation update for mode changes (sprint/walk)"""
	if action_system:
		var mode_context = {
			"is_running": character.is_running if character else false,
			"is_slow_walking": character.is_slow_walking if character else false,
			"movement_speed": character.get_movement_speed() if character else 0.0,
			"state_name": state_name
		}
		action_system.request_action("animation_mode_change", mode_context)

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
		character.get_movement_speed() > 0.5
	)

# === UTILITY METHODS ===

func transition_and_forward_action(new_state_name: String, action: Action):
	"""Transition to new state and forward the action to it"""
	change_to(new_state_name)
	
	# Forward action to new state after transition
	if state_machine and state_machine.current_state:
		var new_state = state_machine.current_state
		if new_state != self and new_state.has_method("execute_action"):
			print("🔄 Forwarding action ", action.name, " to new state: ", new_state_name)
			new_state.execute_action(action)

func has_action_system() -> bool:
	return action_system != null

func request_action(action_name: String, context: Dictionary = {}):
	"""Helper to request actions from states"""
	if action_system:
		action_system.request_action(action_name, context)

func get_recent_actions(count: int = 5) -> Array:
	"""Get recent actions for combo detection, etc."""
	if action_system:
		return action_system.executed_actions.slice(-count)
	return []

func was_action_recently_executed(action_name: String, time_window: float = 1.0) -> bool:
	"""Check if action was executed recently"""
	if not action_system:
		return false
	
	var current_time = Time.get_ticks_msec() / 1000.0
	for action in action_system.executed_actions:
		if action.name == action_name and (current_time - action.timestamp) <= time_window:
			return true
	return false
