# GroundedState.gd - CLEANED UP VERSION
extends BaseMovementState
class_name GroundedState

# Resource-driven parameters
var jump_velocity: float
var coyote_time: float
var max_jumps: int

func enter():
	super.enter()
	load_parameters_from_resource()
	
	# Reset grounded-specific values
	character.coyote_timer = coyote_time
	character.jumps_remaining = max_jumps

func load_parameters_from_resource():
	"""Load movement parameters from resource"""
	var grounded_resource = state_resource as GroundedStateResource
	
	if grounded_resource:
		jump_velocity = grounded_resource.jump_velocity
		coyote_time = grounded_resource.coyote_time
		max_jumps = grounded_resource.max_jumps
		print("🏃 Grounded state loaded: Jump=", jump_velocity, " Coyote=", coyote_time, " MaxJumps=", max_jumps)
	else:
		push_error("GroundedState: No resource assigned! Movement will not work correctly.")

func update(delta: float):
	super.update(delta)
	
	apply_gravity(delta)
	handle_ground_movement(delta)
	handle_jumping()
	handle_reset_input()
	
	character.move_and_slide()
	
	if check_for_airborne_transition():
		return

func handle_jumping():
	"""Handle jump input while grounded"""
	if Input.is_action_just_pressed("jump"):
		if character.coyote_timer > 0 and character.jumps_remaining > 0:
			character.velocity.y = jump_velocity
			character.jumps_remaining -= 1
			character.coyote_timer = 0

func exit():
	super.exit()

func get_grounded_debug_info() -> Dictionary:
	"""Get grounded-specific debug info"""
	var base_info = get_debug_info()
	base_info.merge({
		"coyote_timer": character.coyote_timer,
		"jumps_remaining": character.jumps_remaining,
		"can_jump": character.coyote_timer > 0 and character.jumps_remaining > 0
	})
	return base_info
