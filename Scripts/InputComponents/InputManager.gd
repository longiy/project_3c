# InputManager.gd - CLEANED UP: Pure raw input detection (CCC-only)
extends Node
class_name InputManager

# === SIGNALS ===
signal jump_pressed()
signal sprint_started()
signal sprint_stopped()
signal slow_walk_started()
signal slow_walk_stopped()
signal reset_pressed()
signal click_navigation(world_position: Vector3)

# === SETTINGS ===
@export_group("Input Settings")
@export var input_deadzone = 0.05
@export var movement_update_frequency = 60

# === STATE (Used by CCC_ControlManager) ===
var character: CharacterBody3D
var camera_rig: CameraController

var current_raw_input = Vector2.ZERO
var last_sent_input = Vector2.ZERO
var movement_active = false
var movement_start_time = 0.0

var input_components: Array[Node] = []
var movement_update_timer = 0.0
var movement_update_interval: float

func _ready():
	character = get_parent() as CharacterBody3D
	if not character:
		push_error("InputManager must be child of CharacterBody3D")
		return
	
	movement_update_interval = 1.0 / movement_update_frequency
	
	camera_rig = get_node_or_null("../../CAMERARIG") as CameraController
	if not camera_rig:
		push_warning("No CameraController found - click navigation may not work")
	
	call_deferred("find_input_components")
	print("✅ InputManager: Initialized in CCC mode (raw input only)")

func _input(event):
	# Handle discrete inputs only
	if event.is_action_pressed("jump"):
		jump_pressed.emit()
	elif event.is_action_pressed("reset"):
		reset_pressed.emit()
	elif event.is_action_pressed("sprint"):
		sprint_started.emit()
	elif event.is_action_released("sprint"):
		sprint_stopped.emit()
	elif event.is_action_pressed("walk"):
		slow_walk_started.emit()
	elif event.is_action_released("walk"):
		slow_walk_stopped.emit()

# === RAW INPUT DETECTION (Used by CCC_ControlManager) ===

func get_raw_wasd_input() -> Vector2:
	"""Get raw WASD input without any processing"""
	return Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

func get_raw_click_input() -> Vector2:
	"""Get raw click navigation input without processing"""
	for component in input_components:
		if is_component_active(component):
			var component_input = component.get_movement_input()
			if component_input and component_input.length() > input_deadzone:
				return component_input
	return Vector2.ZERO

# === INPUT COMPONENT MANAGEMENT ===

func cancel_all_input_components():
	"""Cancel all input components"""
	for component in input_components:
		if component and component.has_method("cancel_input"):
			component.cancel_input()

func find_input_components():
	"""Find and register input components"""
	input_components.clear()
	for child in character.get_children():
		if child != self and child.has_method("get_movement_input"):
			input_components.append(child)
	
	if input_components.size() > 0:
		print("📋 InputManager: Found ", input_components.size(), " input components")

func is_component_active(component: Node) -> bool:
	"""Check if input component is active"""
	return is_instance_valid(component) and component.has_method("is_active") and component.is_active()

# === STATE QUERIES (Used by CCC_ControlManager) ===

func get_movement_duration() -> float:
	"""Get how long movement has been active"""
	if movement_active:
		return (Time.get_ticks_msec() / 1000.0) - movement_start_time
	return 0.0

func is_movement_active() -> bool:
	"""Check if movement is currently active"""
	return movement_active

func get_current_input_direction() -> Vector2:
	"""Get current input direction"""
	return current_raw_input

# === CCC INTERFACE (Called by CCC_ControlManager) ===

func disable_legacy_movement_processing():
	"""Called by CCC_ControlManager - no longer needed (legacy removed)"""
	print("✅ InputManager: CCC mode active (legacy code removed)")

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get debug information"""
	var debug_data = {
		"mode": "ccc_only",
		"movement_active": movement_active,
		"current_input": current_raw_input,
		"movement_duration": get_movement_duration(),
		"component_count": input_components.size(),
		"raw_wasd": get_raw_wasd_input(),
		"raw_click": get_raw_click_input(),
		"input_deadzone": input_deadzone
	}
	
	if camera_rig:
		debug_data["camera_mode"] = camera_rig.get_mode_name(camera_rig.get_current_mode())
	else:
		debug_data["camera_mode"] = "unknown"
	
	return debug_data
