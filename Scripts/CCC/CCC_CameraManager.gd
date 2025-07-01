# CCC_CameraManager.gd - Enhanced with migrated camera mode control
extends Node
class_name CCC_CameraManager

# === WRAPPED COMPONENT ===
@export var camera_controller: CameraController

# === SIGNALS (Passthrough from CameraController) ===
signal camera_mode_changed(mode: String)
signal mouse_mode_changed(captured: bool)
signal target_lost()
signal target_acquired(target: Node3D)

# === CCC CAMERA CONFIGURATION ===
enum CameraType {
	ORBITAL,       # Player-controlled 3D camera (current orbit mode)
	FOLLOWING,     # Auto-follow camera with smooth tracking
	FIXED,         # Static camera position(s)
	FIRST_PERSON,  # Camera at character eye level
	CONTEXTUAL     # Camera changes based on gameplay context
}

# Camera behavior settings for each type
var camera_configs = {
	CameraType.ORBITAL: {
		"allows_manual_rotation": true,
		"allows_mode_switching": true,
		"mouse_capture_in_orbit": true,
		"default_distance": 4.0,
		"default_fov": 75.0
	},
	CameraType.FOLLOWING: {
		"allows_manual_rotation": false,
		"allows_mode_switching": false,
		"mouse_capture_in_orbit": false,
		"default_distance": 6.0,
		"default_fov": 65.0
	},
	CameraType.FIXED: {
		"allows_manual_rotation": false,
		"allows_mode_switching": false,
		"mouse_capture_in_orbit": false,
		"default_distance": 8.0,
		"default_fov": 60.0
	}
}

var current_camera_type: CameraType = CameraType.ORBITAL

# === MIGRATED CAMERA CONTROL STATE ===
var camera_logic_migrated = false
var camera_input_disabled = false
var custom_mode_switching_enabled = true


func _ready():
	setup_camera_controller()
	connect_camera_signals()
	check_migration_status()
	print("✅ CCC_CameraManager: Initialized with enhanced camera control")

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

func check_migration_status():
	"""Check if we should take over camera mode control"""
	# For now, always take control if CCC is active
	camera_logic_migrated = true
	print("🔄 CCC_CameraManager: Taking control of camera mode management")

func connect_camera_signals():
	"""Connect CameraController signals to our passthrough signals"""
	if not camera_controller:
		return
	
	# Connect camera signals through wrapper
	camera_controller.camera_mode_changed.connect(_on_camera_mode_changed)
	camera_controller.mouse_mode_changed.connect(_on_mouse_mode_changed)
	camera_controller.target_lost.connect(_on_target_lost)
	camera_controller.target_acquired.connect(_on_target_acquired)

func _input(event):
	"""MIGRATED: Handle camera input with CCC logic"""
	if not camera_logic_migrated or not camera_controller:
		return
	
	# Handle mode switching based on camera type
	if current_camera_type == CameraType.ORBITAL and custom_mode_switching_enabled:
		handle_orbital_camera_input(event)

func handle_orbital_camera_input(event: InputEvent):
	"""MIGRATED: Handle orbital camera input (was in CameraInput)"""
	if not camera_controller.enable_camera_rig or camera_controller.is_externally_controlled:
		return
	
	# Handle mode switching (right-click) - MIGRATED from CameraInput
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if can_switch_camera_mode():
			toggle_camera_mode()
		return
	
	# Pass other input to camera controller's input module
	if camera_controller.input_module:
		camera_controller.input_module.handle_input(event)

# === MIGRATED CAMERA MODE CONTROL ===

func toggle_camera_mode():
	"""MIGRATED: Smart camera mode toggling based on CCC configuration"""
	if not can_switch_camera_mode():
		print("🚫 CCC_CameraManager: Camera mode switching disabled for current camera type")
		return
	
	# Apply camera type-specific toggling logic
	match current_camera_type:
		CameraType.ORBITAL:
			toggle_orbital_mode()
		CameraType.CONTEXTUAL:
			toggle_contextual_mode()
		_:
			print("🚫 CCC_CameraManager: Camera mode switching not available for ", CameraType.keys()[current_camera_type])

func toggle_orbital_mode():
	"""Toggle between orbit and click navigation for orbital camera"""
	if not camera_controller:
		return
	
	if camera_controller.mode_switch_cooldown > 0:
		return
	
	var new_mode
	match camera_controller.current_mode:
		CameraController.CameraMode.ORBIT:
			new_mode = CameraController.CameraMode.CLICK_NAVIGATION
		CameraController.CameraMode.CLICK_NAVIGATION:
			new_mode = CameraController.CameraMode.ORBIT
	
	set_camera_mode_internal(new_mode)
	camera_controller.mode_switch_cooldown = camera_controller.mode_switch_delay
	
	print("📹 CCC_CameraManager: Toggled camera mode via orbital camera type")

func toggle_contextual_mode():
	"""Toggle camera mode based on context (future implementation)"""
	# TODO: Implement contextual camera mode switching
	toggle_orbital_mode()  # Fallback to orbital for now

