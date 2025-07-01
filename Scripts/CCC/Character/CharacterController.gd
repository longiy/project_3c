# CharacterController.gd - Refactored main coordinator
extends CharacterBody3D

# === EXPORT PARAMETERS FOR DESIGNERS ===
@export_group("Component References")
@export var animation_controller: AnimationManager
@export var camera: Camera3D
@export var input_manager: InputManager
@export var debug_helper: CharacterDebugHelper

@export_group("Physics Tuning")
@export var gravity_multiplier = 1.0

@export_group("Action Tuning") 
@export var jump_height = 6.0
@export var air_jump_height = 4.8
@export var max_air_jumps = 1

# === SIGNALS ===
signal ground_state_changed(is_grounded: bool)
signal jump_performed(jump_force: float, is_air_jump: bool)

# === CORE MODULES ===
var physics_module: CharacterPhysics
var actions_module: CharacterActions
var state_machine: CharacterStateMachine
var movement_manager: MovementManager

func _ready():
	setup_modules()
	setup_legacy_components()
	connect_module_signals()
	propagate_export_parameters()

# === MODULE SETUP ===

func setup_modules():
	"""Create and setup the new modular components"""
	# Create physics module
	physics_module = CharacterPhysics.new()
	physics_module.name = "CharacterPhysics"
	physics_module.gravity_multiplier = gravity_multiplier
	add_child(physics_module)
	
	# Create actions module
	actions_module = CharacterActions.new()
	actions_module.name = "CharacterActions"
	actions_module.jump_height = jump_height
	actions_module.air_jump_height = air_jump_height
	actions_module.max_air_jumps = max_air_jumps
	add_child(actions_module)
	
	print("✅ CharacterController: Modules created and initialized")

func setup_legacy_components():
	"""Setup existing components that haven't been refactored yet"""
	# Get existing components
	state_machine = get_node_or_null("CharacterStateMachine") as CharacterStateMachine
	if not state_machine:
		push_error("No CharacterStateMachine found!")
		return
	
	# Create or get movement manager
	movement_manager = get_node_or_null("MovementManager")
	if not movement_manager:
		movement_manager = MovementManager.new()
		movement_manager.name = "MovementManager"
		add_child(movement_manager)
	
	# Setup camera reference for movement manager
	if camera and movement_manager:
		movement_manager.setup_camera_reference(camera)

func connect_module_signals():
	"""Connect signals between modules and legacy components"""
	# Connect physics module signals
	if physics_module:
		physics_module.ground_state_changed.connect(_on_ground_state_changed)
		physics_module.ground_state_changed.connect(ground_state_changed.emit)
	
	# Connect actions module signals  
	if actions_module:
		actions_module.jump_performed.connect(_on_jump_performed)
	
	# Connect input manager signals (legacy)
	if input_manager:
		connect_input_signals()

func propagate_export_parameters():
	"""Propagate exported parameters to modules"""
	if physics_module:
		physics_module.gravity_multiplier = gravity_multiplier
	
	if actions_module:
		actions_module.jump_height = jump_height
		actions_module.air_jump_height = air_jump_height
		actions_module.max_air_jumps = max_air_jumps

# === LEGACY INPUT SIGNAL CONNECTIONS ===

func connect_input_signals():
	"""Connect legacy input manager signals"""
	input_manager.movement_started.connect(_on_movement_started)
	input_manager.movement_updated.connect(_on_movement_updated)
	input_manager.movement_stopped.connect(_on_movement_stopped)
	input_manager.sprint_started.connect(_on_sprint_started)
	input_manager.sprint_stopped.connect(_on_sprint_stopped)
	input_manager.slow_walk_started.connect(_on_slow_walk_started)
	input_manager.slow_walk_stopped.connect(_on_slow_walk_stopped)
	input_manager.jump_pressed.connect(_on_jump_pressed)
	input_manager.reset_pressed.connect(_on_reset_pressed)
	
	# Connect movement manager to animation controller
	if animation_controller and movement_manager:
		movement_manager.movement_changed.connect(animation_controller._on_movement_changed)
		movement_manager.mode_changed.connect(animation_controller._on_mode_changed)

# === PHYSICS PROCESS ===

func _physics_process(delta):
	# State machine update (legacy)
	if state_machine:
		state_machine.update(delta)
	
	# Physics and actions are handled by their modules automatically

# === MODULE SIGNAL HANDLERS ===

func _on_ground_state_changed(is_grounded: bool):
	"""Handle ground state changes from physics module"""
	# This is automatically forwarded to other systems that need it
	pass

func _on_jump_performed(jump_force: float, jump_type: String):
	"""Handle jump performed from actions module"""
	var is_air_jump = (jump_type == "air")
	jump_performed.emit(jump_force, is_air_jump)
	
	# Transition to jumping state
	if state_machine:
		state_machine.change_state("jumping")

# === LEGACY INPUT SIGNAL HANDLERS ===

func _on_movement_started(direction: Vector2, magnitude: float):
	if movement_manager:
		movement_manager.handle_movement_action("move_start", {"direction": direction, "magnitude": magnitude})

func _on_movement_updated(direction: Vector2, magnitude: float):
	if movement_manager:
		movement_manager.handle_movement_action("move_update", {"direction": direction, "magnitude": magnitude})

func _on_movement_stopped():
	if movement_manager:
		movement_manager.handle_movement_action("move_end")

func _on_sprint_started():
	if movement_manager:
		movement_manager.handle_mode_action("sprint_start")

func _on_sprint_stopped():
	if movement_manager:
		movement_manager.handle_mode_action("sprint_end")

