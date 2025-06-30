# DirectControlComponent.gd - Direct WASD control handling
extends Node
class_name DirectControlComponent

# === SIGNALS ===
signal movement_input_received(direction: Vector2, magnitude: float)
signal jump_input_received()
signal sprint_input_received(active: bool)

# === EXPORTS ===
@export_group("Required References")
@export var movement_component: Node  # DirectMovementComponent
@export var config_component: Node  # 3CConfigComponent

@export_group("Control Properties")
@export var enable_input_smoothing: bool = false
@export var enable_debug_output: bool = false

# === INPUT STATE ===
var current_input: Vector2 = Vector2.ZERO
var raw_input: Vector2 = Vector2.ZERO
var sprint_active: bool = false
var input_magnitude: float = 0.0

func _ready():
	validate_setup()
	
	if enable_debug_output:
		print("DirectControlComponent: Initialized")

func validate_setup():
	"""Validate required references"""
	if not movement_component:
		push_error("DirectControlComponent: movement_component reference required")
	
	if not config_component:
		push_error("DirectControlComponent: config_component reference required")

func _process(delta):
	"""Process continuous input"""
	process_movement_input(delta)
	process_action_input()

# === INPUT PROCESSING ===

func process_movement_input(delta: float):
	"""Process WASD movement input"""
	# Get raw input
	raw_input = Vector2.ZERO
	
	if Input.is_action_pressed("move_forward"):
		raw_input.y += 1.0
	if Input.is_action_pressed("move_backward"):
		raw_input.y -= 1.0
	if Input.is_action_pressed("move_left"):
		raw_input.x -= 1.0
	if Input.is_action_pressed("move_right"):
		raw_input.x += 1.0
	
	# Apply deadzone
	var deadzone = get_config_value("input_deadzone", 0.1)
	if raw_input.length() < deadzone:
		raw_input = Vector2.ZERO
	
	# Apply input smoothing if enabled
	if enable_input_smoothing and raw_input.length() > 0:
		var smoothing_speed = get_config_value("input_smoothing", 0.0)
		if smoothing_speed > 0:
			current_input = current_input.lerp(raw_input.normalized(), smoothing_speed * delta)
		else:
			current_input = raw_input.normalized()
	else:
		current_input = raw_input.normalized() if raw_input.length() > 0 else Vector2.ZERO
	
	# Calculate input magnitude for speed control
	input_magnitude = raw_input.length()
	
	# Send to movement component
	if movement_component and movement_component.has_method("handle_movement_input"):
		movement_component.handle_movement_input(current_input)
	
	# Emit signal for other components
	if current_input.length() > 0:
		movement_input_received.emit(current_input, input_magnitude)

func process_action_input():
	"""Process action inputs like jump and sprint"""
	# Jump input
	if Input.is_action_just_pressed("jump"):
		if movement_component and movement_component.has_method("handle_jump_input"):
			movement_component.handle_jump_input()
		
		jump_input_received.emit()
		
		if enable_debug_output:
			print("DirectControlComponent: Jump input processed")
	
	# Sprint input
	var new_sprint_state = Input.is_action_pressed("sprint")
	if new_sprint_state != sprint_active:
		sprint_active = new_sprint_state
		sprint_input_received.emit(sprint_active)
		
		if enable_debug_output:
			print("DirectControlComponent: Sprint ", "activated" if sprint_active else "deactivated")

# === INPUT HANDLING METHOD (for InputManager) ===

func handle_input(event: InputEvent):
	"""Handle input events routed from InputManager"""
	# This method is called by InputManagerComponent
	# Most WASD input is handled in _process, but special events can be handled here
	
	if event.is_action_pressed("toggle_camera_mode"):
		# Handle camera mode toggle if needed
		if enable_debug_output:
			print("DirectControlComponent: Camera toggle received")
	
	# Handle gamepad input if needed
	if event is InputEventJoypadMotion:
		handle_gamepad_input(event)

func handle_gamepad_input(event: InputEventJoypadMotion):
	"""Handle gamepad stick input"""
	# Left stick for movement
	if event.axis == JOY_AXIS_LEFT_X or event.axis == JOY_AXIS_LEFT_Y:
		var stick_input = Vector2(
			Input.get_joy_axis(0, JOY_AXIS_LEFT_X),
			-Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)  # Invert Y for forward movement
		)
		
		# Apply deadzone
		var deadzone = get_config_value("input_deadzone", 0.1)
		if stick_input.length() < deadzone:
			stick_input = Vector2.ZERO
		
		# Send to movement component
		if movement_component and movement_component.has_method("handle_movement_input"):
			movement_component.handle_movement_input(stick_input)
		
		if enable_debug_output and stick_input.length() > 0:
			print("DirectControlComponent: Gamepad movement input: ", stick_input)

# === INPUT MODIFIERS ===

func set_input_sensitivity(sensitivity: float):
	"""Set input sensitivity multiplier"""
	# Could modify input processing here
	if enable_debug_output:
		print("DirectControlComponent: Input sensitivity set to ", sensitivity)

func enable_sprint_modifier(enabled: bool):
	"""Enable/disable sprint input processing"""
	if not enabled:
		sprint_active = false
		sprint_input_received.emit(false)

# === PUBLIC API ===

func get_current_input() -> Vector2:
	"""Get current processed input direction"""
	return current_input

func get_raw_input() -> Vector2:
	"""Get raw unprocessed input"""
	return raw_input

func get_input_magnitude() -> float:
	"""Get input magnitude for speed calculations"""
	return input_magnitude

func is_sprint_active() -> bool:
	"""Check if sprint is currently active"""
	return sprint_active

func is_movement_input_active() -> bool:
	"""Check if any movement input is active"""
	return current_input.length() > 0

func clear_input():
	"""Clear all input (for cutscenes, etc.)"""
	current_input = Vector2.ZERO
	raw_input = Vector2.ZERO
	input_magnitude = 0.0
	sprint_active = false

# === CONFIGURATION ===

func get_config_value(property_name: String, default_value):
	"""Get configuration value safely"""
	if config_component and config_component.has_method("get_config_value"):
		return config_component.get_config_value(property_name, default_value)
	return default_value

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get debug information about direct control component"""
	return {
		"current_input": current_input,
		"raw_input": raw_input,
		"input_magnitude": input_magnitude,
		"sprint_active": sprint_active,
		"input_smoothing": enable_input_smoothing,
		"movement_active": is_movement_input_active(),
		"deadzone": get_config_value("input_deadzone", 0.1)
	}
