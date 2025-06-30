# StateLanding.gd - Refactored for modular architecture
extends CharacterStateBase
class_name StateLanding

@export var landing_duration = 0.2
var landing_timer = 0.0

func enter():
	super.enter()
	landing_timer = landing_duration
	
	# Ensure ground state is updated
	if physics_module:
		physics_module.update_ground_state()

func update(delta: float):
	super.update(delta)
	
	# Apply physics
	apply_gravity(delta)
	apply_ground_movement(delta)
	perform_move_and_slide()
	
	# Update landing timer
	landing_timer -= delta
	
	# Check for early transitions
	if check_for_jump_transition():
		return
	
	if not is_grounded():
		change_state("airborne")
		return
	
	# Complete landing after timer expires
	if landing_timer <= 0:
		# Transition based on movement
		if check_for_movement_transitions():
			return

func get_debug_info() -> Dictionary:
	var base_info = super.get_debug_info()
	base_info["state_type"] = "landing"
	base_info["landing_timer"] = landing_timer
	base_info["landing_duration"] = landing_duration
	return base_info