func _on_slow_walk_started():
	if movement_manager:
		movement_manager.handle_mode_action("slow_walk_start")

func _on_slow_walk_stopped():
	if movement_manager:
		movement_manager.handle_mode_action("slow_walk_end")

func _on_jump_pressed():
	"""Handle jump input through actions module"""
	if actions_module and actions_module.can_jump_at_all():
		actions_module.perform_jump()
	else:
		# Buffer the jump input
		if actions_module:
			actions_module.handle_jump_input()

func _on_reset_pressed():
	reset_character()

# === LEGACY MOVEMENT INTERFACE (For State Machine) ===

func apply_ground_movement(delta: float):
	"""Legacy interface for state machine"""
	if movement_manager:
		movement_manager.apply_ground_movement(delta)

func apply_air_movement(delta: float):
	"""Legacy interface for state machine"""
	if movement_manager:
		movement_manager.apply_air_movement(delta)

func get_movement_speed() -> float:
	"""Legacy interface for state machine"""
	if movement_manager:
		return movement_manager.get_movement_speed()
	return 0.0

func get_target_speed() -> float:
	"""Legacy interface for state machine"""
	if movement_manager:
		return movement_manager.get_target_speed()
	return 0.0

# === LEGACY JUMP INTERFACE (For State Machine) ===

func can_jump() -> bool:
	"""Legacy interface - now delegates to actions module"""
	return actions_module.can_jump() if actions_module else false

func can_air_jump() -> bool:
	"""Legacy interface - now delegates to actions module"""
	return actions_module.can_air_jump() if actions_module else false

func perform_jump(jump_force: float):
	"""Legacy interface - now delegates to actions module"""
	if actions_module:
		actions_module.perform_jump(jump_force)

func update_ground_state():
	"""Legacy interface - now handled automatically by physics module"""
	# This is now automatic, but keeping for compatibility
	pass

# === LEGACY PHYSICS INTERFACE (For State Machine) ===

func apply_gravity(delta: float):
	"""Legacy interface - now handled by physics module"""
	# Physics module handles this automatically
	pass

# === MOVEMENT MODE PROPERTIES ===

var is_running: bool:
	get:
		return movement_manager.is_running if movement_manager else false

var is_slow_walking: bool:
	get:
		return movement_manager.is_slow_walking if movement_manager else false

# === STATE MACHINE INTERFACE ===

func should_transition_to_state(current_state: String) -> String:
	"""Legacy interface for state machine"""
	if movement_manager:
		return movement_manager.should_transition_to_state(current_state)
	return ""

func get_current_state_name() -> String:
	"""Get current state name"""
	return state_machine.get_current_state_name() if state_machine else "none"

func get_previous_state_name() -> String:
	"""Get previous state name"""
	return state_machine.get_previous_state_name() if state_machine else "none"

# === PUBLIC API ===

func get_physics_module() -> CharacterPhysics:
	"""Get physics module reference"""
	return physics_module

func get_actions_module() -> CharacterActions:
	"""Get actions module reference"""
	return actions_module

func get_character_velocity() -> Vector3:
	"""Get current velocity"""
	if physics_module:
		return physics_module.get_velocity()
	return velocity

func set_character_velocity(new_velocity: Vector3):
	"""Set velocity through physics module"""
	if physics_module:
		physics_module.set_velocity(new_velocity)
	else:
		velocity = new_velocity

func add_impulse(impulse: Vector3):
	"""Add impulse through physics module"""
	if physics_module:
		physics_module.add_impulse(impulse)
	else:
		velocity += impulse

func is_grounded() -> bool:
	"""Check if character is grounded"""
	if physics_module:
		return physics_module.is_grounded()
	return is_on_floor()

# === RESET AND CLEANUP ===

func reset_character():
	"""Reset character to initial state"""
	if actions_module:
		actions_module.reset_all_actions()
	
	if physics_module:
		physics_module.reset_physics()
	
	if movement_manager:
		movement_manager.reset_movement_state()
	
	if debug_helper:
		debug_helper.reset_character()

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get comprehensive debug information"""
	var debug_info = {
		"controller": {
			"current_state": get_current_state_name(),
			"movement_speed": get_movement_speed(),
			"is_grounded": is_grounded(),
			"is_running": is_running,
			"is_slow_walking": is_slow_walking
		}
	}
	
	if physics_module:
		debug_info["physics"] = physics_module.get_debug_info()
	
	if actions_module:
		debug_info["actions"] = actions_module.get_debug_info()
	
	if movement_manager:
		debug_info["movement"] = movement_manager.get_debug_info()
	
	if debug_helper:
		var helper_info = debug_helper.get_comprehensive_debug_info()
		debug_info.merge(helper_info)
	
	return debug_info

# === PARAMETER UPDATES (For Runtime Tweaking) ===

func update_gravity_multiplier(new_value: float):
	"""Update gravity multiplier at runtime"""
	gravity_multiplier = new_value
	if physics_module:
		physics_module.gravity_multiplier = new_value

func update_jump_height(new_value: float):
	"""Update jump height at runtime"""
	jump_height = new_value
	if actions_module:
		actions_module.jump_height = new_value

func update_air_jump_height(new_value: float):
	"""Update air jump height at runtime"""
	air_jump_height = new_value
	if actions_module:
		actions_module.air_jump_height = new_value

func update_max_air_jumps(new_value: int):
	"""Update max air jumps at runtime"""
	max_air_jumps = new_value
	if actions_module:
		actions_module.max_air_jumps = new_value
