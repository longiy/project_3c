# CharacterStateBase.gd - Updated for CCC compatibility
class_name CharacterStateBase
extends State

# === CHARACTER REFERENCES ===
var character: CharacterBody3D

# === COMPONENT REFERENCES ===
var movement_manager: MovementManager
var input_manager: InputManager
var jump_system: JumpSystem
var animation_manager: AnimationManager

# === CCC REFERENCES ===
var ccc_character_manager: CCC_CharacterManager
var ccc_control_manager: CCC_ControlManager
var movement_system: MovementSystem

# === ARCHITECTURE DETECTION ===
var using_ccc: bool = false

func enter():
	"""Setup character and component references"""
	super.enter()
	setup_references()
	check_architecture()

func setup_references():
	"""Setup character and component references"""
	character = owner_node as CharacterBody3D
	if not character:
		push_error("CharacterStateBase: owner_node is not CharacterBody3D!")
		return
	
	# Get standard components
	jump_system = character.get_node_or_null("JumpSystem")
	animation_manager = character.get_node_or_null("AnimationManager")
	input_manager = character.get_node_or_null("InputManager")
	
	# Get CCC components
	ccc_character_manager = character.get_node_or_null("CCC_CharacterManager")
	ccc_control_manager = character.get_node_or_null("CCC_ControlManager")
	
	# Get movement system (try CCC first, then legacy)
	if ccc_character_manager and ccc_character_manager.movement_system:
		movement_system = ccc_character_manager.movement_system
		using_ccc = true
	else:
		movement_manager = character.get_node_or_null("MovementManager")
		using_ccc = false

func check_architecture():
	"""Check which architecture is being used"""
	if using_ccc:
		print("🏗️ State ", state_name, ": Using CCC architecture")
	else:
		print("🏗️ State ", state_name, ": Using legacy architecture")

# === MOVEMENT HELPERS (Architecture-aware) ===

func apply_ground_movement(delta: float):
	"""Apply ground movement - works with both CCC and legacy"""
	if using_ccc and movement_system:
		# CCC: MovementSystem handles physics automatically
		pass
	elif movement_manager:
		movement_manager.apply_ground_movement(delta)

func apply_air_movement(delta: float):
	"""Apply air movement - works with both CCC and legacy"""
	if using_ccc and movement_system:
		# CCC: MovementSystem handles physics automatically
		pass
	elif movement_manager:
		movement_manager.apply_air_movement(delta)

func get_movement_speed() -> float:
	"""Get movement speed - works with both CCC and legacy"""
	if using_ccc and ccc_character_manager:
		return ccc_character_manager.get_movement_speed()
	elif movement_manager:
		return movement_manager.get_movement_speed()
	else:
		var horizontal_velocity = Vector2(character.velocity.x, character.velocity.z)
		return horizontal_velocity.length()

func is_movement_active() -> bool:
	"""Check if movement is active - works with both CCC and legacy"""
	if using_ccc and ccc_character_manager:
		return ccc_character_manager.is_movement_active()
	elif movement_manager:
		return movement_manager.is_movement_active
	else:
		return get_movement_speed() > 0.1

func is_running() -> bool:
	"""Check if running - works with both CCC and legacy"""
	if using_ccc and ccc_character_manager:
		return ccc_character_manager.is_running()
	elif movement_manager:
		return movement_manager.is_running
	return false

func is_slow_walking() -> bool:
	"""Check if slow walking - works with both CCC and legacy"""
	if using_ccc and ccc_character_manager:
		return ccc_character_manager.is_slow_walking()
	elif movement_manager:
		return movement_manager.is_slow_walking
	return false

func get_input_direction() -> Vector2:
	"""Get input direction - works with both CCC and legacy"""
	if using_ccc and ccc_character_manager:
		return ccc_character_manager.get_current_input_direction()
	elif movement_manager:
		return movement_manager.current_input_direction
	elif input_manager:
		return input_manager.get_current_input_direction()
	return Vector2.ZERO

# === JUMP HELPERS ===

func can_jump() -> bool:
	"""Check if can jump"""
	if jump_system:
		return jump_system.can_jump()
	return character.is_on_floor()

func can_air_jump() -> bool:
	"""Check if can air jump"""
	if jump_system:
		return jump_system.can_air_jump()
	return false

func attempt_jump():
	"""Attempt to jump"""
	if jump_system:
		jump_system.attempt_jump()

# === COMMON STATE TRANSITIONS ===

func check_movement_transitions():
	"""Check for movement-based state transitions"""
	var speed = get_movement_speed()
	var is_grounded = character.is_on_floor()
	var has_input = get_input_direction().length() > 0.1
	
	# Ground state transitions
	if is_grounded:
		if state_name == "airborne" or state_name == "jumping":
			change_to("landing")
		elif state_name == "idle" and has_input:
			if is_running():
				change_to("running")
			else:
				change_to("walking")
		elif state_name == "walking" and is_running():
			change_to("running")
		elif state_name == "running" and not is_running():
			change_to("walking")
		elif (state_name == "walking" or state_name == "running") and not has_input:
			change_to("idle")
	
	# Air state transitions
	else:
		if state_name != "jumping" and state_name != "airborne":
			change_to("airborne")

func check_jump_transitions():
	"""Check for jump-based state transitions"""
	if character.is_on_floor():
		return
	
	# If in air but not in jumping/airborne state
	if state_name not in ["jumping", "airborne"]:
		change_to("airborne")

# === PHYSICS HELPERS ===

func apply_gravity(delta: float):
	"""Apply gravity to character"""
	if not character.is_on_floor():
		var gravity = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
		character.velocity.y -= gravity * delta

func update_ground_state():
	"""Update ground state for jump system"""
	if jump_system:
		jump_system.update_ground_state()

# === DEBUG HELPERS ===

func get_state_debug_info() -> Dictionary:
	"""Get debug information for this state"""
	return {
		"state_name": state_name,
		"using_ccc": using_ccc,
		"movement_speed": get_movement_speed(),
		"is_grounded": character.is_on_floor(),
		"is_movement_active": is_movement_active(),
		"is_running": is_running(),
		"input_direction": get_input_direction(),
		"can_jump": can_jump(),
		"time_in_state": time_in_state
	}
