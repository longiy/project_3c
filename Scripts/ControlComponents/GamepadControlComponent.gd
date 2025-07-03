# GamepadControlComponent.gd
# Gamepad input handling
# Simple fix: Replace InputPriorityManager with InputCore

extends Node
class_name GamepadControlComponent

# Signals
signal movement_command(direction: Vector3)
signal look_command(look_delta: Vector2)
signal action_command(action: String, pressed: bool)

# Export references - CHANGED: InputPriorityManager → InputCore
@export_group("References")
@export var input_core: InputCore

@export_group("Gamepad Settings")
@export var device_id: int = 0
@export var movement_sensitivity: float = 1.0
@export var look_sensitivity: float = 2.0
@export var stick_deadzone: float = 0.2
@export var invert_y: bool = false

@export_group("Button Mapping")
@export var jump_button: JoyButton = JOY_BUTTON_A
@export var sprint_button: JoyButton = JOY_BUTTON_X

# Internal state
var is_active: bool = false
var current_movement: Vector2 = Vector2.ZERO

func _ready():
	# Register with InputCore - CHANGED: input_priority_manager → input_core
	if input_core:
		input_core.register_component(InputCore.InputType.GAMEPAD, self)

func _process(delta):
	if not is_active:
		return
	
	process_movement_input()
	process_look_input()

func process_input(event: InputEvent):
	if not is_active:
		return
	
	if event is InputEventJoypadButton:
		process_button_inputs()
	elif event is InputEventJoypadMotion:
		# Movement and look are handled in _process
		pass

func process_movement_input():
	var movement = get_movement_input()
	
	if movement.length() > stick_deadzone:
		var movement_3d = Vector3(movement.x, 0, movement.y) * movement_sensitivity
		movement_command.emit(movement_3d)
	else:
		movement_command.emit(Vector3.ZERO)

func process_look_input():
	var look = get_look_input()
	
	if look.length() > stick_deadzone:
		var look_delta = look * look_sensitivity
		if invert_y:
			look_delta.y = -look_delta.y
		look_command.emit(look_delta)

func get_movement_input() -> Vector2:
	return Vector2(
		Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(device_id, JOY_AXIS_LEFT_Y)
	)

func get_look_input() -> Vector2:
	return Vector2(
		Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_Y)
	)

func process_button_inputs():
	if Input.is_joy_button_pressed(device_id, jump_button):
		action_command.emit("jump", true)
	
	if Input.is_joy_button_pressed(device_id, sprint_button):
		action_command.emit("sprint", true)

func should_process_fallback() -> bool:
	# CHANGED: input_priority_manager → input_core
	return not is_active and input_core and \
		   input_core.get_active_input_type() != InputCore.InputType.GAMEPAD

# Public API
func get_current_movement() -> Vector2:
	return current_movement

func get_is_active() -> bool:
	return is_active
