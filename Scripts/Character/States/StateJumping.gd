# StateJumping.gd - UPDATED: Using MovementStateManager
class_name StateJumping
extends CharacterStateBase

var jump_grace_time = 0.05

func enter():
	super.enter()

func update(delta: float):
	super.update(delta)
	
	character.apply_gravity(delta)
	apply_air_movement(delta)  # Uses MovementStateManager
	character.move_and_slide()
	
	# Override base class transitions - jumping has specific timing
	if time_in_state > jump_grace_time:
		change_to("airborne")

# Override to prevent base class movement transitions during jump grace period
func can_do_movement_transitions() -> bool:
	return false

func can_execute_action(action: Action) -> bool:
	match action.name:
		"jump": 
			return character.can_air_jump()
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
		_:
			super.execute_action(action)  # Delegates to MovementStateManager
