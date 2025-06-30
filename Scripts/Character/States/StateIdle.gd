# StateIdle.gd - Fixed for 3C Framework
class_name StateIdle
extends CharacterStateBase

func enter():
	super.enter()
	# Update ground state using new method
	if character.has_method("update_ground_state"):
		character.update_ground_state()

func update(delta: float):
	super.update(delta)
	
	# Apply gravity using new method
	if character.has_method("apply_gravity"):
		character.apply_gravity(delta)
	
	# Apply movement (idle = no movement, just stopping)
	apply_ground_movement(delta)
	
	# Move the character
	character.move_and_slide()
