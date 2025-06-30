# StateAirborne.gd - Simplified
class_name StateAirborne
extends CharacterStateBase

func enter():
	super.enter()

func update(delta: float):
	super.update(delta)
	
	character.apply_gravity(delta)
	apply_air_movement(delta)
	character.move_and_slide()
