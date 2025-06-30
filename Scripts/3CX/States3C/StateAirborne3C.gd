# StateAirborne3C.gd - Airborne state for 3C Character Manager
class_name StateAirborne3C
extends CharacterStateBase3C

func enter():
	super.enter()
	if character:
		character.emit_ground_state_changes()

func update(delta: float):
	super.update(delta)
	
	# Apply air physics through 3C character manager
	apply_air_movement(delta)

func get_debug_info() -> Dictionary:
	return {
		"state": "airborne",
		"time_in_state": time_in_state,
		"is_grounded": character.is_on_floor() if character else false,
		"velocity": character.velocity if character else Vector3.ZERO,
		"y_velocity": character.velocity.y if character else 0.0,
		"air_control": character.active_3c_config.air_control if character and character.active_3c_config else 0.0
	}
