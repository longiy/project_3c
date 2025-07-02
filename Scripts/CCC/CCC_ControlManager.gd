# CCC_ControlManager.gd - Control axis wrapper for 3C architecture
extends Node
class_name CCC_ControlManager

# === WRAPPED COMPONENT ===
@export var input_manager: InputManager

# === SIGNALS (Passthrough from InputManager) ===
signal movement_started(direction: Vector2, magnitude: float)
signal movement_updated(direction: Vector2, magnitude: float)
signal movement_stopped()
signal jump_pressed()
signal sprint_started()
signal sprint_stopped()
signal slow_walk_started()
signal slow_walk_stopped()
signal reset_pressed()
signal click_navigation(world_position: Vector3)

# === 3C CONTROL CONFIGURATION (Empty for now) ===
enum ControlType {
	DIRECT,        # WASD/Gamepad direct control
	TARGET_BASED,  # Click-to-move
	HYBRID,        # Both WASD and click
	GESTURAL       # Pattern-based input (future)
}

var current_control_type: ControlType = ControlType.HYBRID

func _ready():
	setup_input_manager()
	connect_input_signals()
	print("✅ CCC_ControlManager: Initialized as wrapper")

func setup_input_manager():
	"""Find and reference InputManager"""
	if not input_manager:
		input_manager = get_node_or_null("InputManager")
	
	if not input_manager:
		# Try finding it as a sibling
		input_manager = get_parent().get_node_or_null("InputManager")
	
	if not input_manager:
		push_error("CCC_ControlManager: No InputManager found!")
		return

func connect_input_signals():
	"""Connect InputManager signals to our passthrough signals"""
	if not input_manager:
		return
	
	# Connect all input signals through wrapper
	input_manager.movement_started.connect(_on_movement_started)
	input_manager.movement_updated.connect(_on_movement_updated)
	input_manager.movement_stopped.connect(_on_movement_stopped)
	input_manager.jump_pressed.connect(_on_jump_pressed)
	input_manager.sprint_started.connect(_on_sprint_started)
	input_manager.sprint_stopped.connect(_on_sprint_stopped)
	input_manager.slow_walk_started.connect(_on_slow_walk_started)
	input_manager.slow_walk_stopped.connect(_on_slow_walk_stopped)
	input_manager.reset_pressed.connect(_on_reset_pressed)
	input_manager.click_navigation.connect(_on_click_navigation)

# === SIGNAL PASSTHROUGH HANDLERS ===

func _on_movement_started(direction: Vector2, magnitude: float):
	movement_started.emit(direction, magnitude)

func _on_movement_updated(direction: Vector2, magnitude: float):
	movement_updated.emit(direction, magnitude)

func _on_movement_stopped():
	movement_stopped.emit()

func _on_jump_pressed():
	jump_pressed.emit()

func _on_sprint_started():
	sprint_started.emit()

func _on_sprint_stopped():
	sprint_stopped.emit()

func _on_slow_walk_started():
	slow_walk_started.emit()

func _on_slow_walk_stopped():
	slow_walk_stopped.emit()

func _on_reset_pressed():
	reset_pressed.emit()

func _on_click_navigation(world_position: Vector3):
	click_navigation.emit(world_position)

# === PASSTHROUGH METHODS (No logic duplication) ===

func get_current_input_direction() -> Vector2:
	"""Get current input direction from InputManager"""
	if input_manager:
		return input_manager.get_current_input_direction()
	return Vector2.ZERO

func is_movement_active() -> bool:
	"""Check if movement is currently active"""
	if input_manager:
		return input_manager.is_movement_active()
	return false

func get_movement_duration() -> float:
	"""Get how long movement has been active"""
	if input_manager:
		return input_manager.get_movement_duration()
	return 0.0

func cancel_all_input_components():
	"""Cancel all input components"""
	if input_manager:
		input_manager.cancel_all_input_components()

# === 3C CONTROL INTERFACE (Stubbed for future implementation) ===

func configure_control_type(control_type: ControlType):
	"""Configure the control scheme (future implementation)"""
	current_control_type = control_type
	# TODO: Implement when adding 3C configuration system
	print("🎮 CCC_ControlManager: Control type set to ", ControlType.keys()[control_type])

func set_control_sensitivity(sensitivity: float):
	"""Set control sensitivity (future implementation)"""
	# TODO: Implement when adding 3C configuration system
	pass

func enable_input_buffering(enabled: bool):
	"""Enable/disable input buffering (future implementation)"""
	# TODO: Implement when adding 3C configuration system
	pass

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get debug information including InputManager data"""
	var debug_data = {
		"control_type": ControlType.keys()[current_control_type],
		"wrapper_status": "active"
	}
	
	if input_manager:
		debug_data.merge(input_manager.get_debug_info())
	else:
		debug_data["input_manager"] = "missing"
	
	return debug_data
