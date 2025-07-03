# InputCore.gd
# Central input processing hub for CONTROL system
# MERGED: RawInputProcessor functionality integrated directly

extends Node
class_name InputCore

# Export references
@export_group("References")
@export var input_priority_manager: InputPriorityManager
@export var control_system: ControlSystem

# Input classification (from RawInputProcessor)
var wasd_actions = ["move_left", "move_right", "move_forward", "move_backward"]
var mouse_look_active = false
var gamepad_detected = false

func _ready():
	if not verify_references():
		return
	
	setup_input_processors()
	detect_gamepad()

func verify_references() -> bool:
	var missing = []
	
	if not input_priority_manager: missing.append("input_priority_manager")
	if not control_system: missing.append("control_system")
	
	if missing.size() > 0:
		push_error("InputCore: Missing references: " + str(missing))
		return false
	
	return true

func setup_input_processors():
	if input_priority_manager and input_priority_manager.has_method("set_input_core"):
		input_priority_manager.set_input_core(self)

func process_input(event: InputEvent):
	# Direct input processing - no more RawInputProcessor middleman
	classify_and_route_input(event)

func process_unhandled_input(event: InputEvent):
	# Handle unhandled input directly
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			handle_escape_key()

# ===== INPUT CLASSIFICATION & ROUTING =====
# (Merged from RawInputProcessor)

func classify_and_route_input(event: InputEvent):
	# Categorize and route input events directly
	
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

func handle_mouse_motion(event: InputEventMouseMotion):
	# Route mouse motion to appropriate input type
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Mouse look mode - route to direct control
		route_to_priority_manager(event, "DIRECT")
	else:
		# Free mouse mode - route to target control for drag detection
		route_to_priority_manager(event, "TARGET")

func handle_mouse_button(event: InputEventMouseButton):
	# Determine input type based on mouse mode and button
	if event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			# Left click in visible mode - route to click navigation
			route_to_priority_manager(event, "TARGET")
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		# Right click - could toggle mouse modes
		if event.pressed:
			toggle_mouse_mode()

func handle_keyboard_input(event: InputEventKey):
	# Check if it's a movement key
	var action_name = get_action_for_key(event)
	
	if action_name in wasd_actions:
		# Movement input - route to direct control
		route_to_priority_manager(event, "DIRECT")
	else:
		# Other keyboard input (jump, sprint, etc.)
		route_to_priority_manager(event, "DIRECT")

func handle_gamepad_input(event: InputEvent):
	# Gamepad input detected
	if not gamepad_detected:
		gamepad_detected = true
		print("InputCore: Gamepad detected")
	
	# Route to gamepad control
	route_to_priority_manager(event, "GAMEPAD")

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

func toggle_mouse_mode():
	# Toggle between captured and visible mouse modes
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		print("InputCore: Mouse released")
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		print("InputCore: Mouse captured")

func handle_escape_key():
	# Handle escape key - typically releases mouse
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		print("InputCore: Mouse released (ESC)")

func detect_gamepad():
	# Check if gamepad is connected
	for i in range(4):  # Check first 4 controller slots
		if Input.get_connected_joypads().has(i):
			gamepad_detected = true
			print("InputCore: Gamepad detected at slot ", i)
			break

# ===== PRIORITY MANAGER INTERFACE =====

func route_to_priority_manager(event: InputEvent, input_type: String):
	if input_priority_manager:
		input_priority_manager.route_input(event, input_type)

func get_control_components():
	return control_system.get_components() if control_system else null

# ===== DEBUG INFO =====

func get_debug_info() -> Dictionary:
	return {
		"mouse_look_active": mouse_look_active,
		"gamepad_detected": gamepad_detected,
		"mouse_mode": Input.mouse_mode,
		"connected_joypads": Input.get_connected_joypads()
	}
