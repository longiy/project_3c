# State.gd - Base class for all states with node support
extends Node
class_name State

var state_machine: CharacterStateMachine  # Changed from StateMachine to CharacterStateMachine
var owner_node: Node  # Renamed from 'owner' to avoid conflict with Node.owner
var state_name: String = ""
var state_node: Node = null  # Reference to the scene node (if exists)

# State timing
var time_in_state: float = 0.0
var time_since_entered: float = 0.0

func enter():
	"""Called when entering this state"""
	time_in_state = 0.0
	time_since_entered = 0.0
	# No logging here - state machine handles it

func exit():
	"""Called when leaving this state"""
	# No logging here - state machine handles it
	pass

func update(delta: float):
	"""Called every frame while in this state"""
	time_in_state += delta
	time_since_entered += delta

func handle_input(event: InputEvent):
	"""Called for input events while in this state"""
	pass

# Helper method to change states
func change_to(new_state: String):
	"""Change to another state"""
	if state_machine:
		state_machine.change_state(new_state)

# Helper to check how long we've been in this state
func get_time_in_state() -> float:
	return time_in_state

# Helper to check if we just entered (useful for one-time setup)
func just_entered(threshold: float = 0.1) -> bool:
	return time_since_entered < threshold

# === NODE ACCESS HELPERS ===

func has_state_node() -> bool:
	"""Check if this state has an associated scene node"""
	return state_node != null and is_instance_valid(state_node)

func get_state_node() -> Node:
	"""Get the associated scene node"""
	return state_node if has_state_node() else null

func get_node_property(property_name: String, default_value = null):
	"""Get a property from the state node (for inspector-configured values)"""
	if not has_state_node():
		return default_value
	
	if state_node.has_method("get") and property_name in state_node:
		return state_node.get(property_name)
	
	return default_value

func set_node_property(property_name: String, value):
	"""Set a property on the state node"""
	if has_state_node() and state_node.has_method("set"):
		state_node.set(property_name, value)

# === DEBUG HELPERS ===

func get_debug_info() -> Dictionary:
	"""Get debug information about this state"""
	return {
		"state_name": state_name,
		"time_in_state": time_in_state,
		"time_since_entered": time_since_entered,
		"has_node": has_state_node(),
		"node_name": state_node.name if has_state_node() else "None"
	}
