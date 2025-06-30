# Camera3CManager.gd - Camera Axis with 3C Configuration
extends Node3D
class_name Camera3CManager

enum CameraMode { ORBIT, CLICK_NAVIGATION, FIXED, FIRST_PERSON, RESPONSIVE }

# === SIGNALS ===
signal mode_changed(new_mode: CameraMode)

# === 3C CONFIGURATION ===
var active_3c_config: CharacterConfig

# === CAMERA COMPONENTS ===
@export var camera: Camera3D
@export var target: Node3D

# === CAMERA STATE ===
var current_mode: CameraMode = CameraMode.ORBIT
var camera_offset: Vector3
var target_distance: float = 4.0
var target_height: float = 2.0
var follow_smoothing: float = 8.0
var default_fov: float = 75.0

# === ORBIT CONTROLS ===
var orbit_sensitivity: float = 1.0
var zoom_sensitivity: float = 1.0
var min_distance: float = 2.0
var max_distance: float = 10.0
var orbit_speed: float = 2.0

# === CAMERA TWEENS ===
var camera_tween: Tween

func _ready():
	setup_camera()
	setup_initial_position()

func setup_camera():
	"""Initialize camera setup"""
	if not camera:
		camera = get_node_or_null("Camera3D")
		if not camera:
			push_error("No Camera3D found in Camera3CManager")
			return
	
	if not target:
		target = get_parent().get_node_or_null("CHARACTER")
		if not target:
			push_warning("No target found for camera")

func setup_initial_position():
	"""Set initial camera position"""
	if target and camera:
		camera_offset = Vector3(0, target_height, target_distance)
		update_camera_position()

func configure_from_3c(config: CharacterConfig):
	"""Configure camera behavior based on 3C settings"""
	active_3c_config = config
	
	# Apply camera parameters
	target_distance = config.camera_distance
	target_height = config.camera_height
	follow_smoothing = config.camera_smoothing
	default_fov = config.camera_fov
	orbit_sensitivity = config.mouse_sensitivity
	orbit_speed = config.orbit_speed
	zoom_sensitivity = config.zoom_speed
	
	# Set camera mode based on camera type
	match config.camera_type:
		CharacterConfig.CameraType.ORBITAL:
			set_camera_mode(CameraMode.ORBIT)
		CharacterConfig.CameraType.FOLLOWING:
			set_camera_mode(CameraMode.CLICK_NAVIGATION)
		CharacterConfig.CameraType.FIXED:
			set_camera_mode(CameraMode.FIXED)
		CharacterConfig.CameraType.FIRST_PERSON:
			set_camera_mode(CameraMode.FIRST_PERSON)
		CharacterConfig.CameraType.RESPONSIVE:
			set_camera_mode(CameraMode.RESPONSIVE)
	
	# Apply FOV
	if camera:
		camera.fov = default_fov

func set_camera_mode(new_mode: CameraMode):
	"""Switch camera mode with smooth transition"""
	if current_mode == new_mode:
		return
	
	var old_mode = current_mode
	current_mode = new_mode
	
	# Configure mode-specific settings
	match current_mode:
		CameraMode.ORBIT:
			setup_orbit_mode()
		CameraMode.CLICK_NAVIGATION:
			setup_click_navigation_mode()
		CameraMode.FIXED:
			setup_fixed_mode()
		CameraMode.FIRST_PERSON:
			setup_first_person_mode()
		CameraMode.RESPONSIVE:
			setup_responsive_mode()
	
	mode_changed.emit(current_mode)
	print("Camera mode changed from ", CameraMode.keys()[old_mode], " to ", CameraMode.keys()[current_mode])

func setup_orbit_mode():
	"""Configure orbit camera mode"""
	# Free orbit around target
	pass

func setup_click_navigation_mode():
	"""Configure click navigation camera mode"""
	# Following camera for click-to-move
	pass

func setup_fixed_mode():
	"""Configure fixed camera mode"""
	# Static camera position
	pass

func setup_first_person_mode():
	"""Configure first person camera mode"""
	# Camera attached to character
	pass

func setup_responsive_mode():
	"""Configure responsive camera mode"""
	# Dynamic camera that adapts to context
	pass

func _input(event):
	if not active_3c_config:
		return
	
	match current_mode:
		CameraMode.ORBIT:
			handle_orbit_input(event)
		CameraMode.CLICK_NAVIGATION:
			handle_click_navigation_input(event)

func handle_orbit_input(event):
	"""Handle input for orbit camera mode"""
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var mouse_delta = event.relative * orbit_sensitivity * 0.001
		rotate_camera_around_target(-mouse_delta.x, -mouse_delta.y)
	
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_camera(-zoom_sensitivity)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_camera(zoom_sensitivity)

func handle_click_navigation_input(event):
	"""Handle input for click navigation camera mode"""
	# Mouse wheel zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_camera(-zoom_sensitivity)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_camera(zoom_sensitivity)

