# CCC_CharacterManager.gd - Phase 1B: CHARACTER DOMAIN ORCHESTRATOR
extends Node
class_name CCC_CharacterManager

# === OWNED SYSTEMS ===
var movement_system: MovementSystem
var jump_system: JumpSystem
var state_machine: CharacterStateMachine
var animation_manager: AnimationManager

# === CHARACTER PROPERTIES (Absorbed from MovementManager) ===
@export_group("Movement Settings")
@export var walk_speed = 3.0
@export var run_speed = 6.0
@export var slow_walk_speed = 1.5
@export var air_speed_multiplier = 0.6

@export_group("Physics")
@export var ground_acceleration = 15.0
@export var air_acceleration = 8.0
@export var deceleration = 18.0
@export var rotation_speed = 12.0

# === CHARACTER DOMAIN SIGNALS ===
signal character_moved(direction: Vector2, speed: float)
signal character_jumped(force: float, is_air_jump: bool)
signal character_state_changed(new_state: String)
signal animation_changed(animation: String, blend_value: float)

# === CHARACTER TYPE CONFIGURATION ===
enum CharacterType {
	AVATAR,        # Direct character control (current implementation)
	OBSERVER,      # Watch-only, no direct control
	COMMANDER,     # Control multiple units/characters
	COLLABORATOR   # Shared control with AI/other players
}

var character_configs = {
	CharacterType.AVATAR: {
		"allows_direct_control": true,
		"movement_responsiveness": 1.0,
		"embodiment_quality": 1.0,
		"ai_assistance": false
	},
	CharacterType.OBSERVER: {
		"allows_direct_control": false,
		"movement_responsiveness": 0.0,
		"embodiment_quality": 0.3,
		"ai_assistance": false
	},
	CharacterType.COMMANDER: {
		"allows_direct_control": true,
		"movement_responsiveness": 0.7,
		"embodiment_quality": 0.6,
		"ai_assistance": true
	}
}

var current_character_type: CharacterType = CharacterType.AVATAR

# === REFERENCES ===
var character: CharacterBody3D
var camera: Camera3D

# === MIGRATION STATE ===
var old_movement_manager: MovementManager

func _ready():
	setup_character_domain()
	orchestrate_character_systems()
	print("✅ CCC_CharacterManager: Character domain orchestration established")

func setup_character_domain():
	"""Setup character domain components"""
	# Get character reference
	character = get_parent() as CharacterBody3D
	if not character:
		push_error("CCC_CharacterManager: No CharacterBody3D parent found!")
		return
	
	# Create MovementSystem as child
	movement_system = MovementSystem.new()
	movement_system.name = "MovementSystem"
	add_child(movement_system)
	
	# Setup movement system properties
	movement_system.setup_character(character)
	movement_system.copy_settings_from_manager(self)
	
	# Find existing systems
	jump_system = get_parent().get_node_or_null("JumpSystem")
	state_machine = get_parent().get_node_or_null("CharacterStateMachine")
	animation_manager = get_parent().get_node_or_null("AnimationManager")
	
	# Absorb existing MovementManager
	absorb_movement_manager()

func absorb_movement_manager():
	"""Absorb existing MovementManager and disable it"""
	old_movement_manager = get_parent().get_node_or_null("MovementManager")
	if old_movement_manager:
		# Copy properties from old movement manager
		movement_system.copy_properties_from(old_movement_manager)
		
		# Disconnect old signals
		disconnect_old_movement_manager()
		
		# Disable old movement manager (don't delete yet for safety)
		old_movement_manager.set_physics_process(false)
		old_movement_manager.set_process(false)
		old_movement_manager.name = "MovementManager_OLD"
		
		print("🔄 CCC_CharacterManager: Absorbed MovementManager")

func disconnect_old_movement_manager():
	"""Safely disconnect old movement manager signals"""
	if not old_movement_manager:
		return
	
	# Get all connections and disconnect them
	var connections = old_movement_manager.movement_changed.get_connections()
	for connection in connections:
		old_movement_manager.movement_changed.disconnect(connection.callable)
	
	connections = old_movement_manager.mode_changed.get_connections()
	for connection in connections:
		old_movement_manager.mode_changed.disconnect(connection.callable)

func orchestrate_character_systems():
	"""Orchestrate character domain systems"""
	# Connect internal systems
	if movement_system:
		movement_system.movement_changed.connect(_on_movement_changed)
		movement_system.mode_changed.connect(_on_mode_changed)
	
	if jump_system:
		jump_system.jump_performed.connect(_on_jump_performed)
	
	if state_machine:
		state_machine.state_changed.connect(_on_state_changed)
	
	# Character manager coordinates all character systems
	coordinate_movement_and_animation()
	coordinate_physics_and_states()

func coordinate_movement_and_animation():
	"""Coordinate movement with animation systems"""
	if not animation_manager or not movement_system:
		return
	
	# Connect movement to animation
	movement_system.movement_changed.connect(animation_manager._on_movement_changed)
	movement_system.mode_changed.connect(animation_manager._on_mode_changed)

func coordinate_physics_and_states():
	"""Coordinate physics with state systems"""
	# This will be expanded as we add more sophisticated coordination
	pass

