# State.gd - Base class for all states
extends RefCounted
class_name State

var state_machine: StateMachine
var owner: Node
var state_name: String = ""

# State timing
var time_in_state: float = 0.0
var time_since_entered: float = 0.0

func enter():
	"""Called when entering this state"""
	time_in_state = 0.0
	time_since_entered = 0.0
	print("  ➤ Entering: ", state_name)

func exit():
	"""Called when leaving this state"""
	print("  ➤ Exiting: ", state_name, " (was active for ", "%.2f" % time_in_state, "s)")

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
