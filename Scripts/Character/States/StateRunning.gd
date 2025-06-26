# StateRunning.gd - Action-based running state
class_name StateRunning
extends CharacterStateBase

func enter():
	super.enter()
	character.update_ground_state()

func update(delta: float):
	super.update(delta)
	
	character.apply_gravity(delta)
	
	# Handle movement based on action state
	if is_movement_active and current_movement_vector.length() > 0:
		var movement_3d = character.calculate_movement_vector(current_movement_vector)
		var target_speed = character.get_target_speed()
		var acceleration = character.get_target_acceleration()
		
		character.apply_movement(movement_3d, target_speed, acceleration, delta)
	else:
		character.apply_deceleration(delta)
		if character.get_movement_speed() < 0.1:
			change_to("idle")
	
	character.move_and_slide()
	check_transitions()

func check_transitions():
	"""Check for state transitions"""
	if not character.is_on_floor():
		change_to("airborne")
	elif is_movement_active:
		# Check if we should downgrade to walking
		if not character.is_running or character.get_target_speed() <= character.walk_speed:
			change_to("walking")

# === MOVEMENT ACTION OVERRIDES ===

func on_movement_started(direction: Vector2, magnitude: float):
	"""Movement started while running"""
	pass

func on_movement_updated(direction: Vector2, magnitude: float):
	"""Movement updated while running"""
	# Check if we should transition to walking
	if not character.is_running or character.get_target_speed() <= character.walk_speed:
		change_to("walking")

func on_movement_ended():
	"""Movement ended while running"""
	pass

# === ACTION SYSTEM INTERFACE ===

func can_execute_action(action: Action) -> bool:
	match action.name:
		"jump": 
			return character.can_jump()
		"move_start", "move_update", "move_end":
			return true
		"sprint_start", "sprint_end", "slow_walk_start", "slow_walk_end": 
			return true
		"look_delta":
			return true
		_: 
			return super.can_execute_action(action)

func execute_action(action: Action):
	match action.name:
		"jump":
			character.perform_jump(character.jump_system.get_jump_force())
			change_to("jumping")
		
		"move_start", "move_update", "move_end":
			super.execute_action(action)
		
		_:
			super.execute_action(action)
