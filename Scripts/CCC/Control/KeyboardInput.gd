# KeyboardInput.gd - Specialized keyboard input component
extends Node
class_name KeyboardInput

# === SETTINGS ===
@export_group("Keyboard Settings")
@export var input_deadzone = 0.05
@export var enable_keyboard = true
@export var smoothing_enabled = false
@export var smoothing_speed = 8.0

# === STATE ===
var current_input = Vector2.ZERO
var smoothed_input = Vector2.ZERO
var is_input_active = false

# Component reference
var character: CharacterBody3D

func _ready():
	character = get_parent() as CharacterBody3D
	if not character:
		push_error("KeyboardInput must be child of CharacterBody3D")
		return
	
	print("✅ KeyboardInput: Ready for WASD input processing")

func _physics_process(delta):
	if enable_keyboard:
		process_keyboard_input(delta)

func process_keyboard_input(delta: float):
	"""Process WASD keyboard input"""
	# Get raw input
	var raw_input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var magnitude = raw_input.length()
	
	# Apply deadzone
	current_input = raw_input if magnitude > input_deadzone else Vector2.ZERO
	
	# Apply smoothing if enabled
	if smoothing_enabled:
		smoothed_input = smoothed_input.lerp(current_input, smoothing_speed * delta)
	else:
		smoothed_input = current_input
	
	# Update active state
	is_input_active = smoothed_input.length() > input_deadzone

# === PUBLIC INTERFACE (Required by InputPriorityManager) ===

func is_active() -> bool:
	"""Check if keyboard input is providing movement"""
	return enable_keyboard and is_input_active

func get_movement_input() -> Vector2:
	"""Get processed keyboard movement input"""
	if not enable_keyboard:
		return Vector2.ZERO
	
	return smoothed_input

func cancel_input():
	"""Cancel keyboard input (clear state)"""
	current_input = Vector2.ZERO
	smoothed_input = Vector2.ZERO
	is_input_active = false

func get_input_type() -> String:
	"""Return input type for classification"""
	return "keyboard_wasd"

# === CONFIGURATION ===

func set_deadzone(deadzone: float):
	"""Update input deadzone"""
	input_deadzone = deadzone

func set_smoothing(enabled: bool, speed: float = 8.0):
	"""Configure input smoothing"""
	smoothing_enabled = enabled
	smoothing_speed = speed

func enable_input(enabled: bool):
	"""Enable/disable keyboard input"""
	enable_keyboard = enabled
	if not enabled:
		cancel_input()

# === ADVANCED FEATURES ===

func get_raw_input() -> Vector2:
	"""Get unprocessed raw input"""
	if not enable_keyboard:
		return Vector2.ZERO
	
	return Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

func get_input_strength() -> float:
	"""Get input strength (0.0 to 1.0)"""
	return smoothed_input.length()

func get_input_direction() -> Vector2:
	"""Get normalized input direction"""
	return smoothed_input.normalized() if smoothed_input.length() > 0 else Vector2.ZERO

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get keyboard input debug information"""
	return {
		"enabled": enable_keyboard,
		"is_active": is_active(),
		"raw_input": get_raw_input(),
		"current_input": current_input,
		"smoothed_input": smoothed_input,
		"input_strength": get_input_strength(),
		"input_direction": get_input_direction(),
		"deadzone": input_deadzone,
		"smoothing_enabled": smoothing_enabled,
		"smoothing_speed": smoothing_speed
	}
