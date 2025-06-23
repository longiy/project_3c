# GroundedState.gd - Fixed to use unified movement handling with minimal logging
extends BaseMovementState
class_name GroundedState

func enter():
	super.enter()
	
	# Reset grounded-specific values
	character.coyote_timer = character.coyote_time
	character.jumps_remaining = character.max_jumps

func update(delta: float):
	super.update(delta)
	
	# Handle all grounded logic
	apply_gravity(delta)
	handle_ground_movement(delta)  # This now includes proper input arbitration
	handle_jumping()
	handle_reset_input()
	
	# Apply physics
	character.move_and_slide()
	
	# Check for state transitions
	if check_for_airborne_transition():
		return  # Already transitioned to airborne

func handle_jumping():
	"""Handle jump input while grounded"""
	if Input.is_action_just_pressed("jump"):
		if character.coyote_timer > 0 and character.jumps_remaining > 0:
			# Perform jump
			character.velocity.y = character.jump_velocity
			character.jumps_remaining -= 1
			character.coyote_timer = 0
			
			# Transition to airborne will happen on next frame via check_for_airborne_transition()

func exit():
	super.exit()

# === GROUNDED-SPECIFIC HELPERS ===

func get_grounded_debug_info() -> Dictionary:
	"""Get grounded-specific debug info"""
	var base_info = get_debug_info()
	base_info.merge({
		"coyote_timer": character.coyote_timer,
		"jumps_remaining": character.jumps_remaining,
		"can_jump": character.coyote_timer > 0 and character.jumps_remaining > 0
	})
	return base_info
