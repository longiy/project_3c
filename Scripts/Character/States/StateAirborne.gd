# StateAirborne.gd - UPDATED: Using MovementStateManager
class_name StateAirborne
extends CharacterStateBase

func enter():
	super.enter()

func update(delta: float):
	super.update(delta)
	
	character.apply_gravity(delta)
	apply_air_movement(delta)  # Uses MovementStateManager
	character.move_and_slide()

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
			change_to("jumping")
		_:
			super.execute_action(action)  # Delegates to MovementStateManager
