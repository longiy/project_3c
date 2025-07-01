# StateRunning.gd - Simplified
class_name StateRunning
extends CharacterStateBase

func enter():
	super.enter()
	character.update_ground_state()

func update(delta: float):
	super.update(delta)
	
	character.apply_gravity(delta)
	apply_ground_movement(delta)
	character.move_and_slide()
