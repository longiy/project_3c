# CharacterStatesBase.gd - Action-based state system
class_name CharacterStateBase
extends State

var character: CharacterBody3D
var action_system: ActionSystem

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

func update(_delta: float):
	super.update(_delta)
	# Base states no longer handle input directly

func handle_common_input():
	"""Handle input that works in all states (kept for compatibility)"""
	# This can now be removed since actions handle reset, etc.
	pass

# === ACTION SYSTEM INTERFACE ===

func can_execute_action(action: Action) -> bool:
	"""Override in child states to define what actions can be executed"""
	match action.name:
		"reset":
			return true  # All states can reset
		_:
			return false

func execute_action(action: Action):
	"""Override in child states to define how actions are executed"""
	match action.name:
		"reset":
			character.reset_character()
		_:
			push_warning("Unhandled action in ", state_name, ": ", action.name)

# === MOVEMENT MODE HELPERS ===

func handle_movement_mode_actions():
	"""Process movement mode changes from action system"""
	if not action_system:
		return
	
	# Check recent actions for movement mode changes
	for action in action_system.executed_actions.slice(-3):  # Check last 3 actions
		match action.name:
			"sprint_start":
				character.is_running = true
			"sprint_end":
				character.is_running = false
			"slow_walk_start":
				character.is_slow_walking = true
			"slow_walk_end":
				character.is_slow_walking = false

# === UTILITY METHODS ===

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
