# ===================================================================
# StateJumping.gd - Action-based jumping state
# ===================================================================
class_name StateJumping
extends CharacterStateBase

var jump_grace_time = 0.05

func enter():
	super.enter()
	# Jump force is applied via action system now

func update(delta: float):
	super.update(delta)
	
	character.apply_gravity(delta)
	handle_air_movement(delta)
	handle_movement_mode_actions()
	
	character.move_and_slide()
	check_transitions()

func handle_air_movement(delta: float):
	if character.should_process_input():
		var input = character.get_smoothed_input()
		var movement_vector = character.calculate_movement_vector(input)
		var air_speed = character.get_target_speed() * character.air_speed_multiplier
		var air_acceleration = character.air_acceleration
		
		character.apply_movement(movement_vector, air_speed, air_acceleration, delta)

func check_transitions():
	if time_in_state > jump_grace_time:
		change_to("airborne")

func can_execute_action(action: Action) -> bool:
	match action.name:
		"jump": return character.can_air_jump()  # Air jump while jumping
		"sprint_start", "sprint_end", "slow_walk_start", "slow_walk_end": return true
		_: return super.can_execute_action(action)

func execute_action(action: Action):
	match action.name:
		"jump":
			character.perform_jump(character.jump_system.get_jump_force())
			# Stay in jumping state for air jumps
		"sprint_start": character.is_running = true
		"sprint_end": character.is_running = false
		"slow_walk_start": character.is_slow_walking = true
		"slow_walk_end": character.is_slow_walking = false
		_: super.execute_action(action)
