# BaseMovementState.gd - Shared functionality for all movement states
extends State
class_name BaseMovementState

# Cache character reference for performance
var character: CharacterBody3D

func enter():
	super.enter()
	character = owner as CharacterBody3D
	if not character:
		push_error("BaseMovementState requires CharacterBody3D owner")

# === SHARED PHYSICS METHODS ===

func apply_gravity(delta: float):
	"""Apply gravity to character"""
	if not character.is_on_floor():
		character.velocity.y -= (character.base_gravity * character.gravity_multiplier) * delta

func handle_reset_input():
	"""Handle reset input (shared across all states)"""
	if Input.is_action_just_pressed("reset"):
		character.reset_character_transform()

# === SHARED INPUT METHODS ===

func get_current_input() -> Vector2:
	"""Get current movement input (delegates to character's arbitration system)"""
	return character.get_current_input()

func apply_input_smoothing(raw_input: Vector2, delta: float) -> Vector2:
	"""Apply input smoothing (delegates to character)"""
	return character.apply_input_smoothing(raw_input, delta)

func get_movement_mode_inputs() -> Dictionary:
	"""Get current movement mode (walk/run/sprint)"""
	return {
		"is_slow_walking": Input.is_action_pressed("walk"),
		"is_running": Input.is_action_pressed("sprint") and not Input.is_action_pressed("walk")
	}

# === SHARED MOVEMENT METHODS ===

func calculate_movement_vector(input_dir: Vector2) -> Vector3:
	"""Calculate 3D movement vector from 2D input"""
	return character.calculate_movement_vector(input_dir)

func apply_movement_with_acceleration(movement_vector: Vector3, target_speed: float, acceleration: float, delta: float):
	"""Apply movement with proper acceleration"""
	if movement_vector.length() > 0:
		var movement_direction = movement_vector.normalized()
		
		# Smooth acceleration to target speed
		character.velocity.x = move_toward(character.velocity.x, movement_direction.x * target_speed, acceleration * delta)
		character.velocity.z = move_toward(character.velocity.z, movement_direction.z * target_speed, acceleration * delta)
		
		# Handle rotation
		var target_rotation = atan2(movement_direction.x, movement_direction.z)
		character.rotation.y = lerp_angle(character.rotation.y, target_rotation, character.rotation_speed * delta)

func apply_deceleration(delta: float):
	"""Apply deceleration when no input"""
	character.velocity.x = move_toward(character.velocity.x, 0, character.deceleration * delta)
	character.velocity.z = move_toward(character.velocity.z, 0, character.deceleration * delta)

func get_target_speed_and_acceleration() -> Dictionary:
	"""Get target speed and acceleration based on movement mode"""
	var modes = get_movement_mode_inputs()
	
	if modes.is_slow_walking:
		return {
			"speed": character.slow_walk_speed,
			"acceleration": character.slow_walk_acceleration
		}
	elif modes.is_running:
		return {
			"speed": character.run_speed,
			"acceleration": character.run_acceleration  
		}
	else:
		return {
			"speed": character.walk_speed,
			"acceleration": character.walk_acceleration
		}

# === SHARED UTILITY METHODS ===

func should_process_movement() -> bool:
	"""Check if movement should be processed (respects input duration)"""
	var raw_input = get_current_input()
	var has_input_now = raw_input.length() > character.input_deadzone
	
	return has_input_now and (
		character.get_input_duration() >= character.min_input_duration or 
		character.get_movement_speed() > 0.5
	)

func cancel_all_input_components():
	"""Cancel all input components"""
	character.cancel_all_input_components()

# === SHARED STATE TRANSITION HELPERS ===

func check_for_airborne_transition():
	"""Check if character should transition to airborne"""
	if not character.is_on_floor():
		change_to("airborne")
		return true
	return false

func check_for_grounded_transition():
	"""Check if character should transition to grounded"""
	if character.is_on_floor():
		change_to("grounded")
		return true
	return false

# === DEBUG HELPERS ===

func get_debug_info() -> Dictionary:
	"""Get debug information for this state"""
	return {
		"state_name": state_name,
		"time_in_state": time_in_state,
		"character_speed": character.get_movement_speed(),
		"character_grounded": character.is_on_floor(),
		"input_duration": character.get_input_duration()
	}
