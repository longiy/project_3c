# ControllerCamera.gd - Simplified without InputManager
extends Node3D

@export_group("Target & Following")
@export var target_character: CharacterBody3D ## Drag your character here
@export var camera_height = 2.0 ## Height offset above character
@export var follow_smoothing = 8.0 ## How smoothly camera follows character position

@export_group("Mouse Controls")
@export var mouse_sensitivity = 0.002 ## Mouse look sensitivity
@export var enable_mouse_yaw = true ## Enable/disable horizontal mouse rotation
@export var enable_mouse_pitch = true ## Enable/disable vertical mouse rotation

@export_group("Rotation Limits")
@export var vertical_limit_min = -80.0 ## Minimum vertical look angle (degrees)
@export var vertical_limit_max = 50.0 ## Maximum vertical look angle (degrees)

@onready var spring_arm = $SpringArm3D

var character: CharacterBody3D
var mouse_delta = Vector2.ZERO
var camera_rotation_x = 0.0
var is_mouse_captured = true

func _ready():
	# Get character reference
	character = target_character
	if not character:
		push_error("No target character assigned to camera!")
		return
	
	# Start in mouse capture mode
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	print("Camera: Using simplified input system")
	
	# Set initial camera rotation
	camera_rotation_x = deg_to_rad(-20.0)
	
	# Position camera system initially at character
	if character:
		global_position = character.global_position + Vector3(0, camera_height, 0)

func _input(event):
	# Mouse capture toggle
	if event.is_action_pressed("toggle_mouse_look"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			is_mouse_captured = false
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			is_mouse_captured = true
		
		# Notify InputComponent about mode change
		if character:
			var input_component = character.get_node("InputComponent")
			if input_component:
				input_component.on_mouse_mode_changed(is_mouse_captured)
	
	# Mouse movement for camera
	if is_mouse_captured and event is InputEventMouseMotion:
		mouse_delta = event.relative

func _physics_process(delta):
	if not character:
		return
	
	# Handle mouse look rotation only when captured
	if is_mouse_captured and mouse_delta.length() > 0:
		# Horizontal rotation (Y-axis)
		if enable_mouse_yaw:
			rotation.y -= mouse_delta.x * mouse_sensitivity
		
		# Vertical rotation (X-axis)
		if enable_mouse_pitch:
			camera_rotation_x -= mouse_delta.y * mouse_sensitivity
			camera_rotation_x = clamp(camera_rotation_x, 
				deg_to_rad(vertical_limit_min), 
				deg_to_rad(vertical_limit_max))
		
		mouse_delta = Vector2.ZERO
	
	# Position the camera system at character with height offset
	var target_position = character.global_position + Vector3(0, camera_height, 0)
	global_position = global_position.lerp(target_position, follow_smoothing * delta)
	
	# Apply vertical rotation to SpringArm
	spring_arm.rotation.x = camera_rotation_x

func get_camera() -> Camera3D:
	return $SpringArm3D/Camera3D
