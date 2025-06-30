# KeyboardMouseComponent.gd - Keyboard and mouse device handling
extends Node
class_name CCC_KeyboardMouseComponent

# === SIGNALS ===
signal device_input_received(event: InputEvent)
signal sensitivity_changed(new_sensitivity: float)
signal deadzone_changed(new_deadzone: float)

# === EXPORTS ===
@export_group("Required References")
@export var config_component: Node  # 3CConfigComponent

@export_group("Device Properties")
@export var enable_mouse_input: bool = true
@export var enable_keyboard_input: bool = true
@export var enable_debug_output: bool = false

# === INPUT STATE ===
var current_mouse_sensitivity: float = 0.002
var current_deadzone: float = 0.1
var mouse_captured: bool = false

# === INPUT MAPPING ===
var action_mappings: Dictionary = {
	"move_forward": "w",
	"move_backward": "s", 
	"move_left": "a",
	"move_right": "d",
	"jump": "space",
	"sprint": "shift",
	"toggle_camera_mode": "mouse_right"
}

func _ready():
	validate_setup()
	load_device_settings()
	
	if enable_debug_output:
		print("KeyboardMouseComponent: Initialized")

func validate_setup():
	"""Validate required references"""
	if not config_component:
		push_error("KeyboardMouseComponent: config_component reference required")

func load_device_settings():
	"""Load device settings from configuration"""
	current_mouse_sensitivity = get_config_value("mouse_sensitivity", 0.002)
	current_deadzone = get_config_value("input_deadzone", 0.1)

func _input(event):
	"""Handle device input events"""
	if not is_input_enabled():
		return
	
	# Process mouse input
	if enable_mouse_input and event is InputEventMouse:
		handle_mouse_input(event)
	
	# Process keyboard input
	if enable_keyboard_input and event is InputEventKey:
		handle_keyboard_input(event)
	
	# Emit for other components to handle
	device_input_received.emit(event)

# === MOUSE INPUT ===

func handle_mouse_input(event: InputEventMouse):
	"""Handle mouse input events"""
	if event is InputEventMouseMotion:
		handle_mouse_motion(event)
	elif event is InputEventMouseButton:
		handle_mouse_button(event)

func handle_mouse_motion(event: InputEventMouseMotion):
	"""Handle mouse motion for camera control"""
	# Only process if mouse is captured for camera control
	if not mouse_captured:
		return
	
	# Apply sensitivity to motion
	var adjusted_motion = event.relative * current_mouse_sensitivity
	
	# Create modified event with adjusted sensitivity
	var modified_event = InputEventMouseMotion.new()
	modified_event.relative = adjusted_motion
	modified_event.position = event.position
	
	if enable_debug_output:
		print("KeyboardMouseComponent: Mouse motion - ", adjusted_motion)

func handle_mouse_button(event: InputEventMouseButton):
	"""Handle mouse button events"""
	# Handle camera mode toggle
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		toggle_mouse_capture()
	
	# Handle scroll wheel for zoom
	if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if enable_debug_output:
			print("KeyboardMouseComponent: Mouse wheel - ", event.button_index)

# === KEYBOARD INPUT ===

func handle_keyboard_input(event: InputEventKey):
	"""Handle keyboard input events"""
	if not event.pressed:
		return
	
	# Handle special key combinations
	if event.keycode == KEY_ESCAPE:
		handle_escape_key()
	
	if enable_debug_output:
		print("KeyboardMouseComponent: Key pressed - ", event.keycode)

func handle_escape_key():
	"""Handle escape key press"""
	if mouse_captured:
		release_mouse_capture()

# === MOUSE CAPTURE MANAGEMENT ===

func toggle_mouse_capture():
	"""Toggle mouse capture state"""
	if mouse_captured:
		release_mouse_capture()
	else:
		capture_mouse()

func capture_mouse():
	"""Capture mouse for camera control"""
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	mouse_captured = true
	
	if enable_debug_output:
		print("KeyboardMouseComponent: Mouse captured")

func release_mouse_capture():
	"""Release mouse capture"""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	mouse_captured = false
	
	if enable_debug_output:
		print("KeyboardMouseComponent: Mouse released")

# === SENSITIVITY AND DEADZONE ===

