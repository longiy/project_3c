# ===================================================================
# StateAirborne.gd - Action-based airborne state
# ===================================================================
class_name StateAirborne
extends CharacterStateBase

func enter():
	super.enter()

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
	if character.is_on_floor():
		change_to("landing")

func can_execute_action(action: Action) -> bool:
	match action.name:
		"jump": return character.can_air_jump()
		"sprint_start", "sprint_end", "slow_walk_start", "slow_walk_end": return true
		_: return super.can_execute_action(action)

func execute_action(action: Action):
	match action.name:
		"jump":
			character.perform_jump(character.jump_system.get_jump_force())
			change_to("jumping")  # Brief jump state for air jumps
		"sprint_start": character.is_running = true
		"sprint_end": character.is_running = false
		"slow_walk_start": character.is_slow_walking = true
		"slow_walk_end": character.is_slow_walking = false
		_: super.execute_action(action)
