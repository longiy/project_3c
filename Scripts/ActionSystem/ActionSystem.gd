# ActionSystem.gd - How it SHOULD look for your clean signal-driven architecture
class_name ActionSystem
extends Node

# === SIGNALS ===
signal action_requested(action: Action)
signal action_executed(action: Action)
signal action_failed(action: Action, reason: String)

# === PROPERTIES ===
var executed_actions: Array[Action] = []
var character: CharacterBody3D

@export var enable_debug_logging = true
@export var max_history_size = 50

func _ready():
	character = get_parent() as CharacterBody3D
	if not character:
		push_error("ActionSystem must be child of CharacterBody3D")
		return
	
	print("🎯 ActionSystem: Initialized for ", character.name)

# === CORE FUNCTION ===
func request_action(action_name: String, context: Dictionary = {}) -> Action:
	"""Main entry point - creates and processes action immediately"""
	
	# Validate inputs
	if action_name.is_empty():
		push_error("ActionSystem: Cannot create action with empty name")
		return null
	
	# Create action safely
	var action = Action.new(action_name, context)
	if not action:
		push_error("ActionSystem: Failed to create action")
		return null
	
	# Emit requested signal
	action_requested.emit(action)
	
	# Process immediately (no queuing in your design)
	process_action_immediately(action)
	
	if enable_debug_logging:
		print("🎯 Action requested: ", action_name)
	
	return action

# === IMMEDIATE PROCESSING ===
func process_action_immediately(action: Action):
	"""Process action right away (event-driven)"""
	
	if not action:
		push_error("ActionSystem: Cannot process null action")
		return
	
	if action.is_expired():
		fail_action(action, "Action expired before processing")
		return
	
	# Find current state and see if it can handle the action
	if character and character.state_machine and character.state_machine.current_state:
		var current_state = character.state_machine.current_state
		
		# Check if state can handle this action
		if current_state.has_method("can_execute_action") and current_state.can_execute_action(action):
			# Execute the action
			if current_state.has_method("execute_action"):
				current_state.execute_action(action)
				execute_action_success(action, current_state.state_name)
			else:
				fail_action(action, "State has no execute_action method")
		else:
			# Only log failure for non-movement actions (movement failures are normal)
			if not action.is_movement_action():
				fail_action(action, "State cannot handle action: " + str(current_state.state_name))
	else:
		fail_action(action, "No state machine or current state")

# === ACTION COMPLETION ===
func execute_action_success(action: Action, executor: String):
	"""Mark action as successfully executed"""
	if not action:
		push_error("ActionSystem: Cannot execute null action")
		return
		
	executed_actions.append(action)
	
	# Keep history manageable - safe null check
	if executed_actions.size() > max_history_size:
		executed_actions.pop_front()
	
	action_executed.emit(action)
	
	if enable_debug_logging:
		print("✅ Action executed: ", action.name, " by ", executor)

func fail_action(action: Action, reason: String):
	"""Mark action as failed"""
	if not action:
		push_error("ActionSystem: Cannot fail null action")
		return
		
	action.failure_reason = reason
	action_failed.emit(action, reason)
	
	if enable_debug_logging:
		print("❌ Action failed: ", action.name, " - ", reason)

# === UTILITY METHODS ===
func cancel_all_actions():
	"""Cancel all actions (for reset)"""
	executed_actions.clear()
	print("🎯 ActionSystem: All actions cancelled")

func get_recent_actions(count: int = 5) -> Array[Action]:
	"""Get recent executed actions"""
	return executed_actions.slice(-count)

func was_action_recently_executed(action_name: String, time_window: float = 1.0) -> bool:
	"""Check if action was executed recently"""
	var current_time = Time.get_ticks_msec() / 1000.0
	for action in executed_actions:
		if action.name == action_name and (current_time - action.timestamp) <= time_window:
			return true
	return false

# === DEBUG INFO ===
func get_debug_info() -> Dictionary:
	return {
		"total_executed": executed_actions.size(),
		"recent_actions": get_recent_actions().map(func(a): return a.name),
		"character_connected": character != null,
		"state_machine_connected": character.state_machine != null if character else false,
		"architecture": "Signal-Driven (Actions for Logic, Signals for Animation)"
	}

# === VALIDATION ===
func validate_setup() -> bool:
	"""Validate ActionSystem setup"""
	if not character:
		push_error("ActionSystem: No character reference")
		return false
	
	if not character.state_machine:
		push_error("ActionSystem: Character missing state machine")
		return false
	
	# Test if Action class is available
	var test_action = Action.new("test", {})
	if not test_action:
		push_error("ActionSystem: Action class not available")
		return false
	
	print("✅ ActionSystem: Setup validation passed")
	return true

func _get_configuration_warnings() -> PackedStringArray:
	"""Provide editor warnings"""
	var warnings = PackedStringArray()
	
	if not get_parent() is CharacterBody3D:
		warnings.append("ActionSystem should be child of CharacterBody3D")
	
	return warnings