func set_camera_mode_internal(mode):
	"""MIGRATED: Set camera mode with CCC enhancements"""
	if not camera_controller:
		return
	
	if camera_controller.current_mode == mode:
		return
	
	var old_mode_name = camera_controller.get_mode_name(camera_controller.current_mode)
	camera_controller.current_mode = mode
	var new_mode_name = camera_controller.get_mode_name(camera_controller.current_mode)
	
	# Apply camera type-specific behavior
	apply_camera_type_behavior(mode)
	
	# Emit signals
	camera_controller.camera_mode_changed.emit(new_mode_name)
	camera_controller.mouse_mode_changed.emit(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	
	print("📹 CCC_CameraManager: Camera mode changed from ", old_mode_name, " to ", new_mode_name)

func apply_camera_type_behavior(mode):
	"""Apply camera type-specific behavior when switching modes"""
	var config = camera_configs.get(current_camera_type, {})
	
	match mode:
		CameraController.CameraMode.ORBIT:
			if config.get("mouse_capture_in_orbit", true):
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			print("📹 CCC_CameraManager: Applied ", CameraType.keys()[current_camera_type], " behavior for ORBIT mode")
		
		CameraController.CameraMode.CLICK_NAVIGATION:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			print("📹 CCC_CameraManager: Applied ", CameraType.keys()[current_camera_type], " behavior for CLICK_NAVIGATION mode")

# === SIGNAL PASSTHROUGH HANDLERS ===

func _on_camera_mode_changed(mode: String):
	camera_mode_changed.emit(mode)

func _on_mouse_mode_changed(captured: bool):
	mouse_mode_changed.emit(captured)

func _on_target_lost():
	target_lost.emit()

func _on_target_acquired(target: Node3D):
	target_acquired.emit(target)

# === CAMERA CONTROL METHODS (Enhanced) ===

func set_camera_mode(mode):
	"""Set camera mode through enhanced CCC logic"""
	if camera_logic_migrated:
		set_camera_mode_internal(mode)
	elif camera_controller:
		camera_controller.set_camera_mode(mode)

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

func can_switch_camera_mode() -> bool:
	"""Check if camera mode switching is allowed for current camera type"""
	var config = camera_configs.get(current_camera_type, {})
	return config.get("allows_mode_switching", false)

# === TARGET MANAGEMENT (Unchanged) ===

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

# === CAMERA PROPERTIES (Enhanced with camera type configs) ===

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

func apply_camera_type_defaults():
	"""Apply default settings for current camera type"""
	var config = camera_configs.get(current_camera_type, {})
	
	if config.has("default_distance"):
		set_follow_distance(config.default_distance)
	
	if config.has("default_fov"):
		set_fov(config.default_fov)
	
	print("📹 CCC_CameraManager: Applied defaults for ", CameraType.keys()[current_camera_type])

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

# === CCC CAMERA INTERFACE (Enhanced) ===

func configure_camera_type(camera_type: CameraType):
	"""Configure the camera type with full implementation"""
	var old_type = current_camera_type
	current_camera_type = camera_type
	
	print("📷 CCC_CameraManager: Camera type changed from ", CameraType.keys()[old_type], " to ", CameraType.keys()[camera_type])
	
	# Apply camera type configuration
	apply_camera_type_defaults()
	
	# Update behavior based on camera type
	var config = camera_configs.get(camera_type, {})
	custom_mode_switching_enabled = config.get("allows_mode_switching", false)
	
	# Apply immediate changes
	match camera_type:
		CameraType.ORBITAL:
			print("   → Orbital camera: Manual control with mode switching")
		CameraType.FOLLOWING:
			print("   → Following camera: Auto-follow, no manual control")
			if is_in_orbit_mode():
				set_camera_mode(CameraController.CameraMode.CLICK_NAVIGATION)
		CameraType.FIXED:
			print("   → Fixed camera: Static positioning")
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func set_information_clarity(clarity: float):
	"""Set how clearly the camera communicates spatial information"""
	# Adjust FOV and distance based on clarity
	var base_fov = camera_configs.get(current_camera_type, {}).get("default_fov", 75.0)
	var base_distance = camera_configs.get(current_camera_type, {}).get("default_distance", 4.0)
	
	# Higher clarity = wider FOV and further distance
	set_fov(base_fov + (clarity * 15.0))
	set_follow_distance(base_distance + (clarity * 2.0))
	
	print("📷 CCC_CameraManager: Information clarity set to ", clarity)

func set_comfort_level(comfort: float):
	"""Set camera comfort (motion sickness prevention)"""
	# Adjust smoothing and FOV for comfort
	var base_smoothing = 8.0
	var comfort_smoothing = base_smoothing + (comfort * 4.0)
	
	if camera_controller:
		camera_controller.follow_smoothing = comfort_smoothing
		camera_controller.distance_smoothing = comfort_smoothing
		camera_controller.fov_smoothing = comfort_smoothing
	
	print("📷 CCC_CameraManager: Comfort level set to ", comfort)

# === DEBUG INFO (Enhanced) ===

func get_debug_info() -> Dictionary:
	"""Get enhanced debug information"""
	var debug_data = {
		"camera_type": CameraType.keys()[current_camera_type],
		"migration_status": "camera_control_migrated" if camera_logic_migrated else "legacy",
		"mode_switching_enabled": custom_mode_switching_enabled,
		"can_switch_mode": can_switch_camera_mode()
	}
	
	if camera_controller:
		debug_data.merge({
			"current_mode": camera_controller.get_mode_name(camera_controller.current_mode),
			"target": get_target().name if get_target() else "none",
			"distance": get_follow_distance(),
			"fov": get_fov(),
			"enabled": is_camera_enabled(),
			"external_control": is_externally_controlled(),
			"camera_config": camera_configs.get(current_camera_type, {})
		})
	else:
		debug_data["camera_controller"] = "missing"
	
	return debug_data
