# StateWalking.gd - CLEANED: Uses base class transitions, no debug prints
class_name StateWalking
extends CharacterStateBase

func enter():
	super.enter()
	character.update_ground_state()

func update(delta: float):
	super.update(delta)
	
	character.apply_gravity(delta)
	
	if is_movement_active and current_movement_vector.length() > 0:
		var movement_3d = character.calculate_movement_vector(current_movement_vector)
		var target_speed = character.get_target_speed()
		var acceleration = character.get_target_acceleration()
		
		character.apply_movement(movement_3d, target_speed, acceleration, delta)
	else:
		character.apply_deceleration(delta)
	
	character.move_and_slide()

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
