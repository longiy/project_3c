# CameraRig.gd - 3C Framework Integration
extends Node3D
class_name CameraRig

# === SIGNALS ===
signal camera_mode_changed(mode: String)
signal mouse_mode_changed(captured: bool)
signal target_lost()
signal target_acquired(target: Node3D)

# === EXPORTS ===
@export_group("Target Following")
@export var target_node: Node3D
@export var follow_height_offset = 1.6
@export var follow_smoothing = 8.0

@export_group("Mouse Look")
@export var mouse_sensitivity = 0.002
@export var invert_y = false

@export_group("Rotation Limits")
@export var pitch_limit_min = -80.0
@export var pitch_limit_max = 50.0

@export_group("Camera Distance")
@export var default_distance = 4.0
@export var min_distance = 1.0
@export var max_distance = 10.0
@export var distance_smoothing = 8.0
@export var scroll_zoom_speed = 0.5

@export_group("Camera Properties")
@export var default_fov = 75.0
@export var fov_smoothing = 5.0

@export_group("State Response Values")
@export var idle_fov = 50.0
@export var idle_distance = 4.0
@export var walking_fov = 60.0
@export var walking_distance = 4.0
@export var running_fov = 70.0
@export var running_distance = 4.5
@export var jumping_fov = 85.0
@export var jumping_distance = 4.8
@export var airborne_fov = 90.0
@export var airborne_distance = 5.0
@export var landing_fov = 75.0
@export var landing_distance = 4.0

@export_group("Control Modes")
@export var enable_camera_rig = true

# === CAMERA MODES ===
enum CameraMode {
	ORBIT,              # Default: Mouse orbits camera, WASD moves character
	CLICK_NAVIGATION    # Mouse2 toggle: Cursor visible, click to move
}

var current_mode: CameraMode = CameraMode.ORBIT

# === INTERNAL STATE ===
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

var character_state_machine: CharacterStateMachine

# Camera transform state
var camera_rotation_x = 0.0  # Pitch
var camera_rotation_y = 0.0  # Yaw

# Target following
var target_position = Vector3.ZERO

# Camera properties
var current_distance = 4.0
var target_distance = 4.0
var current_fov = 75.0
var target_fov = 75.0

func _ready():
	if not enable_camera_rig:
		set_process(false)
		set_physics_process(false)
		return
	
	current_distance = default_distance
	target_distance = default_distance
	current_fov = default_fov
	target_fov = default_fov
	
	setup_camera()
	setup_character_connection()

func setup_camera():
	if spring_arm:
		spring_arm.spring_length = current_distance
	
	if camera:
		camera.fov = current_fov

func setup_character_connection():
	character_state_machine = get_node_or_null("../CHARACTER/CharacterStateMachine") as CharacterStateMachine
	if character_state_machine:
		character_state_machine.state_changed_for_camera.connect(_on_character_state_changed)
		print("✅ CameraRig: Connected to CharacterStateMachine")
	else:
		print("⚠️ CameraRig: No CharacterStateMachine found")

# === 3C CONFIGURATION ===

func configure_from_3c(config: CharacterConfig):
	"""Apply 3C configuration to camera parameters"""
	default_distance = config.camera_distance
	follow_smoothing = config.camera_smoothing
	default_fov = config.camera_fov
	mouse_sensitivity = config.mouse_sensitivity
	follow_height_offset = config.follow_height_offset
	
	# Apply state-specific values
	idle_fov = config.idle_fov
	idle_distance = config.idle_distance
	walking_fov = config.walking_fov
	walking_distance = config.walking_distance
	running_fov = config.running_fov
	running_distance = config.running_distance
	jumping_fov = config.jumping_fov
	jumping_distance = config.jumping_distance
	
	# Update current values
	target_distance = default_distance
	target_fov = default_fov
	
	# Apply camera type behavior
	match config.camera_type:
		CharacterConfig.CameraType.ORBITAL:
			setup_orbital_camera()
		CharacterConfig.CameraType.FOLLOWING:
			setup_following_camera()
		CharacterConfig.CameraType.FIXED:
			setup_fixed_camera()
		CharacterConfig.CameraType.FIRST_PERSON:
			setup_first_person_camera()
	
	print("🎮 CameraRig: 3C config applied - ", CharacterConfig.CameraType.keys()[config.camera_type], " mode")

