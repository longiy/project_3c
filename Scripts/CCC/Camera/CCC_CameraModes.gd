class_name CCC_CameraModes
extends Node

@export_group("Mode Settings")
@export var default_mode: String = "follow"
@export var auto_switch_modes: bool = true

@export_group("Camera Components")
@export var camera_input: CCC_CameraInput
@export var camera_responder: CCC_CameraResponder

@export_group("3C Integration")
@export var character_controller: CCC_CharacterController
@export var input_manager: CCC_InputManager

var available_modes: Array[String] = ["follow", "orbit", "free"]
var current_mode_index: int = 0
var mode_descriptions: Dictionary = {
	"follow": "Camera follows character with relative movement",
	"orbit": "Camera orbits around character, WASD only",
	"free": "Free camera movement independent of character"
}

signal mode_changed(new_mode: String, old_mode: String)
signal mode_switch_requested(mode: String)

func _ready():
	set_mode(default_mode)
	connect_signals()

func connect_signals():
	if character_controller:
		character_controller.state_changed.connect(_on_character_state_changed)
	
	if input_manager:
		input_manager.input_source_changed.connect(_on_input_source_changed)

func set_mode(mode_name: String):
	var mode_index = available_modes.find(mode_name)
	if mode_index == -1:
		push_warning("Unknown camera mode: " + mode_name)
		return
	
	var old_mode = get_current_mode()
	current_mode_index = mode_index
	
	apply_mode_settings()
	mode_changed.emit(get_current_mode(), old_mode)

func cycle_mode():
	current_mode_index = (current_mode_index + 1) % available_modes.size()
	var old_mode = available_modes[(current_mode_index - 1 + available_modes.size()) % available_modes.size()]
	
	apply_mode_settings()
	mode_changed.emit(get_current_mode(), old_mode)

func apply_mode_settings():
	var current_mode = get_current_mode()
	
	match current_mode:
		"follow":
			setup_follow_mode()
		"orbit":
			setup_orbit_mode()
		"free":
			setup_free_mode()

func setup_follow_mode():
	# Follow mode: camera follows character, all input types allowed
	if camera_input:
		camera_input.enable_mouse_capture = false
	
	# Notify input manager of mode change
	if input_manager:
		# Input manager will handle input priority based on camera mode
		pass

func setup_orbit_mode():
	# Orbit mode: camera orbits, WASD input only
	if camera_input:
		camera_input.enable_mouse_capture = true
	
	# Input manager will restrict to WASD only in orbit mode

func setup_free_mode():
	# Free mode: independent camera movement
	if camera_input:
		camera_input.enable_mouse_capture = true

func _on_character_state_changed(state: String):
	if not auto_switch_modes:
		return
	
	match state:
		"JUMPING", "FALLING":
			# Could auto-switch to better mode for aerial movement
			if get_current_mode() != "orbit":
				mode_switch_requested.emit("orbit")
		"IDLE", "WALKING":
			# Could auto-switch back to follow mode
			if get_current_mode() == "free":
				mode_switch_requested.emit("follow")

func _on_input_source_changed(source: String):
	if not auto_switch_modes:
		return
	
	match source:
		"click_navigation":
			if get_current_mode() != "follow":
				mode_switch_requested.emit("follow")
		"none":
			# Input cancelled, could switch to orbit for observation
			pass

func get_current_mode() -> String:
	if current_mode_index >= 0 and current_mode_index < available_modes.size():
		return available_modes[current_mode_index]
	return "unknown"

func get_current_mode_index() -> int:
	return current_mode_index

func get_mode_description(mode: String = "") -> String:
	if mode.is_empty():
		mode = get_current_mode()
	
	return mode_descriptions.get(mode, "Unknown mode")

func get_available_modes() -> Array[String]:
	return available_modes.duplicate()

func is_mode_available(mode: String) -> bool:
	return mode in available_modes

func add_custom_mode(mode_name: String, description: String = ""):
	if mode_name not in available_modes:
		available_modes.append(mode_name)
		if not description.is_empty():
			mode_descriptions[mode_name] = description

func remove_mode(mode_name: String):
	var index = available_modes.find(mode_name)
	if index != -1 and available_modes.size() > 1:
		available_modes.remove_at(index)
		mode_descriptions.erase(mode_name)
		
		# Adjust current mode if necessary
		if current_mode_index >= available_modes.size():
			current_mode_index = 0
			apply_mode_settings()

func get_debug_info() -> Dictionary:
	return {
		"camera_modes_current": get_current_mode(),
		"camera_modes_index": current_mode_index,
		"camera_modes_available": available_modes,
		"camera_modes_description": get_mode_description(),
		"camera_modes_auto_switch": auto_switch_modes
	}
