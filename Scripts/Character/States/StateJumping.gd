# StateJumping.gd - Refactored for modular architecture
extends CharacterStateBase
class_name StateJumping

@export var jump_transition_threshold = 0.1

func enter():
	super.enter()
	# Jump is performed by actions module before state transition

func update(delta: float):
	super.update(delta)
	
	# Apply physics
	apply_gravity(delta)
	apply_air_movement(delta)
	perform_move_and_slide()
	
	# Check for transitions
	var velocity = get_velocity()
	
	# Transition to airborne when upward velocity slows
	if velocity.y <= jump_transition_threshold:
		change_state("airborne")
		return
	
	# Handle air jump input
	if actions_module and actions_module.can_air_jump():
		if actions_module.jump_buffer_timer > 0:
			actions_module.perform_jump()
			# Stay in jumping state for air jumps

func get_debug_info() -> Dictionary:
	var base_info = super.get_debug_info()
	base_info["state_type"] = "jumping"
	base_info["upward_velocity"] = get_velocity().y
	base_info["jump_threshold"] = jump_transition_threshold
	return base_info
