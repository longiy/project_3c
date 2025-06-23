# AirborneState.gd - REPLACE ENTIRE enter() function and ADD new methods
extends BaseMovementState
class_name AirborneState

# ADD THIS: Resource-driven parameters (loaded in enter())
var air_jump_velocity: float
var air_control_multiplier: float
var gravity_multiplier: float

func enter():
	super.enter()
	
	# ADD THIS: Load parameters from resource or use fallbacks
	load_parameters_from_resource()

# ADD THIS: Load parameters from resource
func load_parameters_from_resource():
	"""Load movement parameters from resource or use hardcoded fallbacks"""
	
	# Cast to specific resource type for type safety
	var airborne_resource = state_resource as AirborneStateResource
	
	if airborne_resource:
		# Use resource values
		air_jump_velocity = airborne_resource.air_jump_velocity
		air_control_multiplier = airborne_resource.air_control_multiplier
		gravity_multiplier = airborne_resource.gravity_multiplier
		
		print("🪂 Airborne state using resource values - AirJump: ", air_jump_velocity, ", AirControl: ", air_control_multiplier, ", Gravity: ", gravity_multiplier)
	else:
		# Use hardcoded fallbacks
		air_jump_velocity = 5.0
		air_control_multiplier = 0.3
		gravity_multiplier = 1.0
		
		print("🪂 Airborne state using fallback values - AirJump: ", air_jump_velocity, ", AirControl: ", air_control_multiplier, ", Gravity: ", gravity_multiplier)

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
		# Apply reduced air control using resource value
		var movement_vector = calculate_movement_vector(input_dir)
		var speed_data = get_target_speed_and_acceleration()
		
		# Use resource-driven air control multiplier
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
			# Use resource-driven air jump velocity
			character.velocity.y = air_jump_velocity
			character.jumps_remaining -= 1

func exit():
	super.exit()

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
