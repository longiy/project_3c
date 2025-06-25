# ===================================================================
# AIRBORNE STATE - Character is falling or in air
# ===================================================================
class_name StateAirborne
extends CharacterStateBase

func enter():
	super.enter()

func update(delta: float):
	super.update(delta)
	
	character.apply_gravity(delta)
	handle_air_movement(delta)
	handle_air_jump_input()
	handle_common_input()
	
	character.move_and_slide()
	check_transitions()

func handle_air_movement(delta: float):
	"""Handle air control while airborne"""
	if character.should_process_input():
		var input = character.get_smoothed_input()
		var movement_vector = character.calculate_movement_vector(input)
		var air_speed = character.get_target_speed() * character.air_speed_multiplier
		var air_acceleration = character.air_acceleration
		
		character.apply_movement(movement_vector, air_speed, air_acceleration, delta)

func handle_air_jump_input():
	"""Handle air jumping while airborne"""
	if character.try_consume_jump_buffer() and character.can_air_jump():
		character.perform_jump(character.jump_system.get_jump_force())  # Use normal jump force, not air_jump_force

func check_transitions():
	"""Check for landing"""
	if character.is_on_floor():
		change_to("landing")