func rotate_camera_around_target(horizontal: float, vertical: float):
	"""Rotate camera around target"""
	if not target or not camera:
		return
	
	# Horizontal rotation (around Y axis)
	global_transform.origin = target.global_position
	rotate_y(horizontal * orbit_speed)
	
	# Vertical rotation (limited)
	var vertical_angle = vertical * orbit_speed
	var current_angle = asin(camera_offset.normalized().y)
	var target_angle = clamp(current_angle + vertical_angle, -PI/3, PI/3)
	
	# Apply vertical rotation
	var horizontal_distance = sqrt(camera_offset.x * camera_offset.x + camera_offset.z * camera_offset.z)
	camera_offset.y = sin(target_angle) * target_distance
	var new_horizontal_distance = cos(target_angle) * target_distance
	camera_offset = camera_offset.normalized() * Vector3(new_horizontal_distance, camera_offset.y, new_horizontal_distance)

func zoom_camera(zoom_delta: float):
	"""Zoom camera in/out"""
	target_distance = clamp(target_distance + zoom_delta, min_distance, max_distance)
	camera_offset = camera_offset.normalized() * target_distance

func _process(delta):
	if active_3c_config:
		update_camera_position(delta)

func update_camera_position(delta: float = 0.0):
	"""Update camera position based on current mode"""
	if not target or not camera:
		return
	
	match current_mode:
		CameraMode.ORBIT:
			update_orbit_camera(delta)
		CameraMode.CLICK_NAVIGATION:
			update_following_camera(delta)
		CameraMode.FIXED:
			update_fixed_camera(delta)
		CameraMode.FIRST_PERSON:
			update_first_person_camera(delta)
		CameraMode.RESPONSIVE:
			update_responsive_camera(delta)

func update_orbit_camera(delta: float):
	"""Update orbit camera position"""
	var target_position = target.global_position + camera_offset
	
	if delta > 0:
		camera.global_position = camera.global_position.lerp(target_position, follow_smoothing * delta)
	else:
		camera.global_position = target_position
	
	camera.look_at(target.global_position + Vector3.UP, Vector3.UP)

func update_following_camera(delta: float):
	"""Update following camera position"""
	var target_position = target.global_position + Vector3(0, target_height, target_distance)
	
	if delta > 0:
		camera.global_position = camera.global_position.lerp(target_position, follow_smoothing * delta)
	else:
		camera.global_position = target_position
	
	camera.look_at(target.global_position + Vector3.UP, Vector3.UP)

func update_fixed_camera(delta: float):
	"""Update fixed camera (minimal movement)"""
	# Fixed cameras generally don't move, but might have slight adjustments
	pass

func update_first_person_camera(delta: float):
	"""Update first person camera"""
	if target:
		camera.global_position = target.global_position + Vector3(0, 1.7, 0)  # Eye height
		# First person cameras typically don't auto-rotate

func update_responsive_camera(delta: float):
	"""Update responsive camera based on context"""
	# Adaptive camera behavior based on character state and 3C config
	var responsiveness = active_3c_config.character_responsiveness if active_3c_config else 1.0
	var adaptive_smoothing = follow_smoothing * responsiveness
	
	var target_position = target.global_position + camera_offset
	camera.global_position = camera.global_position.lerp(target_position, adaptive_smoothing * delta)
	camera.look_at(target.global_position + Vector3.UP, Vector3.UP)

# === CAMERA EFFECTS ===

func add_camera_shake(intensity: float, duration: float):
	"""Add camera shake effect"""
	if camera_tween:
		camera_tween.kill()
	
	camera_tween = create_tween()
	camera_tween.set_loops(int(duration * 30))  # 30 shakes per second
	
	var original_position = camera.global_position
	camera_tween.tween_callback(func(): 
		var shake_offset = Vector3(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		camera.global_position = original_position + shake_offset
	).set_delay(1.0 / 30.0)
	
	camera_tween.tween_callback(func(): camera.global_position = original_position).set_delay(duration)

func smooth_fov_transition(target_fov: float, duration: float = 0.5):
	"""Smoothly transition FOV"""
	if camera_tween:
		camera_tween.kill()
	
	camera_tween = create_tween()
	camera_tween.tween_property(camera, "fov", target_fov, duration)

func smooth_distance_transition(new_distance: float, duration: float = 1.0):
	"""Smoothly transition camera distance"""
	if camera_tween:
		camera_tween.kill()
	
	camera_tween = create_tween()
	camera_tween.tween_method(
		func(distance): 
			target_distance = distance
			camera_offset = camera_offset.normalized() * target_distance,
		target_distance,
		new_distance,
		duration
	)

# === UTILITY FUNCTIONS ===

func get_current_mode() -> CameraMode:
	return current_mode

func get_mode_name(mode: CameraMode) -> String:
	return CameraMode.keys()[mode]

func toggle_camera_mode():
	"""Toggle between orbit and click navigation modes"""
	if current_mode == CameraMode.ORBIT:
		set_camera_mode(CameraMode.CLICK_NAVIGATION)
	else:
		set_camera_mode(CameraMode.ORBIT)

func is_camera_moving() -> bool:
	"""Check if camera is currently in motion"""
	return camera_tween != null and camera_tween.is_valid()

func get_camera_info() -> Dictionary:
	"""Get debug information about camera state"""
	return {
		"mode": get_mode_name(current_mode),
		"distance": target_distance,
		"height": target_height,
		"fov": camera.fov if camera else 0,
		"smoothing": follow_smoothing,
		"position": camera.global_position if camera else Vector3.ZERO,
		"is_moving": is_camera_moving()
	}
