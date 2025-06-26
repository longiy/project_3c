# CameraActionReceiver.gd - Bridges action system to camera signals
extends Node
class_name CameraActionReceiver

@export_group("Input Settings")
@export var scroll_zoom_speed = 0.5
@export var enable_action_processing = true
@export var action_system_node: NodePath = ""  # Set in inspector

# Component references
var camera_rig: CameraRig
var action_system: ActionSystem

func _ready():
	camera_rig = get_parent() as CameraRig
	if not camera_rig:
		push_error("CameraActionReceiver must be child of CameraRig")
		return
	
	# Find action system in scene
	find_and_connect_action_system()
	
	print("📹 CameraActionReceiver: Initialized")

func _input(event):
	"""Handle direct input events that need immediate processing"""
	if not enable_action_processing:
		return
		
	# Handle scroll wheel for zoom (immediate response needed)
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				camera_rig._on_zoom_input(-scroll_zoom_speed)
			MOUSE_BUTTON_WHEEL_DOWN:
				camera_rig._on_zoom_input(scroll_zoom_speed)
	
	# Handle mouse toggle (immediate response needed)
	if event.is_action_pressed("toggle_mouse_look"):
		camera_rig._on_mouse_toggle()

func connect_to_action_system():
	"""Connect to action system"""
	if action_system and action_system.has_signal("action_executed"):
		action_system.action_executed.connect(_on_action_executed)
		print("✅ CameraActionReceiver: Connected to ActionSystem at ", action_system.get_path())
	else:
		print("❌ CameraActionReceiver: ActionSystem missing action_executed signal")

func find_and_connect_action_system():
	"""Use explicit path instead of scene searching"""
	# EXPLICIT connection via NodePath
	if not action_system_node.is_empty():
		action_system = get_node_or_null(action_system_node) as ActionSystem
		if action_system:
			connect_to_action_system()
			return
	
	# FALLBACK: Only search immediate scene children (no deep search)
	var scene_root = get_tree().current_scene
	if scene_root:
		for child in scene_root.get_children():
			if child is CharacterBody3D:
				var action_sys = child.get_node_or_null("ActionSystem")
				if action_sys:
					action_system = action_sys
					connect_to_action_system()
					return
	
	print("⚠️ CameraActionReceiver: No ActionSystem found - set action_system_node path")


# === ACTION PROCESSING ===

func _on_action_executed(action: Action):
	"""Process camera-related actions"""
	if not enable_action_processing or not camera_rig:
		return
	
	match action.name:
		"look_delta":
			handle_look_action(action)
		"camera_zoom":
			handle_zoom_action(action)
		"camera_toggle_mouse":
			handle_mouse_toggle_action(action)
		"camera_set_fov":
			handle_fov_action(action)
		"camera_set_distance":
			handle_distance_action(action)

func handle_look_action(action: Action):
	"""Handle look_delta action"""
	var delta = action.get_look_delta()
	var sensitivity = action.context.get("sensitivity", 1.0)
	
	camera_rig._on_look_input(delta, sensitivity)

func handle_zoom_action(action: Action):
	"""Handle camera zoom action"""
	var zoom_delta = action.context.get("zoom_delta", 0.0)
	camera_rig._on_zoom_input(zoom_delta)

func handle_mouse_toggle_action(action: Action):
	"""Handle mouse toggle action"""
	camera_rig._on_mouse_toggle()

func handle_fov_action(action: Action):
	"""Handle FOV change action"""
	var fov = action.context.get("fov", 75.0)
	var transition_time = action.context.get("transition_time", 0.0)
	camera_rig.set_camera_fov(fov, transition_time)

func handle_distance_action(action: Action):
	"""Handle distance change action"""
	var distance = action.context.get("distance", 4.0)
	var transition_time = action.context.get("transition_time", 0.0)
	camera_rig.set_camera_distance(distance, transition_time)

# === MANUAL ACTION REQUESTS ===

func request_camera_action(action_name: String, context: Dictionary = {}):
	"""Manually request camera action (for external systems)"""
	if action_system:
		action_system.request_action(action_name, context)
		print("📹 CameraActionReceiver: Requested action - ", action_name)
	else:
		print("❌ CameraActionReceiver: No action system connected")

# === CONTROL API ===

func set_enabled(enabled: bool):
	"""Enable/disable action processing"""
	enable_action_processing = enabled
	print("📹 CameraActionReceiver: ", "Enabled" if enabled else "Disabled")

func is_connected_to_action_system() -> bool:
	"""Check if connected to action system"""
	return action_system != null

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get debug information"""
	return {
		"enabled": enable_action_processing,
		"action_system_connected": action_system != null,
		"action_system_path": action_system.get_path() if action_system else "None",
		"scroll_zoom_speed": scroll_zoom_speed
	}
