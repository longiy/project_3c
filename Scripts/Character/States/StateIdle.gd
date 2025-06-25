# StateIdle.gd - Action-based idle state
class_name StateIdle
extends CharacterStateBase

func enter():
	super.enter()
	character.update_ground_state()

func update(delta: float):
	super.update(delta)
	
	character.apply_gravity(delta)
	handle_movement_input(delta)
	handle_movement_mode_actions()  # Process sprint/walk mode changes
	
	character.move_and_slide()
	check_transitions()

func handle_movement_input(delta: float):
	"""Handle movement input while idle"""
	if character.should_process_input():
		var input = character.get_smoothed_input()
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

func check_transitions():
	"""Check for state transitions"""
	if not character.is_on_floor():
		change_to("airborne")

# === ACTION SYSTEM INTERFACE ===

func can_execute_action(action: Action) -> bool:
	"""Define what actions can be executed while idle"""
	match action.name:
		"jump":
			return character.can_jump()
		"sprint_start", "sprint_end", "slow_walk_start", "slow_walk_end":
			return true  # Movement modes always available
		"reset":
			return true
		_:
			return super.can_execute_action(action)

func execute_action(action: Action):
	"""Execute actions while idle"""
	match action.name:
		"jump":
			character.perform_jump(character.jump_system.get_jump_force())
			change_to("jumping")
		"sprint_start":
			character.is_running = true
		"sprint_end":
			character.is_running = false
		"slow_walk_start":
			character.is_slow_walking = true
		"slow_walk_end":
			character.is_slow_walking = false
		_:
			super.execute_action(action)