func set_mouse_sensitivity(sensitivity: float):
	"""Set mouse sensitivity"""
	current_mouse_sensitivity = clamp(sensitivity, 0.0001, 0.01)
	sensitivity_changed.emit(current_mouse_sensitivity)
	
	# Update configuration
	if config_component and config_component.has_method("set_config_value"):
		config_component.set_config_value("mouse_sensitivity", current_mouse_sensitivity)
	
	if enable_debug_output:
		print("KeyboardMouseComponent: Mouse sensitivity set to ", current_mouse_sensitivity)

func set_input_deadzone(deadzone: float):
	"""Set input deadzone"""
	current_deadzone = clamp(deadzone, 0.0, 0.5)
	deadzone_changed.emit(current_deadzone)
	
	# Update configuration
	if config_component and config_component.has_method("set_config_value"):
		config_component.set_config_value("input_deadzone", current_deadzone)
	
	if enable_debug_output:
		print("KeyboardMouseComponent: Input deadzone set to ", current_deadzone)

# === INPUT REMAPPING ===

func remap_action(action_name: String, new_key: String):
	"""Remap action to new key"""
	if action_name in action_mappings:
		action_mappings[action_name] = new_key
		
		if enable_debug_output:
			print("KeyboardMouseComponent: Remapped ", action_name, " to ", new_key)

func get_action_mapping(action_name: String) -> String:
	"""Get current mapping for action"""
	return action_mappings.get(action_name, "")

func reset_default_mappings():
	"""Reset to default key mappings"""
	action_mappings = {
		"move_forward": "w",
		"move_backward": "s", 
		"move_left": "a",
		"move_right": "d",
		"jump": "space",
		"sprint": "shift",
		"toggle_camera_mode": "mouse_right"
	}

# === DEVICE DETECTION ===

func is_mouse_available() -> bool:
	"""Check if mouse is available"""
	return Input.get_connected_joypads().size() >= 0  # Mouse is always available

func is_keyboard_available() -> bool:
	"""Check if keyboard is available"""
	return true  # Keyboard is always available on PC

func get_input_device_info() -> Dictionary:
	"""Get information about input devices"""
	return {
		"mouse_available": is_mouse_available(),
		"keyboard_available": is_keyboard_available(),
		"mouse_captured": mouse_captured,
		"mouse_sensitivity": current_mouse_sensitivity,
		"input_deadzone": current_deadzone
	}

# === INPUT VALIDATION ===

func is_input_enabled() -> bool:
	"""Check if input processing is enabled"""
	return enable_mouse_input or enable_keyboard_input

func validate_input_event(event: InputEvent) -> bool:
	"""Validate if input event should be processed"""
	if event is InputEventMouseMotion and not enable_mouse_input:
		return false
	
	if event is InputEventKey and not enable_keyboard_input:
		return false
	
	return true

# === PUBLIC API ===

func get_mouse_sensitivity() -> float:
	"""Get current mouse sensitivity"""
	return current_mouse_sensitivity

func get_input_deadzone() -> float:
	"""Get current input deadzone"""
	return current_deadzone

func is_mouse_captured() -> bool:
	"""Check if mouse is captured"""
	return mouse_captured

func enable_mouse_input_processing(enabled: bool):
	"""Enable/disable mouse input processing"""
	enable_mouse_input = enabled

func enable_keyboard_input_processing(enabled: bool):
	"""Enable/disable keyboard input processing"""
	enable_keyboard_input = enabled

func force_release_mouse():
	"""Force release mouse (for cutscenes, menus, etc.)"""
	release_mouse_capture()

func get_action_mappings() -> Dictionary:
	"""Get all current action mappings"""
	return action_mappings.duplicate()

# === CONFIGURATION ===

func configure_from_3c(config: CCC_CharacterConfig):
	"""Configure device component from 3C config"""
	if not config:
		return
	
	current_mouse_sensitivity = config.mouse_sensitivity
	current_deadzone = config.input_deadzone
	
	if enable_debug_output:
		print("KeyboardMouseComponent: Configured from 3C config")

func get_config_value(property_name: String, default_value):
	"""Get configuration value safely"""
	if config_component and config_component.has_method("get_config_value"):
		return config_component.get_config_value(property_name, default_value)
	return default_value

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get debug information about keyboard/mouse component"""
	return {
		"mouse_input_enabled": enable_mouse_input,
		"keyboard_input_enabled": enable_keyboard_input,
		"mouse_captured": mouse_captured,
		"mouse_sensitivity": current_mouse_sensitivity,
		"input_deadzone": current_deadzone,
		"action_mappings": action_mappings,
		"device_info": get_input_device_info()
	}
