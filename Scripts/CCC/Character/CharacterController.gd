# CharacterController.gd - Main coordinator for character systems
extends CharacterBody3D
class_name CharacterController

# === SIGNALS ===
signal ground_state_changed(is_grounded: bool)
signal jump_performed(jump_force: float, is_air_jump: bool)


# === EXPORTS ===
@export_group("Physics")
@export var gravity_multiplier = 1.0

@export_group("Component References")
@export var animation_controller: AnimationManager
@export var camera: Camera3D
@export var debug_helper: CharacterDebugHelper

# === CORE MODULES ===
var physics_module: CharacterPhysics
var state_module: CharacterState
var actions_module: CharacterActions
var signals_module: CharacterSignals

# === EXTERNAL COMPONENTS ===
var input_controller: InputController
var movement_manager: MovementManager

# === STATE ===
var base_gravity: float

func _ready():
	setup_character_controller()
	setup_core_modules()
	setup_external_components()
	connect_module_signals()

func _physics_process(delta):
	# Update all modules
	if physics_module:
		physics_module.update_physics(delta)
	
	if state_module:
		state_module.update_state_machine(delta)

# === SETUP ===

func setup_character_controller():
	"""Initialize character controller basics"""
	base_gravity = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	if base_gravity <= 0:
		base_gravity = 9.8

func setup_core_modules():
	"""Create and setup core character modules"""
	# Create physics module
	physics_module = CharacterPhysics.new()
	physics_module.name = "CharacterPhysics"
	physics_module.setup_character_reference(self)
	add_child(physics_module)
	
	# Create state module
	state_module = CharacterState.new()
	state_module.name = "CharacterState"
	state_module.setup_character_reference(self)
	add_child(state_module)
	
	# Create actions module
	actions_module = CharacterActions.new()
	actions_module.name = "CharacterActions"
	actions_module.setup_character_reference(self)
	add_child(actions_module)
	
	# Create signals module
	signals_module = CharacterSignals.new()
	signals_module.name = "CharacterSignals"
	signals_module.setup_character_reference(self)
	add_child(signals_module)

func setup_external_components():
	"""Setup references to external components"""
	# Get input controller
	input_controller = get_node_or_null("InputController") as InputController
	if not input_controller:
		push_error("No InputController found!")
		return
	
	# Get or create movement manager
	movement_manager = get_node_or_null("MovementManager")
	if not movement_manager:
		movement_manager = MovementManager.new()
		movement_manager.name = "MovementManager"
		add_child(movement_manager)
	
	# Setup camera reference for movement
	if camera and movement_manager:
		movement_manager.setup_camera_reference(camera)

func connect_module_signals():
	"""Connect signals between modules and external components"""
	if not input_controller or not movement_manager:
		return
	
	# Connect input to movement manager through signals module
	if signals_module:
		signals_module.connect_input_system(input_controller, movement_manager)
		signals_module.connect_animation_system(animation_controller)
	
	# Connect physics module to actions
	if physics_module and actions_module:
		physics_module.ground_state_changed.connect(actions_module._on_ground_state_changed)

# === PUBLIC API (Simplified) ===

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

func get_movement_speed() -> float:
	"""Get current movement speed"""
	return movement_manager.get_movement_speed() if movement_manager else 0.0

func update_ground_state():
	"""Update ground state detection"""
	if physics_module:
		physics_module.update_ground_state()

func reset_character():
	"""Reset character to initial state"""
	if state_module:
		state_module.reset_to_initial_state()
	
	if actions_module:
		actions_module.reset_actions()
	
	if physics_module:
		physics_module.reset_physics()

# === STATE MACHINE INTERFACE ===

func change_state(state_name: String):
	"""Change character state"""
	if state_module:
		state_module.change_state(state_name)

func get_current_state() -> String:
	"""Get current state name"""
	return state_module.get_current_state_name() if state_module else "unknown"

# === ACTIONS INTERFACE ===

func can_jump() -> bool:
	"""Check if character can jump"""
	return actions_module.can_jump() if actions_module else false

func can_air_jump() -> bool:
	"""Check if character can air jump"""
	return actions_module.can_air_jump() if actions_module else false

func perform_jump():
	"""Perform jump action"""
	if actions_module:
		actions_module.perform_jump()

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get comprehensive debug information"""
	var info = {
		"base_gravity": base_gravity,
		"current_state": get_current_state(),
		"movement_speed": get_movement_speed(),
		"can_jump": can_jump(),
		"can_air_jump": can_air_jump()
	}
	
	# Add module debug info
	if physics_module:
		info["physics"] = physics_module.get_debug_info()
	
	if state_module:
		info["state"] = state_module.get_debug_info()
	
	if actions_module:
		info["actions"] = actions_module.get_debug_info()
	
	if signals_module:
		info["signals"] = signals_module.get_debug_info()
	
	return info
