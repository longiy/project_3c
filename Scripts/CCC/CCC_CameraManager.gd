# CCC_CameraManager.gd - Camera axis wrapper for 3C architecture
extends Node
class_name CCC_CameraManager

# === WRAPPED COMPONENT ===
@export var camera_controller: CameraController

# === SIGNALS (Passthrough from CameraController) ===
signal camera_mode_changed(mode: String)
signal mouse_mode_changed(captured: bool)
signal target_lost()
signal target_acquired(target: Node3D)

# === 3C CAMERA CONFIGURATION (Empty for now) ===
enum CameraType {
	ORBITAL,       # Player-controlled 3D camera (current orbit mode)
	FOLLOWING,     # Auto-follow camera with smooth tracking
	FIXED,         # Static camera position(s)
	FIRST_PERSON,  # Camera at character eye level
	CONTEXTUAL     # Camera changes based on gameplay context
}

var current_camera_type: CameraType = CameraType.ORBITAL

func _ready():
	setup_camera_controller()
	connect_camera_signals()
	print("✅ CCC_CameraManager: Initialized as wrapper")

func setup_camera_controller():
	"""Find and reference CameraController"""
	if not camera_controller:
		camera_controller = get_node_or_null("CameraController")
	
	if not camera_controller:
		# Try finding it as a sibling
		camera_controller = get_parent().get_node_or_null("CameraController")
		
	if not camera_controller:
		# Try finding CAMERARIG
		camera_controller = get_node_or_null("../CAMERARIG") as CameraController
	
	if not camera_controller:
		push_error("CCC_CameraManager: No CameraController found!")
		return

func connect_camera_signals():
	"""Connect CameraController signals to our passthrough signals"""
	if not camera_controller:
		return
	
	# Connect camera signals through wrapper
	camera_controller.camera_mode_changed.connect(_on_camera_mode_changed)
	camera_controller.mouse_mode_changed.connect(_on_mouse_mode_changed)
	camera_controller.target_lost.connect(_on_target_lost)
	camera_controller.target_acquired.connect(_on_target_acquired)

# === SIGNAL PASSTHROUGH HANDLERS ===

func _on_camera_mode_changed(mode: String):
	camera_mode_changed.emit(mode)

func _on_mouse_mode_changed(captured: bool):
	mouse_mode_changed.emit(captured)

func _on_target_lost():
	target_lost.emit()

func _on_target_acquired(target: Node3D):
	target_acquired.emit(target)

# === CAMERA CONTROL PASSTHROUGH METHODS (No logic duplication) ===

func set_camera_mode(mode):
	"""Set camera mode through CameraController"""
	if camera_controller:
		camera_controller.set_camera_mode(mode)

func toggle_camera_mode():
	"""Toggle camera mode through CameraController"""
	if camera_controller:
		camera_controller.toggle_camera_mode()

func get_current_camera_mode():
	"""Get current camera mode"""
	if camera_controller:
		return camera_controller.current_mode
	return 0

func is_in_orbit_mode() -> bool:
	"""Check if camera is in orbit mode"""
	if camera_controller:
		return camera_controller.current_mode == CameraController.CameraMode.ORBIT
	return false

func is_in_click_navigation_mode() -> bool:
	"""Check if camera is in click navigation mode"""
	if camera_controller:
		return camera_controller.current_mode == CameraController.CameraMode.CLICK_NAVIGATION
	return false

# === TARGET MANAGEMENT ===

func set_target(target: Node3D):
	"""Set camera target"""
	if camera_controller:
		camera_controller.target_node = target

func get_target() -> Node3D:
	"""Get current camera target"""
	if camera_controller:
		return camera_controller.target_node
	return null

func clear_target():
	"""Clear camera target"""
	if camera_controller:
		camera_controller.target_node = null

# === CAMERA PROPERTIES ===

func set_follow_distance(distance: float):
	"""Set camera follow distance"""
	if camera_controller:
		camera_controller.target_distance = distance

