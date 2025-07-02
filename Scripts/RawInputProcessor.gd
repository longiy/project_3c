# RawInputProcessor.gd
# Processes raw input events and categorizes them
# First stage of input processing pipeline

extends Node
class_name RawInputProcessor

var input_core: InputCore

# Input categorization
var wasd_actions = ["move_left", "move_right", "move_forward", "move_backward"]
var mouse_look_active = false
var gamepad_detected = false

func _ready():
	# Check for gamepad on startup
	detect_gamepad()

func set_input_core(core: InputCore):
	input_core = core

func process_raw_input(event: InputEvent):
	# Categorize and route input events
	
	# Mouse motion (for camera look)
	if event is InputEventMouseMotion:
		handle_mouse_motion(event)
	
	# Mouse buttons (for click navigation)
	elif event is InputEventMouseButton:
		handle_mouse_button(event)
	
	# Keyboard input (for WASD and actions)
	elif event is InputEventKey:
		handle_keyboard_input(event)
	
	# Gamepad input
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		handle_gamepad_input(event)

func process_unhandled_input(event: InputEvent):
	# Process any input that wasn't handled by main input processing
	if event is InputEventKey and event.pressed:
		# Handle special keys like ESC, etc.
		if event.keycode == KEY_ESCAPE:
			handle_escape_key()

func handle_mouse_motion(event: InputEventMouseMotion):
	# Route mouse motion to appropriate input type
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Mouse look mode - route to direct control
		route_input("DIRECT", event)
	else:
		# Free mouse mode - could be for UI or click navigation
		pass

func handle_mouse_button(event: InputEventMouseButton):
	# Determine input type based on mouse mode and button
	if event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			# Left click in visible mode - route to click navigation
			route_input("TARGET", event)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		# Right click - could toggle mouse modes
		if event.pressed:
			toggle_mouse_mode()

func handle_keyboard_input(event: InputEventKey):
	# Check if it's a movement key
	var action_name = get_action_for_key(event)
	
	if action_name in wasd_actions:
		# Movement input - route to direct control
		route_input("DIRECT", event)
	else:
		# Other keyboard input (jump, sprint, etc.)
		route_input("DIRECT", event)

func handle_gamepad_input(event: InputEvent):
	# Gamepad input detected
	if not gamepad_detected:
		gamepad_detected = true
		print("InputProcessor: Gamepad detected")
	
	# Route to gamepad control
	route_input("GAMEPAD", event)

func get_action_for_key(event: InputEventKey) -> String:
	# Map key events to action names
	for action in wasd_actions:
		if InputMap.action_has_event(action, event):
			return action
	
	# Check other actions
	var other_actions = ["jump", "sprint", "walk", "reset"]
	for action in other_actions:
		if InputMap.action_has_event(action, event):
			return action
	
	return ""

func route_input(input_type: String, event: InputEvent):
	# Route through InputCore to priority manager
	if input_core:
		input_core.route_to_priority_manager(event, input_type)

func toggle_mouse_mode():
	# Toggle between captured and visible mouse modes
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		print("InputProcessor: Mouse released")
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		print("InputProcessor: Mouse captured")

func handle_escape_key():
	# Handle escape key - typically releases mouse
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		print("InputProcessor: Mouse released (ESC)")

func detect_gamepad():
	# Check if gamepad is connected
	for i in range(4):  # Check first 4 controller slots
		if Input.get_connected_joypads().has(i):
			gamepad_detected = true
			print("InputProcessor: Gamepad detected at slot ", i)
			break

# Debug info
func get_debug_info() -> Dictionary:
	return {
		"mouse_look_active": mouse_look_active,
		"gamepad_detected": gamepad_detected,
		"mouse_mode": Input.mouse_mode,
		"connected_joypads": Input.get_connected_joypads()
	}