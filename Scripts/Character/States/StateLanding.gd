# StateLanding.gd - UPDATED: Using MovementStateManager
class_name StateLanding
extends CharacterStateBase

var landing_recovery_time = 0.1

func enter():
	super.enter()
	character.update_ground_state()
	
	# Reduce velocity on landing
	character.velocity.x *= 0.8
	character.velocity.z *= 0.8

func update(delta: float):
	super.update(delta)
	
	character.apply_gravity(delta)
	apply_ground_movement(delta)  # Uses MovementStateManager
	character.move_and_slide()
	
	# Override base class transitions - landing has recovery time
	if time_in_state > landing_recovery_time:
		handle_movement_transitions()

# Override to prevent immediate transitions during recovery
func can_do_movement_transitions() -> bool:
	return time_in_state > landing_recovery_time

func can_execute_action(action: Action) -> bool:
	match action.name:
		"jump": 
			return character.can_jump()
		"move_start", "move_update", "move_end":
			return true
		"sprint_start", "sprint_end", "slow_walk_start", "slow_walk_end": 
			return true
		_: 
			return super.can_execute_action(action)

func execute_action(action: Action):
	match action.name:
		"jump":
			character.perform_jump(character.jump_system.get_jump_force())
			change_to("jumping")
		_:
			super.execute_action(action)  # Delegates to MovementStateManager
