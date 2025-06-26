# StateWalking.gd - DIAGNOSTIC VERSION
class_name StateWalking
extends CharacterStateBase

func enter():
	super.enter()
	character.update_ground_state()
	print("🚶 WALKING: Entered walking state")

func update(delta: float):
	super.update(delta)
	
	character.apply_gravity(delta)
	
	print("🚶 WALKING: is_movement_active=", is_movement_active, " vector=", current_movement_vector)
	
	if is_movement_active and current_movement_vector.length() > 0:
		# Calculate 3D movement vector
		var movement_3d = character.calculate_movement_vector(current_movement_vector)
		var target_speed = character.get_target_speed()
		var acceleration = character.get_target_acceleration()
		
		print("🚶 WALKING: movement_3d=", movement_3d, " target_speed=", target_speed)
		
		character.apply_movement(movement_3d, target_speed, acceleration, delta)
	else:
		character.apply_deceleration(delta)
	
	character.move_and_slide()
	
	print("🚶 WALKING: final velocity=", character.velocity)

# Override to prevent base class transitions for now
func handle_common_transitions():
	# DISABLED for diagnostic
	pass

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
	print("🚶 WALKING: Executing action: ", action.name)
	
	match action.name:
		"jump":
			character.perform_jump(character.jump_system.get_jump_force())
			change_to("jumping")
		"move_start", "move_update", "move_end":
			super.execute_action(action)
		_:
			super.execute_action(action)
