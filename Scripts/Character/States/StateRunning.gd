# StateRunning.gd - Fixed for 3C Framework  
class_name StateRunning
extends CharacterStateBase

func enter():
	super.enter()
	if character.has_method("update_ground_state"):
		character.update_ground_state()

func update(delta: float):
	super.update(delta)
	
	if character.has_method("apply_gravity"):
		character.apply_gravity(delta)
	
	apply_ground_movement(delta)
	character.move_and_slide()
