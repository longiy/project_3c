# StateJumping3C.gd - Jumping state for 3C Character Manager
class_name StateJumping3C
extends CharacterStateBase3C

@export var jump_transition_time: float = 0.1

func get_state_name() -> String:
	return "jumping"

func enter():
	super.enter()
	if character:
		character.emit_ground_state_changes()

func update(delta: float):
	super.update(delta)
	
	# Apply air physics through 3C character manager
	apply_air_movement(delta)
	
	# Auto-transition to airborne after brief jump start
	if time_in_state > jump_transition_time:
		change_to("airborne")

func get_debug_info() -> Dictionary:
	return {
		"state": "jumping",
		"time_in_state": time_in_state,
		"is_grounded": character.is_on_floor() if character else false,
		"velocity": character.velocity if character else Vector3.ZERO,
		"y_velocity": character.velocity.y if character else 0.0,
		"will_transition_at": jump_transition_time
	}
