# ActionSystem.gd - Enhanced with animation action support
class_name ActionSystem
extends Node

signal action_requested(action: Action)
signal action_executed(action: Action)
signal action_failed(action: Action, reason: String)
signal action_ready(action: Action) # Immediate processing signal

var executed_actions: Array[Action] = []
var character: CharacterBody3D

@export var enable_debug_logging = true
@export var max_history_size = 50

func _ready():
	character = get_parent() as CharacterBody3D
	if not character:
		push_error("ActionSystem must be child of CharacterBody3D")
		return
	
	# Connect to our own signal for immediate processing
	action_ready.connect(_on_action_ready)
	print("🎯 ActionSystem: Using event-driven processing with animation support")

func _physics_process(delta):
	# Only keep cleanup for executed actions history
	clear_expired_actions()

func request_action(action_name: String, context: Dictionary = {}) -> Action:
	var action = Action.new(action_name, context)
	
	action_requested.emit(action)
	action_ready.emit(action)  # Always immediate
	
	if enable_debug_logging and not action.name.begins_with("animation_"):
		print("🎯 Action requested: ", action_name)
	
	return action

# === EVENT-DRIVEN PROCESSING ===

func _on_action_ready(action: Action):
	"""Handle action immediately when ready"""
	if action.is_expired():
		if enable_debug_logging:
			print("⏰ Action expired before processing: ", action.name)
		return
	
	# Handle animation actions specially
	if action.name.begins_with("animation_"):
		handle_animation_action(action)
		return
	
	# Regular action processing
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

func handle_animation_action(action: Action):
	"""Handle animation-specific actions"""
	var animation_controller = character.get_node_or_null("AnimationController")
	if not animation_controller:
		fail_action_immediate(action, "No AnimationController found", "ActionSystem")
		return
	
	match action.name:
		"animation_state_change":
			handle_animation_state_change(action, animation_controller)
		"animation_movement_change":
			handle_animation_movement_change(action, animation_controller)
		"animation_mode_change":
			handle_animation_mode_change(action, animation_controller)
		_:
			fail_action_immediate(action, "Unknown animation action", "ActionSystem")

func handle_animation_state_change(action: Action, animation_controller):
	"""Handle state change animation updates"""
	if animation_controller.has_method("update_animation_immediately"):
		animation_controller.is_movement_active = action.context.get("movement_active", false)
		animation_controller.current_input_direction = action.context.get("movement_vector", Vector2.ZERO)
		animation_controller.current_movement_speed = action.context.get("movement_speed", 0.0)
		animation_controller.update_animation_immediately()
		execute_action_immediate(action, "AnimationController")
	else:
		fail_action_immediate(action, "AnimationController missing update method", "ActionSystem")

func handle_animation_movement_change(action: Action, animation_controller):
	"""Handle movement change animation updates"""
	if animation_controller.has_method("update_animation_immediately"):
		animation_controller.is_movement_active = action.context.get("movement_active", false)
		animation_controller.current_input_direction = action.context.get("movement_vector", Vector2.ZERO)
		animation_controller.current_movement_speed = character.get_movement_speed()
		animation_controller.update_animation_immediately()
		execute_action_immediate(action, "AnimationController")
	else:
		fail_action_immediate(action, "AnimationController missing update method", "ActionSystem")

func handle_animation_mode_change(action: Action, animation_controller):
	"""Handle mode change animation updates"""
	if animation_controller.has_method("update_animation_immediately"):
		animation_controller.current_movement_speed = action.context.get("movement_speed", 0.0)
		animation_controller.update_animation_immediately()
		execute_action_immediate(action, "AnimationController")
	else:
		fail_action_immediate(action, "AnimationController missing update method", "ActionSystem")

func execute_action_immediate(action: Action, executor: String = "unknown"):
	"""Execute action immediately without queuing"""
	executed_actions.append(action)
	
	# Keep history manageable
	if executed_actions.size() > max_history_size:
		executed_actions.pop_front()
	
	action_executed.emit(action)
	
	if enable_debug_logging and not action.name.begins_with("animation_"):
		print("✅ Action executed: ", action.name, " by ", executor)

func fail_action_immediate(action: Action, reason: String, executor: String = "unknown"):
	"""Fail action immediately"""
	action.failure_reason = reason
	
	action_failed.emit(action, reason)
	
	if enable_debug_logging:
		print("❌ Action failed: ", action.name, " - ", reason, " by ", executor)

# === UTILITY METHODS ===

func clear_expired_actions():
	# Keep only executed actions history cleanup
	if executed_actions.size() > max_history_size * 2:
		executed_actions = executed_actions.slice(-max_history_size)

func cancel_all_actions():
	"""Cancel all pending actions (for reset)"""
	# In event-driven system, no pending actions to cancel
	executed_actions.clear()
	print("🎯 ActionSystem: All actions cancelled")

func get_debug_info() -> Dictionary:
	return {
		"event_driven": true,
		"executed_count": executed_actions.size(),
		"recent_actions": executed_actions.slice(-5).map(func(a): return a.name),
		"animation_actions_supported": true
	}
