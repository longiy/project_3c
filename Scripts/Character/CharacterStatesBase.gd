# CharacterStatesBase.gd - Updated for modular system
class_name CharacterStateBase
extends State

var character: CharacterBody3D
var movement_manager: MovementManager
var physics_module: CharacterPhysics  # NEW: Access to physics module

# Transition thresholds
var movement_stop_threshold: float = 0.1
var movement_start_threshold: float = 0.05

func enter():
	super.enter()
	character = owner_node as CharacterBody3D
	if not character:
		push_error("CharacterState requires CharacterBody3D owner")
		return
	
	# Get movement manager (existing)
	movement_manager = character.get_node_or_null("MovementManager")
	if not movement_manager:
		push_error("CharacterState requires MovementManager component")
	
	# NEW: Get physics module reference
	physics_module = character.get_node_or_null("CharacterPhysics")
	if not physics_module:
		# Fallback to character methods if module not found
		push_warning("CharacterPhysics module not found - using fallback methods")

func update(delta: float):
	super.update(delta)
	handle_common_transitions()

# === MOVEMENT HELPERS (UPDATED FOR MODULES) ===

func apply_ground_movement(delta: float):
	"""Apply ground movement through movement manager"""
	if movement_manager:
		movement_manager.apply_ground_movement(delta)

func apply_air_movement(delta: float):
	"""Apply air movement through movement manager"""
	if movement_manager:
		movement_manager.apply_air_movement(delta)

func apply_gravity(delta: float):
	"""Apply gravity through physics module or fallback"""
	if physics_module:
		# Let physics module handle it, but ensure it's called
		physics_module.apply_gravity(delta)
	else:
		# Fallback to character method
		character.apply_gravity(delta)

func update_ground_state():
	"""Update ground state through actions module or fallback"""
	# NEW: Check if actions module exists
	var actions_module = character.get_node_or_null("CharacterActions")
	if actions_module:
		# Actions module handles this automatically via signals
		pass
	else:
		# Fallback to character method
		character.update_ground_state()

func move_and_slide():
	"""Execute movement through physics module or fallback"""
	if physics_module:
		# Let physics module handle it, but ensure it's called
		physics_module.execute_movement()
	else:
		# Fallback to direct character call
		character.move_and_slide()

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
	return state_name in ground_states and not is_character_grounded()

func should_transition_to_ground() -> bool:
	"""Check if should transition from air to ground"""
	var air_states = ["jumping", "airborne"]
	return state_name in air_states and is_character_grounded()

func is_character_grounded() -> bool:
	"""Check if character is grounded (compatible with modules)"""
	# NEW: Use physics module if available
	if physics_module:
		return physics_module.is_grounded()
	else:
		return character.is_on_floor()

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
	
	var current_speed = get_movement_speed()
	var is_moving = current_speed > movement_start_threshold
	var is_stopped = current_speed <= movement_stop_threshold
	
	# Get target state from movement manager
	var target_state = movement_manager.should_transition_to_state(state_name)
	if target_state != "" and target_state != state_name:
		change_to(target_state)
		return
	
	# Fallback logic if movement manager doesn't provide target
	match state_name:
		"idle":
			if is_moving:
				if movement_manager.is_running:
					change_to("running")
				else:
					change_to("walking")
		
		"walking", "running":
			if is_stopped:
				change_to("idle")
			elif movement_manager.is_running and state_name != "running":
				change_to("running")
			elif not movement_manager.is_running and state_name == "running":
				change_to("walking")

# === UTILITY FUNCTIONS ===

func get_movement_speed() -> float:
	"""Get current movement speed (compatible with modules)"""
	if movement_manager:
		return movement_manager.get_movement_speed()
	elif physics_module:
		return physics_module.get_horizontal_speed()
	else:
		return Vector2(character.velocity.x, character.velocity.z).length()

func get_character_velocity() -> Vector3:
	"""Get character velocity (compatible with modules)"""
	if physics_module:
		return physics_module.get_velocity()
	else:
		return character.velocity

func change_to(new_state: String):
	"""Change to new state"""
	if state_machine:
		state_machine.change_state(new_state)