func get_follow_distance() -> float:
	"""Get camera follow distance"""
	if camera_controller:
		return camera_controller.current_distance
	return 0.0

func set_fov(fov: float):
	"""Set camera field of view"""
	if camera_controller:
		camera_controller.target_fov = fov

func get_fov() -> float:
	"""Get current camera field of view"""
	if camera_controller:
		return camera_controller.current_fov
	return 75.0

func set_follow_smoothing(smoothing: float):
	"""Set camera follow smoothing"""
	if camera_controller:
		camera_controller.follow_smoothing = smoothing

func get_follow_smoothing() -> float:
	"""Get camera follow smoothing"""
	if camera_controller:
		return camera_controller.follow_smoothing
	return 8.0

# === CAMERA STATE ===

func is_camera_enabled() -> bool:
	"""Check if camera rig is enabled"""
	if camera_controller:
		return camera_controller.enable_camera_rig
	return false

func set_camera_enabled(enabled: bool):
	"""Enable/disable camera rig"""
	if camera_controller:
		camera_controller.enable_camera_rig = enabled

func is_externally_controlled() -> bool:
	"""Check if camera is externally controlled"""
	if camera_controller:
		return camera_controller.is_externally_controlled
	return false

func set_external_control(controlled: bool):
	"""Set external control state"""
	if camera_controller:
		camera_controller.is_externally_controlled = controlled

# === CAMERA POSITION/ROTATION ===

func get_camera_position() -> Vector3:
	"""Get camera world position"""
	if camera_controller and camera_controller.camera:
		return camera_controller.camera.global_position
	return Vector3.ZERO

func get_camera_rotation() -> Vector3:
	"""Get camera rotation"""
	if camera_controller:
		return Vector3(camera_controller.camera_rotation_x, camera_controller.camera_rotation_y, 0)
	return Vector3.ZERO

# === 3C CAMERA INTERFACE (Stubbed for future implementation) ===

func configure_camera_type(camera_type: CameraType):
	"""Configure the camera type (future implementation)"""
	current_camera_type = camera_type
	# TODO: Implement when adding 3C configuration system
	print("📷 CCC_CameraManager: Camera type set to ", CameraType.keys()[camera_type])

func set_information_clarity(clarity: float):
	"""Set how clearly the camera communicates spatial information (future implementation)"""
	# TODO: Implement when adding 3C configuration system
	pass

func set_comfort_level(comfort: float):
	"""Set camera comfort (motion sickness prevention) (future implementation)"""
	# TODO: Implement when adding 3C configuration system
	pass

func enable_cinematic_mode(enabled: bool):
	"""Enable cinematic camera behavior (future implementation)"""
	# TODO: Implement when adding 3C configuration system
	pass

func set_context_responsiveness(responsiveness: float):
	"""Set how much camera responds to gameplay context (future implementation)"""
	# TODO: Implement when adding 3C configuration system
	pass

# === SPECIAL EFFECTS (Passthrough to CameraResponder if available) ===

func trigger_camera_shake(intensity: float, duration: float):
	"""Trigger camera shake effect (future implementation)"""
	# TODO: Connect to CameraResponder or implement shake system
	pass

func set_dramatic_angle(enabled: bool):
	"""Enable dramatic camera angles for special moments (future implementation)"""
	# TODO: Implement when adding cinematic features
	pass

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get debug information including CameraController data"""
	var debug_data = {
		"camera_type": CameraType.keys()[current_camera_type],
		"wrapper_status": "active"
	}
	
	if camera_controller:
		debug_data.merge({
			"current_mode": camera_controller.get_mode_name(camera_controller.current_mode),
			"target": get_target().name if get_target() else "none",
			"distance": get_follow_distance(),
			"fov": get_fov(),
			"position": get_camera_position(),
			"rotation": get_camera_rotation(),
			"enabled": is_camera_enabled(),
			"external_control": is_externally_controlled()
		})
	else:
		debug_data["camera_controller"] = "missing"
	
	return debug_data
