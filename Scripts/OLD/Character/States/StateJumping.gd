# StateJumping.gd - Simplified
class_name StateJumping
extends CharacterStateBase

var jump_grace_time = 0.05

func enter():
	super.enter()

func update(delta: float):
	super.update(delta)
	
	character.apply_gravity(delta)
	apply_air_movement(delta)
	character.move_and_slide()
	
	# Override base class transitions - jumping has specific timing
	if time_in_state > jump_grace_time:
		change_to("airborne")

# Override to prevent base class movement transitions during jump grace period
func can_do_movement_transitions() -> bool:
	return false
