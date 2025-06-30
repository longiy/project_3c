# AvatarComponent.gd - Avatar character type behavior
extends Node
class_name AvatarComponent

# === SIGNALS ===
signal character_state_changed(state_name: String)
signal movement_mode_changed(mode_name: String)

# === EXPORTS ===
@export_group("Required References")
@export var character_core: CharacterCore
@export var config_component: Node  # 3CConfigComponent

@export_group("Avatar Properties")
@export var enable_state_tracking: bool = true
@export var enable_debug_output: bool = false

# === MOVEMENT MODES ===
enum MovementMode {
	DIRECT,      # WASD control
	NAVIGATION,  # Click-to-move
	HYBRID       # Both available
}

@export var movement_mode: MovementMode = MovementMode.HYBRID

# === CHARACTER STATES ===
enum CharacterState {
	IDLE,
	WALKING,
	RUNNING,
	JUMPING,
	AIRBORNE,
	LANDING
}

var current_state: CharacterState = CharacterState.IDLE
var previous_state: CharacterState = CharacterState.IDLE

# === STATE TRACKING ===
var current_speed: float = 0.0
var is_grounded: bool = true
var movement_input_active: bool = false

func _ready():
	validate_setup()
	connect_signals()
	
	if enable_debug_output:
		print("AvatarComponent: Initialized with movement mode: ", MovementMode.keys()[movement_mode])

func validate_setup():
	"""Validate required references"""
	if not character_core:
		push_error("AvatarComponent: character_core reference required")
	
	if not config_component:
		push_error("AvatarComponent: config_component reference required")

func connect_signals():
	"""Connect to character core signals"""
	if character_core:
		character_core.ground_state_changed.connect(_on_ground_state_changed)
		character_core.velocity_changed.connect(_on_velocity_changed)

func _process(_delta):
	if enable_state_tracking:
		update_character_state()

# === STATE MANAGEMENT ===

func update_character_state():
	"""Update character state based on current conditions"""
	var new_state = determine_character_state()
	
	if new_state != current_state:
		previous_state = current_state
		current_state = new_state
		
		character_state_changed.emit(get_state_name(current_state))
		
		if enable_debug_output:
			print("AvatarComponent: State changed from ", get_state_name(previous_state), " to ", get_state_name(current_state))

func determine_character_state() -> CharacterState:
	"""Determine current character state based on conditions"""
	if not is_grounded:
		if character_core.velocity.y > 0:
			return CharacterState.JUMPING
		else:
			return CharacterState.AIRBORNE
	
	if current_speed <= 0.1:
		return CharacterState.IDLE
	elif current_speed <= get_config_value("run_speed", 6.0) * 0.7:
		return CharacterState.WALKING
	else:
		return CharacterState.RUNNING

func get_state_name(state: CharacterState) -> String:
	"""Get string name for character state"""
	match state:
		CharacterState.IDLE:
			return "idle"
		CharacterState.WALKING:
			return "walking"
		CharacterState.RUNNING:
			return "running"
		CharacterState.JUMPING:
			return "jumping"
		CharacterState.AIRBORNE:
			return "airborne"
		CharacterState.LANDING:
			return "landing"
		_:
			return "unknown"

# === MOVEMENT MODE CONTROL ===

func set_movement_mode(new_mode: MovementMode):
	"""Change movement mode"""
	if new_mode != movement_mode:
		movement_mode = new_mode
		movement_mode_changed.emit(MovementMode.keys()[movement_mode])
		
		if enable_debug_output:
			print("AvatarComponent: Movement mode changed to ", MovementMode.keys()[movement_mode])

func can_use_direct_control() -> bool:
	"""Check if direct WASD control is available"""
	return movement_mode == MovementMode.DIRECT or movement_mode == MovementMode.HYBRID

func can_use_navigation() -> bool:
	"""Check if click navigation is available"""
	return movement_mode == MovementMode.NAVIGATION or movement_mode == MovementMode.HYBRID

# === SIGNAL HANDLERS ===

func _on_ground_state_changed(grounded: bool):
	"""Handle ground state changes"""
	is_grounded = grounded
	
	if enable_debug_output:
		print("AvatarComponent: Ground state changed to ", grounded)

func _on_velocity_changed(velocity: Vector3):
	"""Handle velocity changes"""
	current_speed = Vector2(velocity.x, velocity.z).length()

func _on_movement_input_changed(active: bool):
	"""Handle movement input state changes (called by input components)"""
	movement_input_active = active

# === PUBLIC API ===

func get_current_state() -> CharacterState:
	"""Get current character state"""
	return current_state

func get_current_state_name() -> String:
	"""Get current character state name"""
	return get_state_name(current_state)

func get_movement_mode() -> MovementMode:
	"""Get current movement mode"""
	return movement_mode

func is_moving() -> bool:
	"""Check if character is currently moving"""
	return current_speed > 0.1

func is_in_air() -> bool:
	"""Check if character is airborne"""
	return not is_grounded

# === CONFIGURATION ===

func get_config_value(property_name: String, default_value):
	"""Get configuration value safely"""
	if config_component and config_component.has_method("get_config_value"):
		return config_component.get_config_value(property_name, default_value)
	return default_value

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get debug information about avatar component"""
	return {
		"current_state": get_state_name(current_state),
		"previous_state": get_state_name(previous_state),
		"movement_mode": MovementMode.keys()[movement_mode],
		"current_speed": current_speed,
		"is_grounded": is_grounded,
		"movement_input_active": movement_input_active,
		"can_direct_control": can_use_direct_control(),
		"can_navigation": can_use_navigation()
	}