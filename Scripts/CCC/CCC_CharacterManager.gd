# CCC_CharacterManager.gd - Character axis wrapper for 3C architecture
extends Node
class_name CCC_CharacterManager

# === WRAPPED COMPONENTS ===
@export var movement_manager: MovementManager
@export var character_body: CharacterBody3D

# === SIGNALS (Passthrough from MovementManager) ===
signal movement_changed(is_moving: bool, direction: Vector2, speed: float)
signal mode_changed(is_running: bool, is_slow_walking: bool)

# === 3C CHARACTER CONFIGURATION (Empty for now) ===
enum CharacterType {
	AVATAR,        # Direct character control (current implementation)
	OBSERVER,      # Watch-only, no direct control
	COMMANDER,     # Control multiple units/characters
	COLLABORATOR   # Shared control with AI/other players
}

var current_character_type: CharacterType = CharacterType.AVATAR

func _ready():
	setup_components()
	connect_movement_signals()
	print("✅ CCC_CharacterManager: Initialized as wrapper")

func setup_components():
	"""Find and reference wrapped components"""
	if not movement_manager:
		movement_manager = get_node_or_null("MovementManager")
	
	if not movement_manager:
		# Try finding it as a sibling
		movement_manager = get_parent().get_node_or_null("MovementManager")
	
	if not character_body:
		character_body = get_parent() as CharacterBody3D
	
	if not movement_manager:
		push_error("CCC_CharacterManager: No MovementManager found!")
		return
	
	if not character_body:
		push_error("CCC_CharacterManager: No CharacterBody3D found!")
		return

func connect_movement_signals():
	"""Connect MovementManager signals to our passthrough signals"""
	if not movement_manager:
		return
	
	# Connect movement signals through wrapper
	movement_manager.movement_changed.connect(_on_movement_changed)
	movement_manager.mode_changed.connect(_on_mode_changed)

# === SIGNAL PASSTHROUGH HANDLERS ===

func _on_movement_changed(is_moving: bool, direction: Vector2, speed: float):
	movement_changed.emit(is_moving, direction, speed)

func _on_mode_changed(is_running: bool, is_slow_walking: bool):
	mode_changed.emit(is_running, is_slow_walking)

# === MOVEMENT PASSTHROUGH METHODS (No logic duplication) ===

func handle_movement_action(action: String, context: Dictionary = {}):
	"""Handle movement actions through MovementManager"""
	if movement_manager:
		movement_manager.handle_movement_action(action, context)

func handle_mode_action(action: String):
	"""Handle movement mode actions through MovementManager"""
	if movement_manager:
		movement_manager.handle_mode_action(action)

func apply_ground_movement(delta: float):
	"""Apply ground movement through MovementManager"""
	if movement_manager:
		movement_manager.apply_ground_movement(delta)

func apply_air_movement(delta: float):
	"""Apply air movement through MovementManager"""
	if movement_manager:
		movement_manager.apply_air_movement(delta)

func get_movement_speed() -> float:
	"""Get current movement speed"""
	if movement_manager:
		return movement_manager.get_movement_speed()
	return 0.0

func get_target_speed() -> float:
	"""Get target movement speed"""
	if movement_manager:
		return movement_manager.get_target_speed()
	return 0.0

# === CHARACTER STATE PROPERTIES (Passthrough) ===

func is_movement_active() -> bool:
	"""Check if character is actively moving"""
	if movement_manager:
		return movement_manager.is_movement_active
	return false

func is_running() -> bool:
	"""Check if character is running"""
	if movement_manager:
		return movement_manager.is_running
	return false

func is_slow_walking() -> bool:
	"""Check if character is slow walking"""
	if movement_manager:
		return movement_manager.is_slow_walking
	return false

func get_current_input_direction() -> Vector2:
	"""Get current input direction"""
	if movement_manager:
		return movement_manager.current_input_direction
	return Vector2.ZERO

# === PHYSICS PASSTHROUGH ===

func get_velocity() -> Vector3:
	"""Get character velocity"""
	if character_body:
		return character_body.velocity
	return Vector3.ZERO

func set_velocity(velocity: Vector3):
	"""Set character velocity"""
	if character_body:
		character_body.velocity = velocity

func is_on_floor() -> bool:
	"""Check if character is on floor"""
	if character_body:
		return character_body.is_on_floor()
	return false

func get_position() -> Vector3:
	"""Get character position"""
	if character_body:
		return character_body.global_position
	return Vector3.ZERO

func set_position(position: Vector3):
	"""Set character position"""
	if character_body:
		character_body.global_position = position

# === 3C CHARACTER INTERFACE (Stubbed for future implementation) ===

func configure_character_type(character_type: CharacterType):
	"""Configure the character type (future implementation)"""
	current_character_type = character_type
	# TODO: Implement when adding 3C configuration system
	print("👤 CCC_CharacterManager: Character type set to ", CharacterType.keys()[character_type])

func set_embodiment_quality(quality: float):
	"""Set how much the player feels 'present' in the character (future implementation)"""
	# TODO: Implement when adding 3C configuration system
	pass

func set_responsiveness(responsiveness: float):
	"""Set character responsiveness to input (future implementation)"""
	# TODO: Implement when adding 3C configuration system
	pass

func enable_ai_assistance(enabled: bool):
	"""Enable AI assistance for movement (future implementation)"""
	# TODO: Implement when adding 3C configuration system
	pass

# === CAMERA REFERENCE SETUP ===

func setup_camera_reference(camera: Camera3D):
	"""Setup camera reference for movement calculations"""
	if movement_manager:
		movement_manager.setup_camera_reference(camera)

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get debug information including MovementManager data"""
	var debug_data = {
		"character_type": CharacterType.keys()[current_character_type],
		"wrapper_status": "active",
		"position": get_position(),
		"velocity": get_velocity(),
		"is_on_floor": is_on_floor()
	}
	
	if movement_manager:
		debug_data["movement"] = {
			"is_active": is_movement_active(),
			"is_running": is_running(),
			"is_slow_walking": is_slow_walking(),
			"speed": get_movement_speed(),
			"target_speed": get_target_speed(),
			"input_direction": get_current_input_direction()
		}
	else:
		debug_data["movement_manager"] = "missing"
	
	return debug_data
