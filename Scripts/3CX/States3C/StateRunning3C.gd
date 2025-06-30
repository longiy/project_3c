# StateRunning3C.gd - Running state for 3C Character Manager
class_name StateRunning3C
extends CharacterStateBase3C

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
		"state": "running",
		"time_in_state": time_in_state,
		"is_grounded": character.is_on_floor() if character else false,
		"velocity": character.velocity if character else Vector3.ZERO,
		"movement_direction": character.movement_direction if character else Vector2.ZERO,
		"movement_magnitude": character.movement_magnitude if character else 0.0,
		"is_sprinting": character.is_sprinting if character else false
	}
