
# ===================================================================
# StateWalking.gd - Action-based walking state
# ===================================================================
class_name StateWalking
extends CharacterStateBase

func enter():
	super.enter()
	character.update_ground_state()

func update(delta: float):
	super.update(delta)
	
	character.apply_gravity(delta)
	handle_movement_input(delta)
	handle_movement_mode_actions()
	
	character.move_and_slide()
	check_transitions()

func handle_movement_input(delta: float):
	if character.should_process_input():
		var input = character.get_smoothed_input()
		var movement_vector = character.calculate_movement_vector(input)
		var target_speed = character.get_target_speed()
		var acceleration = character.get_target_acceleration()
		
		character.apply_movement(movement_vector, target_speed, acceleration, delta)
	else:
		change_to("idle")

func check_transitions():
	if not character.is_on_floor():
		change_to("airborne")
	elif character.should_process_input():
		if character.is_running and character.get_target_speed() > character.walk_speed:
			change_to("running")
	else:
		if character.get_movement_speed() < 0.1:
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
