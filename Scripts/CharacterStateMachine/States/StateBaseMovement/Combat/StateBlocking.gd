# BlockingState.gd - Template for defensive state
extends StateBaseMovement
class_name StateBlocking

func enter():
	super.enter()
	
	# Reduce movement speed while blocking
	character.velocity *= 0.3
	
	# Play block animation
	if character.animation_controller:
		character.animation_controller.play_block()
	
	print("  🛡️ Started blocking")

func update(delta: float):
	super.update(delta)
	
	# Apply gravity
	apply_gravity(delta)
	
	# Allow very limited movement while blocking
	handle_limited_movement(delta)
	
	# Apply physics
	character.move_and_slide()
	
	# Check for state transitions
	if not Input.is_action_pressed("block"):
		if character.is_on_floor():
			change_to("grounded")
		else:
			change_to("airborne")
	
	# Check for airborne transition
	check_for_airborne_transition()

func handle_limited_movement(delta: float):
	"""Allow slow movement while blocking"""
	var raw_input = get_current_input()
	var input_dir = apply_input_smoothing(raw_input, delta)
	
	if input_dir.length() > character.input_deadzone:
		var movement_vector = calculate_movement_vector(input_dir)
		var reduced_speed = character.walk_speed * 0.3  # Very slow while blocking
		var reduced_acceleration = character.walk_acceleration * 0.5
		
		apply_movement_with_acceleration(
			movement_vector,
			reduced_speed,
			reduced_acceleration,
			delta
		)

func exit():
	super.exit()
	print("  🛡️ Stopped blocking")
