# ActionSystem.gd - Fixed version with better error handling
class_name ActionSystem
extends Node

# === SIGNALS ===
signal action_requested(action: Action)
signal action_executed(action: Action)
signal action_failed(action: Action, reason: String)

# === PROPERTIES ===
var executed_actions: Array = []  # Generic Array for stability
var character: CharacterBody3D

@export var enable_debug_logging = true
@export var max_history_size = 50

# Component validation
var components_validated = false

func _ready():
	character = get_parent() as CharacterBody3D
	if not character:
		push_error("ActionSystem must be child of CharacterBody3D")
		return
	
	# Validate setup when scene is ready
	call_deferred("validate_setup_deferred")
	
	print("🎯 ActionSystem: Initialized for ", character.name)

func validate_setup_deferred():
	"""Validate setup after scene is fully loaded"""
	components_validated = validate_dependencies()
	if not components_validated:
		push_warning("ActionSystem: Some dependencies missing - functionality may be limited")

func validate_dependencies() -> bool:
	"""Validate that required components exist"""
	var all_valid = true
	
	# Test Action class availability
	var test_action = Action.new("test", {})
	if not test_action:
		push_error("ActionSystem: Action class not available")
		all_valid = false
	
	# Check character state machine
	if not character.has_method("get_node") or not character.get_node_or_null("CharacterStateMachine"):
		push_warning("ActionSystem: No CharacterStateMachine found")
		all_valid = false
	
	return all_valid

# === CORE FUNCTION ===
func request_action(action_name: String, context: Dictionary = {}) -> Action:
	"""Main entry point - creates and processes action immediately"""
	
	# Input validation
	if action_name.is_empty():
		push_error("ActionSystem: Cannot create action with empty name")
		return null
	
	# Create action with error handling
	var action: Action = null
	action = Action.new(action_name, context)
	
	if not action:
		push_error("ActionSystem: Action creation returned null")
		return null
	
	# Emit requested signal
	action_requested.emit(action)
	
	# Process immediately
	process_action_immediately(action)
	
	return action

# === IMMEDIATE PROCESSING ===
func process_action_immediately(action: Action):
	"""Process action right away with robust error handling"""
	
	if not action:
		push_error("ActionSystem: Cannot process null action")
		return
	
	# Check if action expired
	if action.has_method("is_expired") and action.is_expired():
		fail_action(action, "Action expired before processing")
		return
	
	# Find current state safely
	var current_state = get_current_state()
	if not current_state:
		fail_action(action, "No current state available")
		return
	
	# Check if state can handle the action
	var can_execute = false
	if current_state.has_method("can_execute_action"):
		can_execute = current_state.can_execute_action(action)
	
	if not can_execute:
		# Only log failure for non-movement actions (movement failures are normal)
		if not (action.has_method("is_movement_action") and action.is_movement_action()):
			fail_action(action, "State '" + current_state.state_name + "' cannot handle action")
		return
	
	# Execute the action
	if current_state.has_method("execute_action"):
		current_state.execute_action(action)
		execute_action_success(action, current_state.state_name)
	else:
		fail_action(action, "State has no execute_action method")

func get_current_state() -> Node:
	"""Safely get current state from character"""
	if not character:
		return null
	
	var state_machine = character.get_node_or_null("CharacterStateMachine")
	if not state_machine:
		return null
	
	if state_machine.has_method("get") and "current_state" in state_machine:
		return state_machine.current_state
	
	return null

# === ACTION COMPLETION ===
func execute_action_success(action: Action, executor: String):
	"""Mark action as successfully executed"""
	if not action:
		push_error("ActionSystem: Cannot execute null action")
		return
	
	# Add to history
	executed_actions.append(action)
	
	# Keep history manageable
	if executed_actions.size() > max_history_size:
		executed_actions.pop_front()
	
	# Emit success signal
	action_executed.emit(action)
	
	if enable_debug_logging:
		print("✅ Action executed: ", action.name, " by ", executor)

func fail_action(action: Action, reason: String):
	"""Mark action as failed"""
	if not action:
		push_error("ActionSystem: Cannot fail null action")
		return
	
	# Set failure reason if action supports it
	if action.has_method("set") and "failure_reason" in action:
		action.failure_reason = reason
	
	# Emit failure signal
	action_failed.emit(action, reason)
	
	if enable_debug_logging and reason != "State 'idle' cannot handle action":
		print("❌ Action failed: ", action.name, " - ", reason)

# === UTILITY METHODS ===
func cancel_all_actions():
	"""Cancel all actions (for reset)"""
	executed_actions.clear()
	print("🎯 ActionSystem: All actions cancelled")

func get_recent_actions(count: int = 5) -> Array:
	"""Get recent executed actions"""
	if executed_actions.size() == 0:
		return []
	return executed_actions.slice(-count)

func was_action_recently_executed(action_name: String, time_window: float = 1.0) -> bool:
	"""Check if action was executed recently"""
	var current_time = Time.get_ticks_msec() / 1000.0
	for action in executed_actions:
		if action.has_method("get") and action.name == action_name:
			var timestamp = action.timestamp if "timestamp" in action else 0.0
			if (current_time - timestamp) <= time_window:
				return true
	return false

# === DEBUG INFO ===
func get_debug_info() -> Dictionary:
	var recent_names = []
	for action in get_recent_actions():
		if action.has_method("get") and "name" in action:
			recent_names.append(action.name)
	
	return {
		"total_executed": executed_actions.size(),
		"recent_actions": recent_names,
		"character_connected": character != null,
		"state_machine_connected": get_current_state() != null,
		"components_validated": components_validated,
		"architecture": "Signal-Driven (Actions for Logic, Signals for Animation)"
	}

# === VALIDATION ===
func validate_setup() -> bool:
	"""Validate ActionSystem setup"""
	if not character:
		push_error("ActionSystem: No character reference")
		return false
	
	var state_machine = character.get_node_or_null("CharacterStateMachine")
	if not state_machine:
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