func setup_orbital_camera():
	"""Configure for orbital camera behavior (your current default)"""
	current_mode = CameraMode.ORBIT
	# Your existing orbital behavior - no changes needed

func setup_following_camera():
	"""Configure for following camera behavior (like Diablo)"""
	# More stable, less mouse influence
	follow_smoothing *= 1.5
	mouse_sensitivity *= 0.7

func setup_fixed_camera():
	"""Configure for fixed camera behavior (like RTS)"""
	# Very stable, minimal mouse influence
	follow_smoothing *= 2.0
	mouse_sensitivity *= 0.3

func setup_first_person_camera():
	"""Configure for first person behavior"""
	target_distance = 0.1  # Very close
	mouse_sensitivity *= 1.2

func _physics_process(delta):
	if not enable_camera_rig:
		return
	
	handle_mouse_input()
	update_target_following(delta)
	update_camera_properties(delta)

func handle_mouse_input():
	if current_mode == CameraMode.ORBIT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mouse_delta = Input.get_last_mouse_velocity() * 0.001
		
		camera_rotation_y -= mouse_delta.x * mouse_sensitivity
		camera_rotation_x -= mouse_delta.y * mouse_sensitivity * (1.0 if not invert_y else -1.0)
		
		camera_rotation_x = clamp(camera_rotation_x, deg_to_rad(pitch_limit_min), deg_to_rad(pitch_limit_max))
		
		rotation = Vector3(camera_rotation_x, camera_rotation_y, 0)

func update_target_following(delta):
	if target_node:
		var target_pos = target_node.global_position + Vector3.UP * follow_height_offset
		global_position = global_position.lerp(target_pos, follow_smoothing * delta)

func update_camera_properties(delta):
	# Smooth distance changes
	current_distance = lerp(current_distance, target_distance, distance_smoothing * delta)
	if spring_arm:
		spring_arm.spring_length = current_distance
	
	# Smooth FOV changes
	current_fov = lerp(current_fov, target_fov, fov_smoothing * delta)
	if camera:
		camera.fov = current_fov

# === CHARACTER STATE RESPONSES ===

func _on_character_state_changed(state_name: String):
	"""Respond to character state changes"""
	match state_name:
		"idle":
			set_camera_state(idle_fov, idle_distance)
		"walking":
			set_camera_state(walking_fov, walking_distance)
		"running":
			set_camera_state(running_fov, running_distance)
		"jumping":
			set_camera_state(jumping_fov, jumping_distance)
		"airborne":
			set_camera_state(airborne_fov, airborne_distance)
		"landing":
			set_camera_state(landing_fov, landing_distance)

func set_camera_state(fov: float, distance: float):
	"""Set target camera properties for a state"""
	target_fov = fov
	target_distance = distance

# === MODE SWITCHING ===

func set_camera_mode(mode: CameraMode):
	if current_mode != mode:
		current_mode = mode
		camera_mode_changed.emit(CameraMode.keys()[mode])
		
		match mode:
			CameraMode.ORBIT:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				mouse_mode_changed.emit(true)
			CameraMode.CLICK_NAVIGATION:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				mouse_mode_changed.emit(false)

func is_in_click_navigation_mode() -> bool:
	return current_mode == CameraMode.CLICK_NAVIGATION

# === INPUT HANDLING ===

func _input(event):
	if not enable_camera_rig:
		return
	
	if event.is_action_pressed("camera_toggle"):
		toggle_camera_mode()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_in()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_out()

func toggle_camera_mode():
	match current_mode:
		CameraMode.ORBIT:
			set_camera_mode(CameraMode.CLICK_NAVIGATION)
		CameraMode.CLICK_NAVIGATION:
			set_camera_mode(CameraMode.ORBIT)

func zoom_in():
	target_distance = max(target_distance - scroll_zoom_speed, min_distance)

func zoom_out():
	target_distance = min(target_distance + scroll_zoom_speed, max_distance)

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	return {
		"mode": CameraMode.keys()[current_mode],
		"current_distance": current_distance,
		"target_distance": target_distance,
		"current_fov": current_fov,
		"target_fov": target_fov,
		"mouse_sensitivity": mouse_sensitivity,
		"follow_smoothing": follow_smoothing
	}
