# ActionSystem.gd - Event-driven action system
class_name ActionSystem
extends Node

signal action_requested(action: Action)
signal action_executed(action: Action)
signal action_failed(action: Action, reason: String)
signal action_ready(action: Action)  # NEW: Immediate processing signal

var pending_actions: Array[Action] = []
var executed_actions: Array[Action] = []
var character: CharacterBody3D

@export var enable_debug_logging = true
@export var max_history_size = 50
@export var use_event_driven_processing = true  # NEW: Toggle for testing

func _ready():
	character = get_parent() as CharacterBody3D
	if not character:
		push_error("ActionSystem must be child of CharacterBody3D")
		return
	
	# Connect to our own signal for immediate processing
	if use_event_driven_processing:
		action_ready.connect(_on_action_ready)
		print("🎯 ActionSystem: Using event-driven processing")
	else:
		print("🎯 ActionSystem: Using frame-based processing")

func _physics_process(delta):
	if not use_event_driven_processing:
		# Fallback to old frame-based processing
		process_pending_actions_frame_based(delta)
	
	# Always clean up expired actions
	clear_expired_actions()

func request_action(action_name: String, context: Dictionary = {}) -> Action:
	var action = Action.new(action_name, context)
	
	action_requested.emit(action)
	
	if use_event_driven_processing:
		# Immediate processing via signal
		action_ready.emit(action)
	else:
		# Add to queue for frame-based processing
		pending_actions.append(action)
	
	if enable_debug_logging:
		print("🎯 Action requested: ", action_name)
	
	return action

# === EVENT-DRIVEN PROCESSING ===

func _on_action_ready(action: Action):
	"""Handle action immediately when ready"""
	if action.is_expired():
		if enable_debug_logging:
			print("⏰ Action expired before processing: ", action.name)
		return
	
	# Immediate processing - no queuing
	if character.state_machine and character.state_machine.current_state:
		var current_state = character.state_machine.current_state
		
		if current_state.has_method("can_execute_action") and current_state.can_execute_action(action):
			if current_state.has_method("execute_action"):
				current_state.execute_action(action)
				execute_action_immediate(action, current_state.state_name)
			else:
				fail_action_immediate(action, "State has no execute_action method", current_state.state_name)
		else:
			# For movement actions, failing to execute immediately is normal
			if not action.is_movement_action():
				fail_action_immediate(action, "State cannot handle action", current_state.state_name)

func execute_action_immediate(action: Action, executor: String = "unknown"):
	"""Execute action immediately without queuing"""
	executed_actions.append(action)
	
	# Keep history manageable
	if executed_actions.size() > max_history_size:
		executed_actions.pop_front()
	
	action_executed.emit(action)
	
	if enable_debug_logging:
		print("✅ Action executed: ", action.name, " by ", executor)

func fail_action_immediate(action: Action, reason: String, executor: String = "unknown"):
	"""Fail action immediately"""
	action.failure_reason = reason
	
	action_failed.emit(action, reason)
	
	if enable_debug_logging:
		print("❌ Action failed: ", action.name, " - ", reason, " by ", executor)

# === FALLBACK FRAME-BASED PROCESSING ===

func process_pending_actions_frame_based(_delta):
	"""Fallback to old frame-based processing if needed"""
	# Process high-priority actions immediately (movement, look)
	for action in pending_actions.duplicate():
		if action.is_expired():
			pending_actions.erase(action)
			continue
		
		# Movement and look actions need immediate processing
		if action.is_movement_action() or action.is_look_action():
			process_action_immediately_legacy(action)
		else:
			# Other actions can wait for next frame if state can't handle them
			attempt_action_execution_legacy(action)

func process_action_immediately_legacy(action: Action):
	"""Legacy immediate processing for comparison"""
	if character.state_machine and character.state_machine.current_state:
		var current_state = character.state_machine.current_state
		
		if current_state.has_method("can_execute_action") and current_state.can_execute_action(action):
			if current_state.has_method("execute_action"):
				current_state.execute_action(action)
				execute_action(action, current_state.state_name)
			else:
				fail_action(action, "State has no execute_action method", current_state.state_name)
		else:
			# Movement actions that can't be handled should be dropped
			fail_action(action, "State cannot handle immediate action", current_state.state_name)

func attempt_action_execution_legacy(action: Action):
	"""Legacy action execution for comparison"""
	if character.state_machine and character.state_machine.current_state:
		var current_state = character.state_machine.current_state
		
		if current_state.has_method("can_execute_action") and current_state.can_execute_action(action):
			if current_state.has_method("execute_action"):
				current_state.execute_action(action)
				execute_action(action, current_state.state_name)
			else:
				fail_action(action, "State has no execute_action method", current_state.state_name)

# === LEGACY METHODS (for compatibility) ===

func execute_action(action: Action, executor: String = "unknown"):
	"""Legacy execute method"""
	pending_actions.erase(action)
	executed_actions.append(action)
	
	if executed_actions.size() > max_history_size:
		executed_actions.pop_front()
	
	action_executed.emit(action)
	
	if enable_debug_logging:
		print("✅ Action executed: ", action.name, " by ", executor)

func fail_action(action: Action, reason: String, executor: String = "unknown"):
	"""Legacy fail method"""
	action.failure_reason = reason
	pending_actions.erase(action)
	
	action_failed.emit(action, reason)
	
	if enable_debug_logging:
		print("❌ Action failed: ", action.name, " - ", reason, " by ", executor)

# === UTILITY METHODS ===

func clear_expired_actions():
	if not use_event_driven_processing:
		var original_count = pending_actions.size()
		pending_actions = pending_actions.filter(func(action): return not action.is_expired())
		
		if enable_debug_logging and pending_actions.size() != original_count:
			print("🕐 Cleared ", original_count - pending_actions.size(), " expired actions")
	
	# Always clean up executed actions history
	if executed_actions.size() > max_history_size * 2:
		executed_actions = executed_actions.slice(-max_history_size)

func cancel_all_actions():
	if not use_event_driven_processing:
		pending_actions.clear()
	
	if enable_debug_logging:
		print("🚫 All pending actions cancelled")

func set_event_driven_mode(enabled: bool):
	"""Toggle between event-driven and frame-based processing"""
	use_event_driven_processing = enabled
	
	if enabled:
		if not action_ready.is_connected(_on_action_ready):
			action_ready.connect(_on_action_ready)
		print("🎯 Switched to event-driven processing")
	else:
		if action_ready.is_connected(_on_action_ready):
			action_ready.disconnect(_on_action_ready)
		print("🎯 Switched to frame-based processing")

func get_debug_info() -> Dictionary:
	return {
		"event_driven": use_event_driven_processing,
		"pending_count": pending_actions.size() if not use_event_driven_processing else 0,
		"executed_count": executed_actions.size(),
		"recent_actions": executed_actions.slice(-5).map(func(a): return a.name),
		"pending_actions": pending_actions.map(func(a): return a.name + " (age: " + str(a.get_age()).pad_decimals(2) + "s)") if not use_event_driven_processing else []
	}
