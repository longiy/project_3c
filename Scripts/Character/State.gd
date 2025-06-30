# State.gd - Refactored base class for all states
extends Node
class_name State

# === REFERENCES ===
var state_machine  # Untyped to work with both old and new systems
var owner_node: Node
var state_name: String = ""
var state_node: Node = null

# === STATE TIMING ===
var time_in_state: float = 0.0
var time_since_entered: float = 0.0

# === STATE LIFECYCLE ===

func enter():
	"""Called when entering this state"""
	time_in_state = 0.0
	time_since_entered = 0.0

func exit():
	"""Called when leaving this state"""
	pass

func update(delta: float):
	"""Called every frame while in this state"""
	time_in_state += delta
	time_since_entered += delta

func handle_input(_event: InputEvent):
	"""Called for input events while in this state"""
	pass

# === STATE CONTROL ===

func change_to(new_state: String):
	"""Change to another state"""
	if state_machine and state_machine.has_method("change_state"):
		state_machine.change_state(new_state)

# === TIMING HELPERS ===

func get_time_in_state() -> float:
	"""Get time spent in current state"""
	return time_in_state

func just_entered(threshold: float = 0.1) -> bool:
	"""Check if we just entered this state"""
	return time_since_entered < threshold

# === NODE ACCESS HELPERS ===

func has_state_node() -> bool:
	"""Check if this state has an associated scene node"""
	return state_node != null and is_instance_valid(state_node)

func get_state_node() -> Node:
	"""Get the associated scene node"""
	return state_node if has_state_node() else null

func get_node_property(property_name: String, default_value = null):
	"""Get a property from the state node"""
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
		"node_name": state_node.name if has_state_node() else "None",
		"state_machine_type": str(state_machine.get_script().get_global_name()) if state_machine else "None"
	}
