# GamepadControlComponent.gd
# Handles gamepad/controller input for character control
# Generates same command signals as DirectControlComponent

extends Node
class_name GamepadControlComponent

# Command signals - same interface as DirectControlComponent
signal movement_command(direction: Vector2, magnitude: float)
signal look_command(delta: Vector2)
signal action_command(action: String, pressed: bool)

# References
var input_priority_manager: InputPriorityManager
var camera_system: CameraSystem

# Gamepad settings
@export_group("Gamepad Settings")
@export var stick_deadzone: float = 0.2
@export var trigger_deadzone: float = 0.1
@export var look_sensitivity: float = 2.0
@export var invert_y: bool = false
@export var device_id: int = 0  # Which gamepad (0-3)

@export_group("Input Mapping")
@export var movement_stick: JoyAxis = JOY_AXIS_LEFT_X  # Left stick for movement
@export var look_stick: JoyAxis = JOY_AXIS_RIGHT_X     # Right stick for camera
@export var jump_button: JoyButton = JOY_BUTTON_A
@export var sprint_button: JoyButton = JOY_BUTTON_X
@export var walk_button: JoyButton = JOY_BUTTON_B

# Internal state
var is_active: bool = false
var current_movement: Vector2 = Vector2.ZERO
var last_look_input_time: float = 0.0

func _ready():
	# Get references
	input_priority_manager = get_node("../../InputCore/InputPriorityManager")
	if input_priority_manager:
		input_priority_manager.register_component(InputPriorityManager.InputType.GAMEPAD, self)
	
	camera_system = get_node("../../../CAMERA") as CameraSystem
	if not camera_system:
		push_error("GamepadControlComponent: CAMERA system not found")
		return
	
	print("GamepadControlComponent: Initialized for device ", device_id)

func _process(delta):
	# Always check gamepad input for activity detection
	check_gamepad_activity()
	
	# Process gamepad input if active or for fallback
	if is_active or should_process_fallback():
		process_gamepad_input(delta)

func process_input(event: InputEvent):
	# Main input processing - called by InputPriorityManager
	if not input_priority_manager:
		return
	
	# Check if we should be active
	is_active = input_priority_manager.is_input_active(InputPriorityManager.InputType.GAMEPAD)
	
	# Handle gamepad events
	if event is InputEventJoypadButton:
		process_gamepad_button(event)
	elif event is InputEventJoypadMotion:
		process_gamepad_motion(event)

func process_fallback_input(event: InputEvent):
	# Limited fallback processing for gamepad
	if event is InputEventJoypadButton:
		process_gamepad_button(event)

func check_gamepad_activity():
	# Check if gamepad is being used - sets priority automatically
	var movement_active = get_movement_magnitude() > stick_deadzone
	var look_active = get_look_magnitude() > stick_deadzone
	var any_button_pressed = is_any_action_button_pressed()
	
	if movement_active or look_active or any_button_pressed:
		if input_priority_manager and not is_active:
			input_priority_manager.set_active_input(InputPriorityManager.InputType.GAMEPAD)

func process_gamepad_input(delta: float):
	# Process movement stick
	process_movement_stick()
	
	# Process look stick
	process_look_stick(delta)
	
	# Process buttons (done in process_input via events)

func process_movement_stick():
	# Get movement input from left stick
	var move_vector = Vector2(
		Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(device_id, JOY_AXIS_LEFT_Y)
	)
	
	# Apply deadzone
	if move_vector.length() < stick_deadzone:
		move_vector = Vector2.ZERO
	else:
		# Normalize to remove deadzone, then scale
		move_vector = (move_vector - move_vector.normalized() * stick_deadzone) / (1.0 - stick_deadzone)
	
	# Store current movement
	current_movement = move_vector
	
	# Emit movement command if we have movement
	if move_vector.length() > 0:
		movement_command.emit(move_vector.normalized(), move_vector.length())

