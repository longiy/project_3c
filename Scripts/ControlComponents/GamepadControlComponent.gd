# GamepadControlComponent.gd
# Gamepad/controller input for character control
# PHASE 2: Updated to reference InputCore directly

extends Node
class_name GamepadControlComponent

# Command signals
signal movement_command(direction: Vector2, magnitude: float)
signal look_command(delta: Vector2)
signal action_command(action: String, pressed: bool)

# Export references - UPDATED: Reference InputCore instead of InputPriorityManager
@export_group("References")
@export var input_core: InputCore
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
	# UPDATED: Register with InputCore directly
	if input_core:
		input_core.register_component(InputCore.InputType.GAMEPAD, self)

func _process(delta):
	check_gamepad_activity()
	
	if is_active or should_process_fallback():
		process_gamepad_input(delta)

func process_input(event: InputEvent):
	if not input_core:
		return
	
	# UPDATED: Check activity with InputCore
	is_active = input_core.is_input_active(InputCore.InputType.GAMEPAD)

func process_fallback_input(_event: InputEvent):
	# Gamepad processes in _process() not events
	pass

func check_gamepad_activity():
	var movement = get_movement_input()
	var look = get_look_input()
	
	if movement.length() > stick_deadzone or look.length() > stick_deadzone:
		# UPDATED: Set as active input if gamepad activity detected
		if input_core:
			input_core.set_active_input(InputCore.InputType.GAMEPAD)

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
		var look_delta = look * look_sensitivity * 0.016  # Simulate 60fps delta
		if invert_y:
			look_delta.y = -look_delta.y
		look_command.emit(look_delta)
	
	# Action buttons
	process_action_buttons()

func get_movement_input() -> Vector2:
	var movement = Vector2.ZERO
	movement.x = Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X)
	movement.y = Input.get_joy_axis(device_id, JOY_AXIS_LEFT_Y)
	
	# Apply deadzone
	if movement.length() < stick_deadzone:
		movement = Vector2.ZERO
	
	return movement

func get_look_input() -> Vector2:
	var look = Vector2.ZERO
	look.x = Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_X)
	look.y = Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_Y)
	
	# Apply deadzone
	if look.length() < stick_deadzone:
		look = Vector2.ZERO
	
	return look

func process_action_buttons():
	# Jump
	if Input.is_joy_button_pressed(device_id, jump_button):
		action_command.emit("jump", true)
	
	# Sprint
	if Input.is_joy_button_pressed(device_id, sprint_button):
		action_command.emit("sprint", true)
	
	# Walk
	if Input.is_joy_button_pressed(device_id, walk_button):
		action_command.emit("walk", true)

func should_process_fallback() -> bool:
	# Always process gamepad if connected
	return Input.get_connected_joypads().size() > 0

# Public API
func get_current_movement() -> Vector2:
	return current_movement

func get_is_active() -> bool:
	return is_active

func get_device_id() -> int:
	return device_id

func set_device_id(new_device_id: int):
	device_id = new_device_id

func get_connected_devices() -> Array:
	return Input.get_connected_joypads()
