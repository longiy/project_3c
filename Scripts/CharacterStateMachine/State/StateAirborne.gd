# AirborneState.gd - CLEANED UP VERSION
extends StateBaseMovement
class_name StateAirborne

# Resource-driven parameters
var air_jump_velocity: float
var air_control_multiplier: float
var gravity_multiplier: float

func enter():
	super.enter()
	load_parameters_from_resource()

func load_parameters_from_resource():
	"""Load movement parameters from resource"""
	var airborne_resource = state_resource as CharacterStateAirborneResource
	
	if airborne_resource:
		air_jump_velocity = airborne_resource.air_jump_velocity
		air_control_multiplier = airborne_resource.air_control_multiplier
		gravity_multiplier = airborne_resource.gravity_multiplier
		print("🪂 Airborne state loaded: AirJump=", air_jump_velocity, " AirControl=", air_control_multiplier, " Gravity=", gravity_multiplier)
	else:
		push_error("AirborneState: No resource assigned! Movement will not work correctly.")

func update(delta: float):
	super.update(delta)
	
	apply_gravity(delta)
	update_coyote_timer(delta)
	handle_air_control(delta)
	handle_air_jumping()
	handle_reset_input()
	
	character.move_and_slide()
	
	if check_for_grounded_transition():
		return

func update_coyote_timer(delta: float):
	"""Update coyote time while airborne"""
	character.coyote_timer -= delta

func handle_air_control(delta: float):
	"""Handle limited movement control while airborne"""
	var raw_input = get_current_input()
	var input_dir = apply_input_smoothing(raw_input, delta)
	
	if input_dir.length() > character.input_deadzone:
		var movement_vector = calculate_movement_vector(input_dir)
		var speed_data = get_target_speed_and_acceleration()
		var reduced_acceleration = speed_data.acceleration * air_control_multiplier
		
		apply_movement_with_acceleration(
			movement_vector,
			speed_data.speed,
			reduced_acceleration,
			delta
		)
		
		cancel_all_input_components()

func handle_air_jumping():
	"""Handle multi-jumping while airborne"""
	if Input.is_action_just_pressed("jump"):
		if character.jumps_remaining > 0 and not character.is_on_floor():
			character.velocity.y = air_jump_velocity
			character.jumps_remaining -= 1

func exit():
	super.exit()

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
