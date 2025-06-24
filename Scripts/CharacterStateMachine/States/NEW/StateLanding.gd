# ===================================================================
# LANDING STATE - Brief recovery after landing
# ===================================================================
class_name StateLanding
extends CharacterStateBase

var landing_recovery_time = 0.1

func enter():
	super.enter()
	character.update_ground_state()
	
	# Brief landing recovery - slight speed reduction
	character.velocity.x *= 0.8
	character.velocity.z *= 0.8

func update(delta: float):
	super.update(delta)
	
	character.apply_gravity(delta)
	handle_landing_movement(delta)
	handle_jump_input()
	handle_common_input()
	
	character.move_and_slide()
	check_transitions()

func handle_landing_movement(delta: float):
	"""Handle limited movement during landing recovery"""
	if character.should_process_input():
		var input = character.get_smoothed_input()
		var movement_vector = character.calculate_movement_vector(input)
		var reduced_speed = character.get_target_speed() * 0.5  # Reduced during landing
		var acceleration = character.get_target_acceleration()
		
		character.apply_movement(movement_vector, reduced_speed, acceleration, delta)
	else:
		character.apply_deceleration(delta)

func handle_jump_input():
	"""Handle immediate jump after landing"""
	if character.try_consume_jump_buffer() and character.can_jump():
		change_to("jumping")

func check_transitions():
	"""Check for transitions from landing"""
	if not character.is_on_floor():
		change_to("airborne")
	elif time_in_state > landing_recovery_time:
		# Landing recovery complete - go to appropriate movement state
		if character.should_process_input() and character.get_smoothed_input().length() > 0:
			if character.is_running:
				change_to("running")
			else:
				change_to("walking")
		else:
			change_to("idle")

# ===================================================================
# FUTURE STATES (templates for expansion)
# ===================================================================

# class_name StateSliding
# extends CharacterStateBase
# # For sliding down slopes or slide attacks

# class_name StateDashing  
# extends CharacterStateBase
# # For quick dash movements

# class_name StateClimbing
# extends CharacterStateBase  
# # For ladder/wall climbing

# class_name StateSwimming
# extends CharacterStateBase
# # For water movement
