# ControllerCamera.gd - Only handles camera-specific inputs
extends Node3D

signal mouse_mode_changed(is_captured: bool)

@export_group("Target & Following")
@export var target_character: CharacterBody3D
@export var camera_height = 2.0
@export var follow_smoothing = 8.0

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

@onready var spring_arm = $SpringArm3D

var character: CharacterBody3D
var mouse_delta = Vector2.ZERO
var camera_rotation_x = 0.0
var is_mouse_captured = true
var target_distance = 4.0
var current_distance = 4.0

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
	
	if character:
		global_position = character.global_position + Vector3(0, camera_height, 0)

func _input(event):
	# ONLY handle camera-specific inputs
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
	
	# Follow character
	var target_position = character.global_position + Vector3(0, camera_height, 0)
	global_position = global_position.lerp(target_position, follow_smoothing * delta)
	
	# Update distance and rotation
	current_distance = lerp(current_distance, target_distance, distance_smoothing * delta)
	spring_arm.spring_length = current_distance
	spring_arm.rotation.x = camera_rotation_x

func get_camera() -> Camera3D:
	return $SpringArm3D/Camera3D
