# ===================================================================
# StateLanding.gd - Action-based landing state
# ===================================================================
class_name StateLanding
extends CharacterStateBase

var landing_recovery_time = 0.1

func enter():
	super.enter()
	character.update_ground_state()
	
	character.velocity.x *= 0.8
	character.velocity.z *= 0.8

func update(delta: float):
	super.update(delta)
	
	character.apply_gravity(delta)
	handle_landing_movement(delta)
	handle_movement_mode_actions()
	
	character.move_and_slide()
	check_transitions()

func handle_landing_movement(delta: float):
	if character.should_process_input():
		var input = character.get_smoothed_input()
		var movement_vector = character.calculate_movement_vector(input)
		var reduced_speed = character.get_target_speed() * 0.5
		var acceleration = character.get_target_acceleration()
		
		character.apply_movement(movement_vector, reduced_speed, acceleration, delta)
	else:
		character.apply_deceleration(delta)

func check_transitions():
	if not character.is_on_floor():
		change_to("airborne")
	elif time_in_state > landing_recovery_time:
		if character.should_process_input() and character.get_smoothed_input().length() > 0:
			if character.is_running:
				change_to("running")
			else:
				change_to("walking")
		else:
			change_to("idle")

func can_execute_action(action: Action) -> bool:
	match action.name:
		"jump": return character.can_jump()
		"sprint_start", "sprint_end", "slow_walk_start", "slow_walk_end": return true
		_: return super.can_execute_action(action)

func execute_action(action: Action):
	match action.name:
		"jump":
			character.perform_jump(character.jump_system.get_jump_force())
			change_to("jumping")
		"sprint_start": character.is_running = true
		"sprint_end": character.is_running = false
		"slow_walk_start": character.is_slow_walking = true
		"slow_walk_end": character.is_slow_walking = false
		_: super.execute_action(action)
