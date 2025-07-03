# GamepadControlComponent.gd
# Gamepad/controller input for character control
# Refactored: Export references, cleaned up

extends Node
class_name GamepadControlComponent

# Command signals
signal movement_command(direction: Vector2, magnitude: float)
signal look_command(delta: Vector2)
signal action_command(action: String, pressed: bool)

# Export references
@export_group("References")
@export var input_priority_manager: InputPriorityManager
@export var camera_system: CameraSystem

@export_group("Gamepad Settings")
@export var stick_deadzone: float = 0.2
@export var trigger_deadzone: float = 0.1
@export var look_sensitivity: float = 2.0
@export var invert_y: bool = false
@export var device_id: int = 0

@export_group("Input Mapping")
@export var jump_button: JoyButton = JOY_BUTTON_A
@export var sprint_button: JoyButton = JOY_BUTTON_X
@export var walk_button: JoyButton = JOY_BUTTON_B

# Internal state
var is_active: bool = false
var current_movement: Vector2 = Vector2.ZERO

func _ready():
	if input_priority_manager:
		input_priority_manager.register_component(InputPriorityManager.InputType.GAMEPAD, self)

func _process(delta):
	check_gamepad_activity()
	
	if is_active or should_process_fallback():
		process_gamepad_input(delta)

func process_input(event: InputEvent):
	if not input_priority_manager:
		return
	
	is_active = input_priority_manager.is_input_active(InputPriorityManager.InputType.GAMEPAD)

func process_fallback_input(_event: InputEvent):
	# Gamepad processes in _process() not events
	pass

func check_gamepad_activity():
	var movement = get_movement_input()
	var look = get_look_input()
	
	if movement.length() > stick_deadzone or look.length() > stick_deadzone:
		if input_priority_manager:
			input_priority_manager.set_active_input(InputPriorityManager.InputType.GAMEPAD)

func process_gamepad_input(_delta: float):
	# Movement
	var movement = get_movement_input()
	if movement.length() > stick_deadzone:
		current_movement = movement.normalized()
		movement_command.emit(current_movement, movement.length())
	else:
		current_movement = Vector2.ZERO
	
	# Look
	var look = get_look_input()
	if look.length() > stick_deadzone:
		var look_delta = look * look_sensitivity
		if invert_y:
			look_delta.y = -look_delta.y
		look_command.emit(look_delta)
	
	# Buttons
	process_button_inputs()

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
	return not is_active and input_priority_manager and \
		   input_priority_manager.get_active_input_type() != InputPriorityManager.InputType.GAMEPAD

# Public API
func get_current_movement() -> Vector2:
	return current_movement

func get_is_active() -> bool:
	return is_active