func process_look_stick(delta: float):
	# Get look input from right stick
	var look_vector = Vector2(
		Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_Y)
	)
	
	# Apply deadzone
	if look_vector.length() < stick_deadzone:
		return
	
	# Apply sensitivity and invert Y if needed
	look_vector *= look_sensitivity * delta * 60.0  # Frame-rate independent
	
	if invert_y:
		look_vector.y = -look_vector.y
	
	# Only send look commands when we're active (camera control)
	if is_active:
		look_command.emit(look_vector)
		last_look_input_time = Time.get_ticks_msec() / 1000.0

func process_gamepad_button(event: InputEventJoypadButton):
	# Handle button presses
	if event.device != device_id:
		return
	
	var action_name = get_action_name_for_button(event.button_index)
	
	if action_name != "":
		# Only emit actions when we're the primary input
		if is_active:
			action_command.emit(action_name, event.pressed)

func process_gamepad_motion(event: InputEventJoypadMotion):
	# Handle analog stick and trigger motion
	if event.device != device_id:
		return
	
	# Trigger handling for additional actions
	match event.axis:
		JOY_AXIS_TRIGGER_LEFT:
			if event.axis_value > trigger_deadzone and is_active:
				action_command.emit("aim", true)
			elif event.axis_value <= trigger_deadzone and is_active:
				action_command.emit("aim", false)
		
		JOY_AXIS_TRIGGER_RIGHT:
			if event.axis_value > trigger_deadzone and is_active:
				action_command.emit("action", true)
			elif event.axis_value <= trigger_deadzone and is_active:
				action_command.emit("action", false)

func get_action_name_for_button(button_index: JoyButton) -> String:
	# Map gamepad buttons to action names
	match button_index:
		jump_button:
			return "jump"
		sprint_button:
			return "sprint"
		walk_button:
			return "walk"
		JOY_BUTTON_Y:
			return "reset"
		JOY_BUTTON_START:
			return "pause"
		JOY_BUTTON_BACK:
			return "menu"
		_:
			return ""

func get_movement_magnitude() -> float:
	# Get current movement stick magnitude
	var move_vector = Vector2(
		Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(device_id, JOY_AXIS_LEFT_Y)
	)
	return move_vector.length()

func get_look_magnitude() -> float:
	# Get current look stick magnitude
	var look_vector = Vector2(
		Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_Y)
	)
	return look_vector.length()

func is_any_action_button_pressed() -> bool:
	# Check if any mapped action buttons are currently pressed
	var buttons_to_check = [
		jump_button, sprint_button, walk_button,
		JOY_BUTTON_Y, JOY_BUTTON_START, JOY_BUTTON_BACK
	]
	
	for button in buttons_to_check:
		if Input.is_joy_button_pressed(device_id, button):
			return true
	
	return false

func should_process_fallback() -> bool:
	# Process as fallback when not primary but gamepad is active
	return not is_active and (get_movement_magnitude() > stick_deadzone or get_look_magnitude() > stick_deadzone)

# Public API for debugging and external systems
func get_debug_info() -> Dictionary:
	return {
		"is_active": is_active,
		"device_id": device_id,
		"movement_magnitude": get_movement_magnitude(),
		"look_magnitude": get_look_magnitude(),
		"current_movement": current_movement,
		"deadzone": stick_deadzone,
		"sensitivity": look_sensitivity,
		"connected": Input.get_connected_joypads().has(device_id)
	}

func is_gamepad_connected() -> bool:
	return Input.get_connected_joypads().has(device_id)

func get_gamepad_name() -> String:
	if is_gamepad_connected():
		return Input.get_joy_name(device_id)
	return "Not connected"

# Settings adjustment functions
func set_sensitivity(new_sensitivity: float):
	look_sensitivity = clamp(new_sensitivity, 0.1, 5.0)

func set_deadzone(new_deadzone: float):
	stick_deadzone = clamp(new_deadzone, 0.0, 0.5)

func set_device_id(new_device_id: int):
	device_id = clamp(new_device_id, 0, 3)
