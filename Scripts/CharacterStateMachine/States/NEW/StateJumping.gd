# ===================================================================
# JUMPING STATE - Character just started a jump
# ===================================================================
class_name StateJumping
extends CharacterStateBase

var jump_grace_time = 0.05  # Brief window to apply jump force

func enter():
	super.enter()
	# Apply jump force immediately
	character.perform_jump(character.jump_height)

func update(delta: float):
	super.update(delta)
	
	character.apply_gravity(delta)
	handle_air_movement(delta)
	handle_common_input()
	
	character.move_and_slide()
	check_transitions()

func handle_air_movement(delta: float):
	"""Handle limited air control during jump"""
	if character.should_process_input():
		var input = character.get_smoothed_input()
		var movement_vector = character.calculate_movement_vector(input)
		var air_speed = character.get_target_speed() * character.air_speed_multiplier
		var air_acceleration = character.air_acceleration
		
		character.apply_movement(movement_vector, air_speed, air_acceleration, delta)

func check_transitions():
	"""Check for transitions from jumping"""
	# Brief grace period to stay in jumping state, then go airborne
	if time_in_state > jump_grace_time:
		change_to("airborne")
