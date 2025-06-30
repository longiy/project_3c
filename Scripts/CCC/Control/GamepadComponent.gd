# GamepadComponent.gd - Enhanced gamepad input with priority system integration
extends Node
class_name GamepadComponent

# === SETTINGS ===
@export_group("Gamepad Settings")
@export var gamepad_device = 0
@export var deadzone = 0.2
@export var outer_deadzone = 0.95
@export var enable_gamepad = true

@export_group("Input Mapping")
@export var movement_actions = ["gamepad_left", "gamepad_right", "gamepad_up", "gamepad_down"]
@export var use_left_stick = true
@export var use_right_stick = false

@export_group("Response Curve")
@export var use_response_curve = true
@export var curve_exponent = 2.0
@export var sensitivity = 1.0

# === STATE ===
var current_input = Vector2.ZERO
var processed_input = Vector2.ZERO
var is_gamepad_connected = false
var is_input_active = false

# Component reference
var character: CharacterBody3D

func _ready():
	character = get_parent() as CharacterBody3D
	if not character:
		push_error("GamepadComponent must be child of CharacterBody3D")
		return
	
	check_gamepad_connection()
	print("✅ GamepadComponent: Ready for gamepad input processing")

func _physics_process(delta):
	if enable_gamepad:
		check_gamepad_connection()
		process_gamepad_input(delta)

func check_gamepad_connection():
	"""Check if gamepad is connected"""
	var connected_joypads = Input.get_connected_joypads()
	is_gamepad_connected = gamepad_device in connected_joypads

func process_gamepad_input(delta: float):
	"""Process gamepad movement input"""
	if not is_gamepad_connected:
		current_input = Vector2.ZERO
		processed_input = Vector2.ZERO
		is_input_active = false
		return
	
	# Get stick input
	var stick_input = get_stick_input()
	current_input = stick_input
	
	# Apply deadzone
	var magnitude = stick_input.length()
	if magnitude < deadzone:
		processed_input = Vector2.ZERO
	elif magnitude > outer_deadzone:
		processed_input = stick_input.normalized()
	else:
		# Apply response curve
		if use_response_curve:
			var normalized_magnitude = (magnitude - deadzone) / (outer_deadzone - deadzone)
			var curved_magnitude = pow(normalized_magnitude, curve_exponent)
			processed_input = stick_input.normalized() * curved_magnitude * sensitivity
		else:
			processed_input = stick_input * sensitivity
	
	# Update active state
	is_input_active = processed_input.length() > deadzone

func get_stick_input() -> Vector2:
	"""Get analog stick input based on configuration"""
	if use_left_stick:
		return Vector2(
			Input.get_joy_axis(gamepad_device, JOY_AXIS_LEFT_X),
			Input.get_joy_axis(gamepad_device, JOY_AXIS_LEFT_Y)
		)
	elif use_right_stick:
		return Vector2(
			Input.get_joy_axis(gamepad_device, JOY_AXIS_RIGHT_X),
			Input.get_joy_axis(gamepad_device, JOY_AXIS_RIGHT_Y)
		)
	else:
		# Fallback to action-based input
		return Input.get_vector(
			movement_actions[0], movement_actions[1], 
			movement_actions[2], movement_actions[3]
		)

# === PUBLIC INTERFACE (Required by InputPriorityManager) ===

func is_active() -> bool:
	"""Check if gamepad is providing movement input"""
	return enable_gamepad and is_gamepad_connected and is_input_active

func get_movement_input() -> Vector2:
	"""Get processed gamepad movement input"""
	if not enable_gamepad or not is_gamepad_connected:
		return Vector2.ZERO
	
	return processed_input

func cancel_input():
	"""Cancel gamepad input (clear state)"""
	current_input = Vector2.ZERO
	processed_input = Vector2.ZERO
	is_input_active = false

func get_input_type() -> String:
	"""Return input type for classification"""
	return "gamepad_analog"

# === CONFIGURATION ===

func set_deadzone(inner: float, outer: float = 0.95):
	"""Update deadzone settings"""
	deadzone = inner
	outer_deadzone = outer

func set_response_curve(enabled: bool, exponent: float = 2.0):
	"""Configure response curve"""
	use_response_curve = enabled
	curve_exponent = exponent

func set_sensitivity(sens: float):
	"""Update input sensitivity"""
	sensitivity = sens

func set_gamepad_device(device: int):
	"""Change gamepad device"""
	gamepad_device = device
	check_gamepad_connection()

func enable_input(enabled: bool):
	"""Enable/disable gamepad input"""
	enable_gamepad = enabled
	if not enabled:
		cancel_input()

# === ADVANCED FEATURES ===

func get_raw_stick_input() -> Vector2:
	"""Get unprocessed stick input"""
	return get_stick_input()

func get_input_strength() -> float:
	"""Get input strength (0.0 to 1.0)"""
	return processed_input.length()

func get_input_direction() -> Vector2:
	"""Get normalized input direction"""
	return processed_input.normalized() if processed_input.length() > 0 else Vector2.ZERO

func is_gamepad_available() -> bool:
	"""Check if gamepad is connected and available"""
	return is_gamepad_connected

func get_gamepad_name() -> String:
	"""Get connected gamepad name"""
	if is_gamepad_connected:
		return Input.get_joy_name(gamepad_device)
	return "No gamepad connected"

# === GAMEPAD-SPECIFIC ACTIONS ===

func is_button_pressed(button: JoyButton) -> bool:
	"""Check if gamepad button is pressed"""
	if not is_gamepad_connected:
		return false
	return Input.is_joy_button_pressed(gamepad_device, button)

func get_trigger_value(trigger: JoyAxis) -> float:
	"""Get trigger pressure value"""
	if not is_gamepad_connected:
		return 0.0
	return Input.get_joy_axis(gamepad_device, trigger)

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get gamepad debug information"""
	return {
		"enabled": enable_gamepad,
		"gamepad_connected": is_gamepad_connected,
		"gamepad_device": gamepad_device,
		"gamepad_name": get_gamepad_name(),
		"is_active": is_active(),
		"raw_input": get_raw_stick_input(),
		"current_input": current_input,
		"processed_input": processed_input,
		"input_strength": get_input_strength(),
		"input_direction": get_input_direction(),
		"deadzone": deadzone,
		"outer_deadzone": outer_deadzone,
		"response_curve": use_response_curve,
		"curve_exponent": curve_exponent,
		"sensitivity": sensitivity,
		"using_left_stick": use_left_stick,
		"using_right_stick": use_right_stick
	}
