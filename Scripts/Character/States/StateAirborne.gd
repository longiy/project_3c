# StateAirborne.gd - Refactored for modular architecture
extends CharacterStateBase
class_name StateAirborne

func enter():
	super.enter()

func update(delta: float):
	super.update(delta)
	
	# Apply physics
	apply_gravity(delta)
	apply_air_movement(delta)
	perform_move_and_slide()
	
	# Check for transitions
	if check_for_landing_transition():
		return
	
	# Handle air jump input
	if actions_module and actions_module.can_air_jump():
		if actions_module.jump_buffer_timer > 0:
			actions_module.perform_jump()
			change_state("jumping")
			return

func get_debug_info() -> Dictionary:
	var base_info = super.get_debug_info()
	base_info["state_type"] = "airborne"
	base_info["falling_velocity"] = get_velocity().y
	base_info["air_jumps_remaining"] = actions_module.air_jumps_remaining if actions_module else 0
	return base_info
