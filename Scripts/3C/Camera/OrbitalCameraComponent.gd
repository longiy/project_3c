# OrbitalCameraComponent.gd - Mouse look orbital camera behavior
extends Node
class_name OrbitalCameraComponent

# === SIGNALS ===
signal rotation_changed(pitch: float, yaw: float)
signal mouse_capture_changed(captured: bool)

# === EXPORTS ===
@export_group("Required References")
@export var camera_core: CameraCore
@export var camera_rig: Node3D  # Parent node that we rotate
@export var config_component: Node  # 3CConfigComponent

@export_group("Rotation Properties")
@export var enable_mouse_capture: bool = true
@export var enable_debug_output: bool = false

# === ROTATION STATE ===
var pitch_rotation: float = 0.0  # X-axis rotation (up/down)
var yaw_rotation: float = 0.0    # Y-axis rotation (left/right)
var mouse_captured: bool = false

func _ready():
	validate_setup()
	setup_initial_rotation()
	setup_mouse_capture()
	
	if enable_debug_output:
		print("OrbitalCameraComponent: Initialized")

func validate_setup():
	"""Validate required references"""
	if not camera_core:
		push_error("OrbitalCameraComponent: camera_core reference required")
	
	if not camera_rig:
		push_error("OrbitalCameraComponent: camera_rig reference required")
	
	if not config_component:
		push_error("OrbitalCameraComponent: config_component reference required")

func setup_initial_rotation():
	"""Set initial camera rotation"""
	pitch_rotation = deg_to_rad(-20.0)  # Start looking slightly down
	yaw_rotation = 0.0
	apply_rotation()

func setup_mouse_capture():
	"""Setup initial mouse capture state"""
	if enable_mouse_capture:
		capture_mouse()
	else:
		release_mouse()

func _input(event):
	"""Handle mouse input for camera rotation"""
	if not mouse_captured or not camera_rig:
		return
	
	if event is InputEventMouseMotion:
		handle_mouse_rotation(event.relative)

# === MOUSE CONTROL ===

func handle_mouse_rotation(mouse_delta: Vector2):
	"""Handle mouse rotation input"""
	var sensitivity = get_config_value("mouse_sensitivity", 0.002)
	var invert_y = get_config_value("invert_y_axis", false)
	
	var look_delta = mouse_delta * sensitivity
	
	if invert_y:
		look_delta.y = -look_delta.y
	
	# Apply rotation changes
	yaw_rotation -= look_delta.x
	pitch_rotation = clamp(
		pitch_rotation - look_delta.y,
		deg_to_rad(get_config_value("pitch_limit_min", -80.0)),
		deg_to_rad(get_config_value("pitch_limit_max", 50.0))
	)
	
	apply_rotation()
	rotation_changed.emit(pitch_rotation, yaw_rotation)
	
	if enable_debug_output:
		print("OrbitalCameraComponent: Rotation updated - Pitch: ", rad_to_deg(pitch_rotation), " Yaw: ", rad_to_deg(yaw_rotation))

func apply_rotation():
	"""Apply rotation to camera rig"""
	if not camera_rig:
		return
	
	# Apply yaw to camera rig Y rotation
	camera_rig.rotation.y = yaw_rotation
	
	# Apply pitch to camera rig X rotation
	camera_rig.rotation.x = pitch_rotation

# === MOUSE CAPTURE CONTROL ===

func capture_mouse():
	"""Capture mouse for camera control"""
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	mouse_captured = true
	mouse_capture_changed.emit(true)
	
	if enable_debug_output:
		print("OrbitalCameraComponent: Mouse captured")

func release_mouse():
	"""Release mouse from camera control"""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	mouse_captured = false
	mouse_capture_changed.emit(false)
	
	if enable_debug_output:
		print("OrbitalCameraComponent: Mouse released")

func toggle_mouse_capture():
	"""Toggle mouse capture state"""
	if mouse_captured:
		release_mouse()
	else:
		capture_mouse()

# === PUBLIC API ===

func set_rotation(pitch: float, yaw: float):
	"""Set camera rotation directly"""
	pitch_rotation = clamp(
		pitch,
		deg_to_rad(get_config_value("pitch_limit_min", -80.0)),
		deg_to_rad(get_config_value("pitch_limit_max", 50.0))
	)
	yaw_rotation = yaw
	apply_rotation()
	rotation_changed.emit(pitch_rotation, yaw_rotation)

func get_rotation() -> Vector2:
	"""Get current rotation as Vector2(pitch, yaw)"""
	return Vector2(pitch_rotation, yaw_rotation)

func get_rotation_degrees() -> Vector2:
	"""Get current rotation in degrees"""
	return Vector2(rad_to_deg(pitch_rotation), rad_to_deg(yaw_rotation))

func is_mouse_captured() -> bool:
	"""Check if mouse is captured"""
	return mouse_captured

func set_mouse_capture_enabled(enabled: bool):
	"""Enable/disable mouse capture functionality"""
	enable_mouse_capture = enabled
	if not enabled and mouse_captured:
		release_mouse()

# === CONFIGURATION ===

func get_config_value(property_name: String, default_value):
	"""Get configuration value safely"""
	if config_component and config_component.has_method("get_config_value"):
		return config_component.get_config_value(property_name, default_value)
	return default_value

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get debug information about orbital camera component"""
	return {
		"pitch_deg": rad_to_deg(pitch_rotation),
		"yaw_deg": rad_to_deg(yaw_rotation),
		"mouse_captured": mouse_captured,
		"mouse_capture_enabled": enable_mouse_capture,
		"mouse_sensitivity": get_config_value("mouse_sensitivity", 0.002),
		"invert_y": get_config_value("invert_y_axis", false)
	}