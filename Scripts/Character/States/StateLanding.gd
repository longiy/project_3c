# ===== StateLanding.gd - Debug Cleaned =====
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
	
	# Handle movement based on action state
	if is_movement_active and current_movement_vector.length() > 0:
		var movement_3d = character.calculate_movement_vector(current_movement_vector)
		var reduced_speed = character.get_target_speed() * 0.5
		var acceleration = character.get_target_acceleration()
		
		character.apply_movement(movement_3d, reduced_speed, acceleration, delta)
	else:
		character.apply_deceleration(delta)
	
	character.move_and_slide()
	check_transitions()

func check_transitions():
	if not character.is_on_floor():
		change_to("airborne")
	elif time_in_state > landing_recovery_time:
		if is_movement_active and current_movement_vector.length() > 0:
			if character.is_running:
				change_to("running")
			else:
				change_to("walking")
		else:
			change_to("idle")

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
