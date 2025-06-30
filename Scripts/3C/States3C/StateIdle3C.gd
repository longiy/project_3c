# StateIdle3C.gd - Idle state for 3C Character Manager
class_name StateIdle3C
extends CharacterStateBase3C

func get_state_name() -> String:
	return "idle"

func enter():
	super.enter()
	if character:
		character.emit_ground_state_changes()

func update(delta: float):
	super.update(delta)
	
	# Apply physics through 3C character manager
	apply_ground_movement(delta)

func get_debug_info() -> Dictionary:
	return {
		"state": "idle",
		"time_in_state": time_in_state,
		"is_grounded": character.is_on_floor() if character else false,
		"velocity": character.velocity if character else Vector3.ZERO
	}
