# StateMachine.gd - Complete state machine system
extends Node
class_name StateMachine

signal state_changed(old_state_name: String, new_state_name: String)
signal state_entered(state_name: String)
signal state_exited(state_name: String)

var current_state: State = null
var previous_state: State = null
var states: Dictionary = {}
var owner_node: Node

# Debug info
var state_history: Array[String] = []
var max_history_size = 10

func _ready():
	owner_node = get_parent()
	print("🎯 StateMachine initialized for: ", owner_node.name)

func add_state(state_name: String, state: State):
	"""Add a state to the machine"""
	if states.has(state_name):
		push_warning("State already exists: " + state_name)
		return
	
	states[state_name] = state
	state.state_machine = self
	state.owner = owner_node
	state.state_name = state_name
	
	print("✅ Added state: ", state_name)

func change_state(new_state_name: String):
	"""Change to a different state"""
	if not states.has(new_state_name):
		push_error("State not found: " + new_state_name)
		return
	
	if current_state and current_state.state_name == new_state_name:
		return  # Already in this state
	
	var old_state_name = current_state.state_name if current_state else "none"
	
	# Exit current state
	if current_state:
		current_state.exit()
		state_exited.emit(old_state_name)
		previous_state = current_state
	
	# Enter new state
	current_state = states[new_state_name]
	current_state.enter()
	
	# Update history
	state_history.append(new_state_name)
	if state_history.size() > max_history_size:
		state_history.pop_front()
	
	# Emit signals
	state_entered.emit(new_state_name)
	state_changed.emit(old_state_name, new_state_name)
	
	print("🔄 State: ", old_state_name, " → ", new_state_name)

func get_current_state_name() -> String:
	"""Get current state name"""
	return current_state.state_name if current_state else "none"

func get_previous_state_name() -> String:
	"""Get previous state name"""
	return previous_state.state_name if previous_state else "none"

func update(delta: float):
	"""Call from parent's _physics_process"""
	if current_state:
		current_state.update(delta)

func handle_input(event: InputEvent):
	"""Call from parent's _input"""
	if current_state:
		current_state.handle_input(event)

func has_state(state_name: String) -> bool:
	"""Check if state exists"""
	return states.has(state_name)

func get_state_history() -> Array[String]:
	"""Get recent state history for debugging"""
	return state_history.duplicate()
