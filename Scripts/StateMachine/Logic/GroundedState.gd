# GroundedState.gd - REPLACE ENTIRE enter() function
extends BaseMovementState
class_name GroundedState

# ADD THIS: Resource-driven parameters (loaded in enter())
var jump_velocity: float
var coyote_time: float
var max_jumps: int

func enter():
	super.enter()
	
	# ADD THIS: Load parameters from resource or use fallbacks
	load_parameters_from_resource()
	
	# Reset grounded-specific values
	character.coyote_timer = coyote_time
	character.jumps_remaining = max_jumps

# ADD THIS: Load parameters from resource
func load_parameters_from_resource():
	"""Load movement parameters from resource or use hardcoded fallbacks"""
	
	# Cast to specific resource type for type safety
	var grounded_resource = state_resource as GroundedStateResource
	
	if grounded_resource:
		# Use resource values
		jump_velocity = grounded_resource.jump_velocity
		coyote_time = grounded_resource.coyote_time
		max_jumps = grounded_resource.max_jumps
		
		print("🏃 Grounded state using resource values - Jump: ", jump_velocity, ", Coyote: ", coyote_time, ", MaxJumps: ", max_jumps)
	else:
		# Use hardcoded fallbacks  
		jump_velocity = 6.0
		coyote_time = 0.1
		max_jumps = 2
		
		print("🏃 Grounded state using fallback values - Jump: ", jump_velocity, ", Coyote: ", coyote_time, ", MaxJumps: ", max_jumps)

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

# MODIFY THIS: Update handle_jumping to use resource values
func handle_jumping():
	"""Handle jump input while grounded"""
	if Input.is_action_just_pressed("jump"):
		if character.coyote_timer > 0 and character.jumps_remaining > 0:
			# Use resource-driven jump velocity
			character.velocity.y = jump_velocity
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
