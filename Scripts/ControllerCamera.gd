# ControllerCamera.gd - Camera with offset system
extends Node3D

signal mouse_mode_changed(is_captured: bool)

@export_group("Target & Following")
@export var target_character: CharacterBody3D
@export var camera_height = 2.0
@export var follow_smoothing = 8.0

@export_group("Camera Offset")
@export var camera_offset = Vector3.ZERO  # NEW: Offset camera within SpringArm
@export var offset_smoothing = 8.0
@export var enable_dynamic_offset = false  # Adjust offset based on movement

@export_group("Mouse Controls")
@export var mouse_sensitivity = 0.002
@export var enable_mouse_yaw = true
@export var enable_mouse_pitch = true

@export_group("Camera Distance")
@export var enable_scroll_zoom = true
@export var min_distance = 1.0
@export var max_distance = 10.0
@export var scroll_speed = 0.5
@export var distance_smoothing = 8.0

@export_group("Rotation Limits")
@export var vertical_limit_min = -80.0
@export var vertical_limit_max = 50.0

@export_group("State Integration") 
@export var enable_state_overrides = true
@export var state_override_smoothing = 6.0

@onready var spring_arm = $SpringArm3D
@onready var camera = $SpringArm3D/Camera3D


var character: CharacterBody3D
var mouse_delta = Vector2.ZERO
var camera_rotation_x = 0.0
var is_mouse_captured = true
var target_distance = 4.0
var current_distance = 4.0
var current_offset = Vector3.ZERO

var base_target_distance = 4.0  # Store original distance
var is_state_controlled = false

func _ready():
	character = target_character
	if not character:
		push_error("No target character assigned to camera!")
		return
	
	# Start in mouse capture mode
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	is_mouse_captured = true
	
	# Initialize camera
	camera_rotation_x = deg_to_rad(-20.0)
	target_distance = spring_arm.spring_length
	current_distance = target_distance
	current_offset = camera_offset
	
	if character:
		global_position = character.global_position + Vector3(0, camera_height, 0)
	
	# Store base values for state system
	base_target_distance = target_distance
	
	
func _input(event):
	# Camera-specific inputs
	if event.is_action_pressed("toggle_mouse_look"):
		toggle_mouse_mode()
	
	# Mouse look when captured
	if is_mouse_captured and event is InputEventMouseMotion:
		mouse_delta = event.relative
	
	# Zoom control
	if enable_scroll_zoom and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			target_distance = clamp(target_distance - scroll_speed, min_distance, max_distance)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			target_distance = clamp(target_distance + scroll_speed, min_distance, max_distance)

func toggle_mouse_mode():
	is_mouse_captured = !is_mouse_captured
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if is_mouse_captured else Input.MOUSE_MODE_VISIBLE
	mouse_mode_changed.emit(is_mouse_captured)

func _physics_process(delta):
	if not character:
		return
	
	# Handle mouse look rotation only when captured
	if is_mouse_captured and mouse_delta.length() > 0:
		if enable_mouse_yaw:
			rotation.y -= mouse_delta.x * mouse_sensitivity
		
		if enable_mouse_pitch:
			camera_rotation_x -= mouse_delta.y * mouse_sensitivity
			camera_rotation_x = clamp(camera_rotation_x, 
				deg_to_rad(vertical_limit_min), 
				deg_to_rad(vertical_limit_max))
		
		mouse_delta = Vector2.ZERO
	
	# Follow character (SpringArm pivot stays at character center)
	var target_position = character.global_position + Vector3(0, camera_height, 0)
	global_position = global_position.lerp(target_position, follow_smoothing * delta)
	
	# Update SpringArm distance and rotation
	current_distance = lerp(current_distance, target_distance, distance_smoothing * delta)
	spring_arm.spring_length = current_distance
	spring_arm.rotation.x = camera_rotation_x
	
	# NEW: Apply camera offset by offsetting the SpringArm itself
	var target_offset = camera_offset
	
	# Optional: Dynamic offset based on character movement
	if enable_dynamic_offset and character.velocity.length() > 0.1:
		var movement_dir = Vector2(character.velocity.x, character.velocity.z).normalized()
		# Slightly offset camera opposite to movement direction
		target_offset += Vector3(movement_dir.x * 0.3, 0, movement_dir.y * 0.3)
	
	# Smoothly apply offset
	current_offset = current_offset.lerp(target_offset, offset_smoothing * delta)
	
	# Apply offset to SpringArm (not camera directly)
	if spring_arm:
		spring_arm.position = current_offset
		
	# NEW: Handle state-based overrides (if enabled)
	if enable_state_overrides:
		handle_state_overrides(delta)

func get_camera() -> Camera3D:
	return camera

# === PUBLIC API FOR OFFSET CONTROL ===

func set_camera_offset(new_offset: Vector3, transition_time: float = 1.0):
	"""Change camera offset smoothly"""
	camera_offset = new_offset
	print("Camera: Setting offset to ", new_offset)

func set_over_shoulder_left(strength: float = 1.0):
	"""Quick setup for left shoulder view"""
	set_camera_offset(Vector3(-0.8 * strength, 0.2 * strength, 0.3 * strength))

func set_over_shoulder_right(strength: float = 1.0):
	"""Quick setup for right shoulder view"""
	set_camera_offset(Vector3(0.8 * strength, 0.2 * strength, 0.3 * strength))

func set_centered_view():
	"""Return to centered view"""
	set_camera_offset(Vector3.ZERO)

func set_combat_offset(target_enemy: Node3D):
	"""Adjust offset to better frame character and enemy"""
	if target_enemy and character:
		var to_enemy = (target_enemy.global_position - character.global_position).normalized()
		var side_offset = Vector3(to_enemy.z, 0, -to_enemy.x) * 0.6  # Perpendicular to enemy direction
		set_camera_offset(side_offset + Vector3(0, 0.3, 0.2))
		
		
# === ADD THESE NEW METHODS ===

func handle_state_overrides(delta):
	"""Handle camera property overrides from state system"""
	# This will be called by CameraStateComponent or can check for it
	pass  # CameraStateComponent handles transitions directly

func set_state_fov(new_fov: float, transition_speed: float = 2.0):
	"""Set FOV from state system"""
	if camera and enable_state_overrides:
		# CameraStateComponent handles the smooth transition
		is_state_controlled = true

func set_state_distance(new_distance: float, transition_speed: float = 2.0):
	"""Set camera distance from state system"""
	if enable_state_overrides:
		target_distance = new_distance
		is_state_controlled = true

func reset_to_base_values():
	"""Reset camera to base values (exit state control)"""
	if is_state_controlled:
		target_distance = base_target_distance
		if camera:
			camera.fov = 75.0  # Default FOV
		is_state_controlled = false

# === ADD THESE PROPERTIES FOR STATE SYSTEM ACCESS ===
func get_current_distance() -> float:
	"""Get current camera distance for state transitions"""
	return current_distance

func get_current_fov() -> float:
	"""Get current FOV for state transitions"""
	return camera.fov if camera else 75.0

# === DEBUG INFO UPDATE - ADD TO EXISTING OR CREATE NEW ===
func get_camera_debug_info() -> Dictionary:
	return {
		"target_distance": target_distance,
		"current_distance": current_distance,
		"is_state_controlled": is_state_controlled,
		"current_fov": camera.fov if camera else 0.0,
		"mouse_captured": is_mouse_captured
	}
