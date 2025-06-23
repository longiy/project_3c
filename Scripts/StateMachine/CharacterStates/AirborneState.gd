# AirborneState.gd - Handles jumping, falling, and air control
extends BaseMovementState
class_name AirborneState

func enter():
	super.enter()
	print("  🚀 Airborne: Started falling/jumping")

func update(delta: float):
	super.update(delta)
	
	# Handle all airborne logic
	apply_gravity(delta)
	update_coyote_timer(delta)
	handle_air_control(delta)
	handle_air_jumping()
	handle_reset_input()
	
	# Apply physics
	character.move_and_slide()
	
	# Check for landing
	if check_for_grounded_transition():
		return  # Already transitioned to grounded

func update_coyote_timer(delta: float):
	"""Update coyote time while airborne"""
	character.coyote_timer -= delta

func handle_air_control(delta: float):
	"""Handle limited movement control while airborne"""
	
	# Get input (air control is usually reduced)
	var raw_input = get_current_input()
	var input_dir = apply_input_smoothing(raw_input, delta)
	
	if input_dir.length() > character.input_deadzone:
		# Apply reduced air control
		var movement_vector = calculate_movement_vector(input_dir)
		var speed_data = get_target_speed_and_acceleration()
		
		# Reduced air control (typically 20-50% of ground control)
		var air_control_multiplier = 0.3
		var reduced_acceleration = speed_data.acceleration * air_control_multiplier
		
		apply_movement_with_acceleration(
			movement_vector,
			speed_data.speed,
			reduced_acceleration,
			delta
		)
		
		# Cancel input components if WASD is active
		cancel_all_input_components()

func handle_air_jumping():
	"""Handle multi-jumping while airborne"""
	if Input.is_action_just_pressed("jump"):
		# Check for multi-jump (no coyote time in air)
		if character.jumps_remaining > 0 and not character.is_on_floor():
			character.velocity.y = character.jump_velocity
			character.jumps_remaining -= 1
			
			print("  ⚡ Air jump performed (", character.jumps_remaining, " remaining)")

func exit():
	super.exit()
	print("  🚀 Left airborne state")

# === AIRBORNE-SPECIFIC HELPERS ===

func get_airborne_debug_info() -> Dictionary:
	"""Get airborne-specific debug info"""
	var base_info = get_debug_info()
	base_info.merge({
		"coyote_timer": character.coyote_timer,
		"jumps_remaining": character.jumps_remaining,
		"can_air_jump": character.jumps_remaining > 0,
		"fall_speed": character.velocity.y
	})
	return base_info
