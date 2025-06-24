# ===================================================================
# IDLE STATE - Character is standing still on ground
# ===================================================================
class_name StateIdle
extends CharacterStateBase

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
	"""Handle movement input while idle"""
	if character.should_process_input():
		var input = character.get_smoothed_input()  # This gets from ALL sources
		if input.length() > 0:
			var target_speed = character.get_target_speed()
			if target_speed <= character.slow_walk_speed:
				change_to("walking")
			elif character.is_running:
				change_to("running")
			else:
				change_to("walking")
	else:
		character.apply_deceleration(delta)

func handle_jump_input():
	"""Handle jump input while idle"""
	if character.try_consume_jump_buffer() and character.can_jump():
		change_to("jumping")

func check_transitions():
	"""Check for state transitions"""
	if not character.is_on_floor():
		change_to("airborne")
