# InputCore.gd
# Central input processing hub for CONTROL system
# PHASE 1: Direct component routing implementation

extends Node
class_name InputCore

# Input types enum (moved from InputPriorityManager)
enum InputType {
	DIRECT,     # WASD + Mouse look
	TARGET,     # Click navigation
	GAMEPAD     # Controller input
}

# Export references for direct component access
@export var control_system: ControlSystem
@export var direct_control_component: DirectControlComponent
@export var target_control_component: TargetControlComponent
@export var gamepad_control_component: GamepadControlComponent

# Component registration system
var registered_components: Dictionary = {}

# Active input tracking - simple "last input wins" logic
var active_input_type: InputType = InputType.DIRECT

# Input classification (from RawInputProcessor)
var wasd_actions = ["move_left", "move_right", "move_forward", "move_backward"]
var mouse_look_active = false
var gamepad_detected = false

func _ready():
	if not verify_references():
		return
	
	setup_component_registration()
	detect_gamepad()

func verify_references() -> bool:
	var missing = []
	
	if not control_system: missing.append("control_system")
	if not direct_control_component: missing.append("direct_control_component")
	if not target_control_component: missing.append("target_control_component")
	if not gamepad_control_component: missing.append("gamepad_control_component")
	
	if missing.size() > 0:
		push_error("InputCore: Missing references: " + str(missing))
		return false
	
	return true

func setup_component_registration():
	# Register components directly
	register_component(InputType.DIRECT, direct_control_component)
	register_component(InputType.TARGET, target_control_component)
	register_component(InputType.GAMEPAD, gamepad_control_component)

# Component registration system
func register_component(input_type: InputType, component: Node):
	if component:
		registered_components[input_type] = component
		print("InputCore: Registered component for type: ", InputType.keys()[input_type])

# Active input tracking
func set_active_input(input_type: InputType):
	active_input_type = input_type

func is_input_active(input_type: InputType) -> bool:
	return active_input_type == input_type

func get_active_input_type() -> InputType:
	return active_input_type

# Direct routing method
func route_to_active_component(event: InputEvent):
	var active_component = registered_components.get(active_input_type)
	if active_component and active_component.has_method("process_input"):
		active_component.process_input(event)

func process_input(event: InputEvent):
	# Direct input processing with component routing
	classify_and_route_input(event)

func process_unhandled_input(event: InputEvent):
	# Handle unhandled input directly
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			handle_escape_key()

# ===== INPUT CLASSIFICATION & ROUTING =====

func classify_and_route_input(event: InputEvent):
	# Handle specific input types with action-based routing
	
	if event is InputEventMouseButton:
		handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		handle_mouse_motion(event)
	elif event is InputEventKey:
		handle_keyboard_input(event)
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		handle_gamepad_input(event)

func classify_input_event(event: InputEvent) -> InputType:
	# Mouse motion (for camera look) - DIRECT
	if event is InputEventMouseMotion:
		return InputType.DIRECT
	
	# Mouse buttons (for click navigation) - TARGET
	elif event is InputEventMouseButton:
		return InputType.TARGET
	
	# Keyboard input (for WASD and actions) - DIRECT
	elif event is InputEventKey:
		var action_name = get_action_name_for_event(event)
		if action_name in wasd_actions:
			return InputType.DIRECT
		return InputType.DIRECT  # Default to DIRECT for keyboard
	
	# Gamepad input - GAMEPAD
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return InputType.GAMEPAD
	
	return InputType.DIRECT  # Default fallback

func route_fallback_input(event: InputEvent):
	# Send input to all components for fallback processing
	for component in registered_components.values():
		if component and component.has_method("process_fallback_input"):
			component.process_fallback_input(event)

func get_action_name_for_event(event: InputEventKey) -> String:
	var actions = ["move_left", "move_right", "move_forward", "move_backward", 
				   "jump", "sprint", "walk", "reset"]
	
	for action in actions:
		if InputMap.action_has_event(action, event):
			return action
	
	return ""

# ===== INDIVIDUAL INPUT HANDLERS =====

func handle_mouse_motion(event: InputEventMouseMotion):
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# In orbit mode - route to direct control for camera
		set_active_input(InputType.DIRECT)
		route_to_active_component(event)
	# In click navigation mode, mouse motion doesn't change input type
	else:
		route_to_active_component(event)

func handle_mouse_button(event: InputEventMouseButton):
	# Only handle left click for navigation when not in orbit mode
	if event.is_action("clicknav") and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		set_active_input(InputType.TARGET)
		route_to_active_component(event)
	# Ignore mouse2 (right click) - does nothing
	# Other buttons route to current active component
	elif not event.is_action("clicknav"):
		route_to_active_component(event)

func cancel_active_navigation():
	# Cancel any active click navigation when entering orbit mode
	var target_component = registered_components.get(InputType.TARGET)
	if target_component and target_component.has_method("force_stop_navigation"):
		target_component.force_stop_navigation()
		print("InputCore: Cancelled active navigation")

func toggle_orbit_mode():
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Exit orbit mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		print("InputCore: Exited orbit mode - cursor visible")
	else:
		# Enter orbit mode - cancel any active navigation first
		cancel_active_navigation()
		set_active_input(InputType.DIRECT)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		print("InputCore: Entered orbit mode - cursor captured")

func handle_keyboard_input(event: InputEventKey):
	# Handle orbit mode toggle - highest priority
	if event.is_action_pressed("orbit"):
		toggle_orbit_mode()
		return
	
	# WASD always sets DIRECT mode when not in orbit
	var action_name = get_action_name_for_event(event)
	if action_name in wasd_actions and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		set_active_input(InputType.DIRECT)
	
	# Always route keyboard input
	route_to_active_component(event)

func handle_gamepad_input(event: InputEvent):
	set_active_input(InputType.GAMEPAD)
	route_to_active_component(event)

func handle_escape_key():
	# Handle escape key logic
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		get_tree().quit()

# ===== GAMEPAD DETECTION =====

func detect_gamepad():
	# Check for connected gamepads
	for device in Input.get_connected_joypads():
		gamepad_detected = true
		print("InputCore: Gamepad detected: ", Input.get_joy_name(device))
		break

func get_control_components():
	# Helper method for component access
	if control_system:
		return control_system.get_components()
	return null

# ===== DEBUG HELPERS =====

func get_input_type_name(input_type: InputType) -> String:
	return InputType.keys()[input_type]

func get_debug_info() -> Dictionary:
	return {
		"active_input_type": get_input_type_name(active_input_type),
		"registered_components": registered_components.keys().size(),
		"gamepad_detected": gamepad_detected
	}
