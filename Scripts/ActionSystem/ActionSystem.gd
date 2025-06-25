# ActionSystem.gd - Professional action/command system
class_name ActionSystem
extends Node

signal action_requested(action: Action)
signal action_executed(action: Action)
signal action_failed(action: Action, reason: String)

var pending_actions: Array[Action] = []
var executed_actions: Array[Action] = []
var character: CharacterBody3D

@export var enable_debug_logging = true
@export var max_history_size = 50

func _ready():
	character = get_parent() as CharacterBody3D
	if not character:
		push_error("ActionSystem must be child of CharacterBody3D")

func _physics_process(delta):
	process_pending_actions(delta)
	clear_expired_actions()

func request_action(action_name: String, context: Dictionary = {}) -> Action:
	var action = Action.new(action_name, context)
	pending_actions.append(action)
	
	action_requested.emit(action)
	
	if enable_debug_logging:
		print("🎯 Action requested: ", action_name)
	
	return action

func process_pending_actions(_delta):
	for action in pending_actions.duplicate():  # Duplicate to avoid modification during iteration
		if action.is_expired():
			continue
		
		# Let current state handle the action
		if character.state_machine and character.state_machine.current_state:
			var current_state = character.state_machine.current_state
			
			if current_state.has_method("can_execute_action") and current_state.can_execute_action(action):
				if current_state.has_method("execute_action"):
					current_state.execute_action(action)
					execute_action(action, current_state.state_name)
				else:
					fail_action(action, "State has no execute_action method", current_state.state_name)
			else:
				# Don't fail immediately - action might become valid next frame
				pass

func execute_action(action: Action, executor: String = "unknown"):
	pending_actions.erase(action)
	executed_actions.append(action)
	
	# Keep history manageable
	if executed_actions.size() > max_history_size:
		executed_actions.pop_front()
	
	action_executed.emit(action)
	
	if enable_debug_logging:
		print("✅ Action executed: ", action.name, " by ", executor)

func fail_action(action: Action, reason: String, executor: String = "unknown"):
	action.failure_reason = reason
	pending_actions.erase(action)
	
	action_failed.emit(action, reason)
	
	if enable_debug_logging:
		print("❌ Action failed: ", action.name, " - ", reason, " by ", executor)

func clear_expired_actions():
	var original_count = pending_actions.size()
	pending_actions = pending_actions.filter(func(action): return not action.is_expired())
	
	if enable_debug_logging and pending_actions.size() != original_count:
		print("🕐 Cleared ", original_count - pending_actions.size(), " expired actions")

func cancel_all_actions():
	pending_actions.clear()
	if enable_debug_logging:
		print("🚫 All pending actions cancelled")

func get_debug_info() -> Dictionary:
	return {
		"pending_count": pending_actions.size(),
		"executed_count": executed_actions.size(),
		"recent_actions": executed_actions.slice(-5).map(func(a): return a.name),
		"pending_actions": pending_actions.map(func(a): return a.name + " (age: " + str(a.get_age()).pad_decimals(2) + "s)")
	}

# Note: Action class is in separate Action.gd file
