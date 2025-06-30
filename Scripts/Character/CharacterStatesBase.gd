# CharacterStateBase.gd - Base class for modular character states
extends State
class_name CharacterStateBase

# === REFERENCES ===
# state_machine inherited from State (untyped for compatibility)
var character: CharacterController

# === MODULES (Quick Access) ===
var physics_module: CharacterPhysics
var actions_module: CharacterActions
var movement_manager: MovementManager

# === STATE LIFECYCLE ===

func enter():
	"""Called when entering this state"""
	super.enter()  # Call parent enter() for timing
	setup_module_references()
	if enable_state_logging():
		print("🎯 Entered state: ", state_name)

func exit():
	"""Called when exiting this state"""
	super.exit()  # Call parent exit()
	if enable_state_logging():
		print("🚪 Exited state: ", state_name)

func update(delta: float):
	"""Called every physics frame while in this state"""
	super.update(delta)  # Call parent update() for timing

func handle_input(event: InputEvent):
	"""Called when input events occur while in this state"""
	super.handle_input(event)  # Call parent handle_input()

# === MODULE SETUP ===

func setup_module_references():
	"""Setup quick access to character modules"""
	# Get character reference from state machine
	if state_machine and state_machine.has_property("character"):
		character = state_machine.character as CharacterController
		owner_node = character  # Set compatibility reference
	
	# If we have a character controller, get its modules
	if character:
		physics_module = character.physics_module
		actions_module = character.actions_module
		movement_manager = character.movement_manager
	else:
		# Fallback: try to find character from owner_node
		if owner_node and owner_node is CharacterController:
			character = owner_node as CharacterController
			physics_module = character.physics_module
			actions_module = character.actions_module
			movement_manager = character.movement_manager

# === COMMON STATE UTILITIES ===

func apply_gravity(delta: float):
	"""Apply gravity to character"""
	if physics_module:
		physics_module.apply_gravity(delta)

func apply_ground_movement(delta: float):
	"""Apply ground movement"""
	if movement_manager:
		movement_manager.apply_ground_movement(delta)

func apply_air_movement(delta: float):
	"""Apply air movement"""
	if movement_manager:
		movement_manager.apply_air_movement(delta)

func perform_move_and_slide():
	"""Execute movement physics"""
	if physics_module:
		physics_module.perform_move_and_slide()

func change_state(new_state: String):
	"""Change to a different state"""
	if state_machine:
		state_machine.change_state(new_state)

# === MOVEMENT QUERIES ===

func get_movement_speed() -> float:
	"""Get current movement speed"""
	return movement_manager.get_movement_speed() if movement_manager else 0.0

func is_moving() -> bool:
	"""Check if character is moving"""
	return get_movement_speed() > 0.1

func is_grounded() -> bool:
	"""Check if character is on ground"""
	return physics_module.is_grounded() if physics_module else false

func get_velocity() -> Vector3:
	"""Get character velocity"""
	return physics_module.get_velocity() if physics_module else Vector3.ZERO

# === ACTION QUERIES ===

func can_jump() -> bool:
	"""Check if character can jump"""
	return actions_module.can_jump() if actions_module else false

func can_air_jump() -> bool:
	"""Check if character can air jump"""
	return actions_module.can_air_jump() if actions_module else false

func perform_jump():
	"""Execute jump action"""
	if actions_module:
		actions_module.perform_jump()

# === STATE TRANSITION HELPERS ===

func check_for_movement_transitions():
	"""Check for common movement-based state transitions"""
	if not is_grounded():
		change_state("airborne")
		return true
	
	var speed = get_movement_speed()
	if speed > 0.1:
		if movement_manager and movement_manager.is_running:
			change_state("running")
		else:
			change_state("walking")
		return true
	else:
		change_state("idle")
		return true
	
	return false

func check_for_jump_transition() -> bool:
	"""Check for jump transition"""
	if actions_module and actions_module.jump_buffer_timer > 0 and can_jump():
		perform_jump()
		change_state("jumping")
		return true
	return false

func check_for_landing_transition() -> bool:
	"""Check for landing transition"""
	if is_grounded() and get_velocity().y <= 0:
		change_state("landing")
		return true
	return false

# === UTILITY FUNCTIONS ===

func enable_state_logging() -> bool:
	"""Check if state logging is enabled"""
	return state_machine and state_machine.enable_debug_transitions

func get_state_time() -> float:
	"""Get time spent in current state"""
	# This could be enhanced to track state entry time
	return 0.0

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get state-specific debug information"""
	return {
		"state_name": state_name,
		"is_grounded": is_grounded(),
		"is_moving": is_moving(),
		"movement_speed": get_movement_speed(),
		"velocity": get_velocity(),
		"can_jump": can_jump(),
		"can_air_jump": can_air_jump()
	}
