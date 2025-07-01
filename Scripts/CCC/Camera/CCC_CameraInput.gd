class_name CCC_CameraInput
extends Node

@export_group("Camera Input Settings")
@export var mouse_sensitivity: float = 0.003
@export var gamepad_sensitivity: float = 2.0
@export var invert_y: bool = false
@export var enable_mouse_capture: bool = true

@export_group("Input Actions")
@export var camera_mode_toggle: String = "camera_mode_toggle"
@export var camera_reset: String = "camera_reset"
@export var zoom_in: String = "zoom_in"
@export var zoom_out: String = "zoom_out"

@export_group("Camera Components")
@export var camera_responder: CCC_CameraResponder
@export var camera_modes: CCC_CameraModes

var mouse_delta: Vector2 = Vector2.ZERO
var gamepad_look: Vector2 = Vector2.ZERO
var zoom_input: float = 0.0
var is_mouse_captured: bool = false

signal camera_look_input(delta: Vector2)
signal camera_zoom_input(zoom_delta: float)
signal camera_action_triggered(action: String)

func _ready():
	if enable_mouse_capture:
		capture_mouse()

func _input(event):
	handle_mouse_input(event)
	handle_action_input(event)

func _process(delta):
	handle_gamepad_input(delta)
	process_camera_input()

func handle_mouse_input(event):
	if event is InputEventMouseMotion and is_mouse_captured:
		mouse_delta = event.relative * mouse_sensitivity
		if invert_y:
			mouse_delta.y *= -1
	
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_input += 1.0
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_input -= 1.0
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if not is_mouse_captured and enable_mouse_capture:
				capture_mouse()

func handle_action_input(event):
	if event.is_action_pressed(camera_mode_toggle):
		camera_action_triggered.emit("mode_toggle")
	elif event.is_action_pressed(camera_reset):
		camera_action_triggered.emit("reset")
	elif event.is_action_pressed("ui_cancel"):
		if is_mouse_captured:
			release_mouse()

func handle_gamepad_input(delta):
	# Right stick for camera look
	gamepad_look.x = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	gamepad_look.y = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	
	# Apply deadzone
	if gamepad_look.length() < 0.2:
		gamepad_look = Vector2.ZERO
	else:
		gamepad_look *= gamepad_sensitivity * delta
		if invert_y:
			gamepad_look.y *= -1

func process_camera_input():
	# Combine mouse and gamepad input
	var total_look_input = mouse_delta + gamepad_look
	
	if total_look_input.length() > 0:
		camera_look_input.emit(total_look_input)
	
	if zoom_input != 0:
		camera_zoom_input.emit(zoom_input)
		zoom_input = 0.0
	
	# Reset mouse delta after processing
	mouse_delta = Vector2.ZERO

func capture_mouse():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	is_mouse_captured = true

func release_mouse():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	is_mouse_captured = false

func set_mouse_sensitivity(sensitivity: float):
	mouse_sensitivity = sensitivity

func set_gamepad_sensitivity(sensitivity: float):
	gamepad_sensitivity = sensitivity

func set_invert_y(invert: bool):
	invert_y = invert

func get_debug_info() -> Dictionary:
	return {
		"camera_input_mouse_captured": is_mouse_captured,
		"camera_input_mouse_delta": mouse_delta,
		"camera_input_gamepad_look": gamepad_look,
		"camera_input_zoom": zoom_input,
		"camera_input_mouse_sensitivity": mouse_sensitivity,
		"camera_input_gamepad_sensitivity": gamepad_sensitivity
	}