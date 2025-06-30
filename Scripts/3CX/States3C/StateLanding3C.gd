# StateLanding3C.gd - Landing state for 3C Character Manager
class_name StateLanding3C
extends CharacterStateBase3C

@export var landing_duration: float = 0.2
@export var auto_transition_to_movement: bool = true

func enter():
	super.enter()
	if character:
		character.emit_ground_state_changes()

func update(delta: float):
	super.update(delta)
	
	# Apply ground physics through 3C character manager
	apply_ground_movement(delta)
	
	# Auto-transition after landing duration
	if auto_transition_to_movement and time_in_state > landing_duration:
		transition_to_appropriate_movement_state()

func transition_to_appropriate_movement_state():
	"""Transition to appropriate movement state based on input"""
	if not character:
		change_to("idle")
		return
	
	var target_state = character.should_transition_to_state("landing")
	if target_state != "":
		change_to(target_state)
	else:
		change_to("idle")

func get_debug_info() -> Dictionary:
	return {
		"state": "landing",
		"time_in_state": time_in_state,
		"is_grounded": character.is_on_floor() if character else false,
		"velocity": character.velocity if character else Vector3.ZERO,
		"landing_duration": landing_duration,
		"will_auto_transition": auto_transition_to_movement
	}
