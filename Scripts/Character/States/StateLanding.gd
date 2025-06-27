# StateLanding.gd - Simplified
class_name StateLanding
extends CharacterStateBase

var landing_recovery_time = 0.1

func enter():
	super.enter()
	character.update_ground_state()
	
	# Reduce velocity on landing
	character.velocity.x *= 0.8
	character.velocity.z *= 0.8

func update(delta: float):
	super.update(delta)
	
	character.apply_gravity(delta)
	apply_ground_movement(delta)
	character.move_and_slide()
	
	# Override base class transitions - landing has recovery time
	if time_in_state > landing_recovery_time:
		handle_movement_transitions()

# Override to prevent immediate transitions during recovery
func can_do_movement_transitions() -> bool:
	return time_in_state > landing_recovery_time