# === MOVEMENT COMMAND HANDLING ===

func handle_movement_command(direction: Vector2, magnitude: float):
	"""Receive movement commands from ControlManager"""
	# Apply character type filtering
	var config = character_configs.get(current_character_type, {})
	if not config.get("allows_direct_control", true):
		print("🚫 CCC_CharacterManager: Movement blocked for character type: ", CharacterType.keys()[current_character_type])
		return
	
	# Apply responsiveness modification
	var responsiveness = config.get("movement_responsiveness", 1.0)
	if responsiveness < 1.0:
		magnitude = magnitude * responsiveness
	
	# Send to movement system
	if movement_system:
		movement_system.process_movement_input(direction, magnitude)
		coordinate_movement_response(direction, magnitude)

func handle_jump_command():
	"""Receive jump commands from ControlManager"""
	var config = character_configs.get(current_character_type, {})
	if not config.get("allows_direct_control", true):
		return
	
	if jump_system:
		jump_system.attempt_jump()

func handle_sprint_command(enabled: bool):
	"""Receive sprint commands from ControlManager"""
	if movement_system:
		movement_system.set_running(enabled)

func coordinate_movement_response(direction: Vector2, magnitude: float):
	"""Orchestrate character response to movement"""
	# Update animation
	if animation_manager:
		animation_manager.update_movement_blend(direction, magnitude)
	
	# Trigger state transitions
	if state_machine:
		state_machine.evaluate_movement_transitions(direction, magnitude)
	
	# Emit to other managers
	character_moved.emit(direction, movement_system.current_speed if movement_system else 0.0)

# === SIGNAL HANDLERS ===

func _on_movement_changed(is_moving: bool, direction: Vector2, speed: float):
	"""Handle movement changes from MovementSystem"""
	# Coordinate with other character systems
	coordinate_character_response(is_moving, direction, speed)

func _on_mode_changed(is_running: bool, is_slow_walking: bool):
	"""Handle mode changes from MovementSystem"""
	# Coordinate mode changes across character systems
	print("🏃 CCC_CharacterManager: Movement mode coordinated - Running:", is_running, " SlowWalk:", is_slow_walking)

func _on_jump_performed(force: float, is_air_jump: bool):
	"""Handle jump events from JumpSystem"""
	character_jumped.emit(force, is_air_jump)

func _on_state_changed(old_state: String, new_state: String):
	"""Handle state changes from StateMachine"""
	character_state_changed.emit(new_state)

func coordinate_character_response(is_moving: bool, direction: Vector2, speed: float):
	"""Coordinate character response to movement changes"""
	# Apply character type-specific behavior
	var config = character_configs.get(current_character_type, {})
	var responsiveness = config.get("movement_responsiveness", 1.0)
	
	if responsiveness < 1.0:
		# Reduce responsiveness for commander/observer types
		speed = speed * responsiveness
	
	# Enhanced animation coordination
	if animation_manager:
		coordinate_with_animation(is_moving, direction, speed)

func coordinate_with_animation(is_moving: bool, direction: Vector2, speed: float):
	"""Enhanced animation coordination"""
	# This could be expanded to provide more sophisticated animation control
	# For now, let the existing animation manager handle it
	pass

# === MOVEMENT SYSTEM PASSTHROUGH ===

func is_movement_active() -> bool:
	"""Check if movement is currently active"""
	if movement_system:
		return movement_system.is_movement_active
	return false

func is_running() -> bool:
	"""Check if character is running"""
	if movement_system:
		return movement_system.is_running
	return false

func is_slow_walking() -> bool:
	"""Check if character is slow walking"""
	if movement_system:
		return movement_system.is_slow_walking
	return false

func get_current_input_direction() -> Vector2:
	"""Get current input direction"""
	if movement_system:
		return movement_system.current_input_direction
	return Vector2.ZERO

func get_movement_speed() -> float:
	"""Get current movement speed"""
	if movement_system:
		return movement_system.current_speed
	return 0.0

# === CHARACTER TYPE MANAGEMENT ===

func set_character_type(character_type: CharacterType):
	"""Set character type and apply configuration"""
	var old_type = current_character_type
	current_character_type = character_type
	
	var config = character_configs.get(character_type, {})
	
	print("👤 CCC_CharacterManager: Character type changed from ", CharacterType.keys()[old_type], " to ", CharacterType.keys()[character_type])
	print("   → Direct control: ", config.get("allows_direct_control", true))
	print("   → Responsiveness: ", config.get("movement_responsiveness", 1.0))
	print("   → Embodiment: ", config.get("embodiment_quality", 1.0))

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get comprehensive debug information"""
	var debug_data = {
		"character_type": CharacterType.keys()[current_character_type],
		"movement_system_active": movement_system != null,
		"old_movement_manager": old_movement_manager != null,
		"systems_connected": {
			"jump": jump_system != null,
			"state_machine": state_machine != null,
			"animation": animation_manager != null
		}
	}
	
	if movement_system:
		debug_data.merge({
			"movement_active": movement_system.is_movement_active,
			"current_speed": movement_system.current_speed,
			"is_running": movement_system.is_running,
			"input_direction": movement_system.current_input_direction
		})
	
	return debug_data
