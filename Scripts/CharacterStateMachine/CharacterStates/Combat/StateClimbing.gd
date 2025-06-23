# ClimbingState.gd - Template for environmental interaction
extends StateBaseMovement
class_name StateClimbing

var climb_speed = 2.0

func enter():
	super.enter()
	
	# Disable gravity while climbing
	character.velocity.y = 0
	
	print("  🧗 Started climbing")

func update(delta: float):
	super.update(delta)
	
	# Handle climbing movement
	handle_climbing_movement(delta)
	
	# Apply physics
	character.move_and_slide()
	
	# Check for dismount
	if Input.is_action_just_pressed("jump") or not can_continue_climbing():
		change_to("airborne")

func handle_climbing_movement(delta: float):
	"""Handle movement while climbing"""
	var input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	# Vertical movement (up/down)
	character.velocity.y = -input.y * climb_speed
	
	# Limited horizontal movement
	var movement_vector = calculate_movement_vector(Vector2(input.x, 0))
	apply_movement_with_acceleration(
		movement_vector,
		climb_speed * 0.5,  # Slower horizontal movement
		character.walk_acceleration,
		delta
	)

func can_continue_climbing() -> bool:
	"""Check if character can still climb (wall detection, etc.)"""
	# TODO: Implement wall detection logic
	return true

func exit():
	super.exit()
	print("  🧗 Stopped climbing")
