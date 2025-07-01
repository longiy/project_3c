class_name CCC_GamepadInput
extends Node

@export_group("Gamepad Settings")
@export var device_id: int = 0
@export var movement_deadzone: float = 0.2
@export var use_left_stick: bool = true

@export_group("Input Actions")
@export var jump_button: String = "gamepad_a"
@export var run_button: String = "gamepad_trigger_left"

var current_movement_input: Vector2 = Vector2.ZERO
var is_active_flag: bool = true
var gamepad_connected: bool = false

signal action_triggered(action: String)
signal movement_changed(direction: Vector2)
signal gamepad_connection_changed(connected: bool)

func _ready():
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	check_gamepad_connection()

func _process(_delta):
	if not is_active_flag or not gamepad_connected:
		if current_movement_input != Vector2.ZERO:
			current_movement_input = Vector2.ZERO
			movement_changed.emit(current_movement_input)
		return
	
	var new_input = get_movement_input()
	
	if new_input != current_movement_input:
		current_movement_input = new_input
		movement_changed.emit(current_movement_input)

func _input(event):
	if not is_active_flag or not gamepad_connected:
		return
	
	if event is InputEventJoypadButton and event.device == device_id:
		if event.pressed:
			match event.button_index:
				JOY_BUTTON_A:
					action_triggered.emit("jump")
				JOY_BUTTON_LEFT_SHOULDER:
					action_triggered.emit("run_start")
		else:
			match event.button_index:
				JOY_BUTTON_A:
					action_triggered.emit("jump_release")
				JOY_BUTTON_LEFT_SHOULDER:
					action_triggered.emit("run_end")

func get_movement_input() -> Vector2:
	if not is_active_flag or not gamepad_connected:
		return Vector2.ZERO
	
	var stick_input = Vector2.ZERO
	
	if use_left_stick:
		stick_input.x = Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X)
		stick_input.y = Input.get_joy_axis(device_id, JOY_AXIS_LEFT_Y)
	else:
		stick_input.x = Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_X)
		stick_input.y = Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_Y)
	
	# Apply deadzone
	if stick_input.length() < movement_deadzone:
		return Vector2.ZERO
	
	# Normalize and reapply magnitude outside deadzone
	var magnitude = stick_input.length()
	var normalized = stick_input.normalized()
	var adjusted_magnitude = (magnitude - movement_deadzone) / (1.0 - movement_deadzone)
	
	return normalized * adjusted_magnitude

func is_active() -> bool:
	return is_active_flag and gamepad_connected

func set_active(active: bool):
	is_active_flag = active
	
	if not active:
		current_movement_input = Vector2.ZERO
		movement_changed.emit(current_movement_input)

func cancel_input():
	# Gamepad input doesn't need cancellation - it's immediate
	pass

func check_gamepad_connection():
	var connected = Input.get_connected_joypads().has(device_id)
	if connected != gamepad_connected:
		gamepad_connected = connected
		gamepad_connection_changed.emit(gamepad_connected)

func _on_joy_connection_changed(device: int, connected: bool):
	if device == device_id:
		gamepad_connected = connected
		gamepad_connection_changed.emit(gamepad_connected)
		
		if not connected and current_movement_input != Vector2.ZERO:
			current_movement_input = Vector2.ZERO
			movement_changed.emit(current_movement_input)

func get_gamepad_name() -> String:
	if gamepad_connected:
		return Input.get_joy_name(device_id)
	return "No gamepad"

func get_debug_info() -> Dictionary:
	return {
		"gamepad_active": is_active_flag,
		"gamepad_connected": gamepad_connected,
		"gamepad_device_id": device_id,
		"gamepad_name": get_gamepad_name(),
		"gamepad_movement": current_movement_input,
		"gamepad_raw_left_x": Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X) if gamepad_connected else 0.0,
		"gamepad_raw_left_y": Input.get_joy_axis(device_id, JOY_AXIS_LEFT_Y) if gamepad_connected else 0.0
	}