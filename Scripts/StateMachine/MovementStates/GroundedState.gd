# GroundedState.gd - Handles all grounded movement
extends BaseMovementState
class_name GroundedState

func enter():
	super.enter()
	
	# Reset grounded-specific values
	character.coyote_timer = character.coyote_time
	character.jumps_remaining = character.max_jumps
	
	print("  🏃 Grounded: Coyote time reset, jumps restored")

func update(delta: float):
	super.update(delta)
	
	# Handle all grounded logic
	apply_gravity(delta)
	handle_ground_movement(delta)
	handle_jumping()
	handle_reset_input()
	
	# Apply physics
	character.move_and_slide()
	
	# Check for state transitions
	if check_for_airborne_transition():
		return  # Already transitioned to airborne

func handle_ground_movement(delta: float):
	"""Handle movement while grounded"""
	
	# Get input with proper filtering
	var raw_input = get_current_input()
	var input_dir = apply_input_smoothing(raw_input, delta)
	
	# Check if we should move (respects minimum input duration)
	if should_process_movement():
		# Calculate movement
		var movement_vector = calculate_movement_vector(input_dir)
		var speed_data = get_target_speed_and_acceleration()
		
		# Apply movement with acceleration
		apply_movement_with_acceleration(
			movement_vector,
			speed_data.speed,
			speed_data.acceleration,
			delta
		)
		
		# Cancel input components if WASD is active
		if raw_input.length() > character.input_deadzone:
			cancel_all_input_components()
	else:
		# Apply deceleration when no valid input
		apply_deceleration(delta)

func handle_jumping():
	"""Handle jump input while grounded"""
	if Input.is_action_just_pressed("jump"):
		if character.coyote_timer > 0 and character.jumps_remaining > 0:
			# Perform jump
			character.velocity.y = character.jump_velocity
			character.jumps_remaining -= 1
			character.coyote_timer = 0
			
			print("  🚀 Ground jump performed")
			
			# Transition to airborne will happen on next frame via check_for_airborne_transition()

func exit():
	super.exit()
	print("  🏃 Left grounded state")

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
