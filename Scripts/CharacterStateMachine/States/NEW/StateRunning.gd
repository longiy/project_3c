# StateRunning.gd - Character is running (fast speed)
extends CharacterStateBase
class_name StateRunning

func enter():
	super.enter()
	character.update_ground_state()

func update(delta: float):
	super.update(delta)
	
	character.apply_gravity(delta)
	handle_movement_input(delta)
	handle_jump_input()
	handle_common_input()
	
	character.move_and_slide()
	check_transitions()

func handle_movement_input(delta: float):
	"""Handle movement input while running"""
	if character.should_process_input():
		var input = character.get_smoothed_input()
		var movement_vector = character.calculate_movement_vector(input)
		var target_speed = character.get_target_speed()
		var acceleration = character.get_target_acceleration()
		
		character.apply_movement(movement_vector, target_speed, acceleration, delta)
	else:
		# No input - go to idle
		change_to("idle")

func handle_jump_input():
	"""Handle jump input while running"""
	if character.try_consume_jump_buffer() and character.can_jump():
		change_to("jumping")

func check_transitions():
	"""Check for state transitions"""
	if not character.is_on_floor():
		change_to("airborne")
	elif character.should_process_input():
		# Check if we should slow down
		if not character.is_running or character.get_target_speed() <= character.walk_speed:
			change_to("walking")
	else:
		# No input - stop moving
		if character.get_movement_speed() < 0.1:
			change_to("idle")
