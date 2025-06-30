# CharacterStatesBase.gd - Fixed for 3C Framework Integration
class_name CharacterStateBase
extends State

var character: CharacterBody3D
var movement_manager: MovementManager

# Transition thresholds
var movement_stop_threshold: float = 0.1
var movement_start_threshold: float = 0.05

func enter():
	super.enter()
	character = owner_node as CharacterBody3D
	if not character:
		push_error("CharacterState requires CharacterBody3D owner")
		return
	
	movement_manager = character.get_node_or_null("MovementManager")
	if not movement_manager:
		push_error("CharacterState requires MovementManager component")

func update(delta: float):
	super.update(delta)
	handle_common_transitions()

# === MOVEMENT HELPERS ===

func apply_ground_movement(delta: float):
	"""Apply movement using MovementManager"""
	if not movement_manager:
		return
	
	# Get target velocity from movement manager
	character.velocity = movement_manager.get_target_velocity(character.velocity, delta)
	
	# Handle rotation
	var rotation_target = movement_manager.get_rotation_target()
	if movement_manager.is_movement_active:
		character.rotation.y = lerp_angle(character.rotation.y, rotation_target, movement_manager.rotation_speed * delta)

func apply_air_movement(delta: float):
	"""Apply air movement (reduced control)"""
	if not movement_manager:
		return
	
	# Reduced air control
	var air_target = movement_manager.get_target_velocity(character.velocity, delta)
	air_target *= movement_manager.air_speed_multiplier
	character.velocity.x = lerp(character.velocity.x, air_target.x, movement_manager.air_acceleration * delta)
	character.velocity.z = lerp(character.velocity.z, air_target.z, movement_manager.air_acceleration * delta)
	
	# Handle rotation in air (slower)
	var rotation_target = movement_manager.get_rotation_target()
	if movement_manager.is_movement_active:
		var air_rotation_speed = movement_manager.rotation_speed * 0.5
		character.rotation.y = lerp_angle(character.rotation.y, rotation_target, air_rotation_speed * delta)

# === TRANSITION LOGIC ===

func handle_common_transitions():
	"""Handle transitions with proper air/ground state respect"""
	if not movement_manager:
		return
	
	# PRIORITY 1: Air/Ground physics transitions (highest priority)
	if should_transition_to_air():
		change_to("airborne")
		return
	
	if should_transition_to_ground():
		change_to("landing")
		return
	
	# PRIORITY 2: Movement-based transitions (only for ground states)
	if can_do_movement_transitions() and is_grounded_state():
		handle_movement_transitions()

func should_transition_to_air() -> bool:
	"""Check if should transition to airborne state"""
	var ground_states = ["idle", "walking", "running", "landing"]
	return state_name in ground_states and not character.is_on_floor()

func should_transition_to_ground() -> bool:
	"""Check if should transition from air to ground"""
	var air_states = ["jumping", "airborne"]
	return state_name in air_states and character.is_on_floor()

func is_grounded_state() -> bool:
	"""Check if current state is a ground state"""
	var ground_states = ["idle", "walking", "running", "landing"]
	return state_name in ground_states

func is_air_state() -> bool:
	"""Check if current state is an air state"""
	var air_states = ["jumping", "airborne"]
	return state_name in air_states

func can_do_movement_transitions() -> bool:
	"""Check if this state should handle movement-based transitions"""
	var no_movement_transition_states = ["jumping", "landing"]
	return not (state_name in no_movement_transition_states)

func handle_movement_transitions():
	"""Handle movement-based state transitions"""
	if not movement_manager:
		return
	
	var current_speed = movement_manager.get_current_speed()
	var is_moving = movement_manager.is_movement_active
	var is_running = movement_manager.is_running
	
	# Determine target state based on movement
	var target_state = "idle"
	
	if is_moving and current_speed > movement_start_threshold:
		if is_running:
			target_state = "running"
		else:
			target_state = "walking"
	
	# Only transition if we're not already in the target state
	if target_state != state_name:
		change_to(target_state)

# === PHYSICS HELPERS ===

func get_movement_speed() -> float:
	"""Get current movement speed"""
	if movement_manager:
		return movement_manager.get_current_speed()
	return 0.0

func is_moving() -> bool:
	"""Check if character is moving"""
	if movement_manager:
		return movement_manager.is_movement_active
	return false

func get_input_magnitude() -> float:
	"""Get input magnitude"""
	if movement_manager:
		return movement_manager.input_magnitude
	return 0.0

# === DEBUG INFO ===

func get_state_debug_info() -> Dictionary:
	"""Get debug info for this state"""
	var base_info = get_debug_info()
	base_info["movement_speed"] = get_movement_speed()
	base_info["is_moving"] = is_moving()
	base_info["is_grounded"] = character.is_on_floor() if character else false
	base_info["can_transition"] = can_do_movement_transitions()
	return base_info
