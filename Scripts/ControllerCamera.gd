# ControllerCamera.gd - Enhanced with composition and limits
extends Node3D

@export_group("Target & Following")
@export var target_character: CharacterBody3D ## Drag your character here
@export var camera_height = 2.0 ## Height offset above character
@export var follow_smoothing = 8.0 ## How smoothly camera follows character position

@export_group("Mouse Controls")
@export var mouse_sensitivity = 0.002 ## Mouse look sensitivity
@export var enable_mouse_yaw = true ## Enable/disable horizontal mouse rotation
@export var enable_mouse_pitch = true ## Enable/disable vertical mouse rotation

@export_group("Camera Distance")
@export var enable_scroll_zoom = true ## Enable mouse wheel zoom control
@export var min_distance = 1.0 ## Minimum camera distance
@export var max_distance = 10.0 ## Maximum camera distance
@export var scroll_speed = 0.5 ## How fast scrolling changes distance
@export var distance_smoothing = 8.0 ## How smoothly distance changes

@export_group("Rotation Limits")
@export var vertical_limit_min = -80.0 ## Minimum vertical look angle (degrees)
@export var vertical_limit_max = 50.0 ## Maximum vertical look angle (degrees)
@export var enable_horizontal_limits = false ## Enable/disable horizontal rotation limits
@export var horizontal_limit_min = -90.0 ## Minimum horizontal look angle (degrees)
@export var horizontal_limit_max = 90.0 ## Maximum horizontal look angle (degrees)

@export_group("Composition & Framing")
@export var camera_composition_offset = Vector3(0, 0.5, 0) ## Offset for composition (doesn't affect follow height)
@export var wall_composition_offset = Vector3(0, -1, 0) ## Offset when near walls to keep character visible
@export var offset_scale_with_collision = true ## Scale composition offset based on collision distance
@export var offset_smoothing = 8.0 ## How smoothly offset scales with collision

@onready var spring_arm = $SpringArm3D

var character: CharacterBody3D
var mouse_delta = Vector2.ZERO
var camera_rotation_x = 0.0
var is_mouse_captured = true
var current_offset_scale = 1.0

# Distance control
var target_distance = 4.0
var current_distance = 4.0

func _ready():
	# Get character reference
	character = target_character
	if not character:
		push_error("No target character assigned to camera!")
		return
	
	# Start in mouse capture mode
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	print("Camera: Using enhanced camera system")
	
	# Set initial camera rotation
	camera_rotation_x = deg_to_rad(-20.0)
	
	# Initialize distance
	target_distance = spring_arm.spring_length
	current_distance = target_distance
	
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
	
	# Mouse wheel zoom control
	if enable_scroll_zoom and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			target_distance = clamp(target_distance - scroll_speed, min_distance, max_distance)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			target_distance = clamp(target_distance + scroll_speed, min_distance, max_distance)

func _physics_process(delta):
	if not character:
		return
	
	# Handle mouse look rotation only when captured
	if is_mouse_captured and mouse_delta.length() > 0:
		# Horizontal rotation (Y-axis)
		if enable_mouse_yaw:
			rotation.y -= mouse_delta.x * mouse_sensitivity
			
			# Apply horizontal limits if enabled
			if enable_horizontal_limits:
				var horizontal_angle = rad_to_deg(rotation.y)
				# Normalize angle to -180 to 180 range
				while horizontal_angle > 180:
					horizontal_angle -= 360
				while horizontal_angle < -180:
					horizontal_angle += 360
				
				horizontal_angle = clamp(horizontal_angle, horizontal_limit_min, horizontal_limit_max)
				rotation.y = deg_to_rad(horizontal_angle)
		
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
	
	# Update SpringArm distance smoothly
	current_distance = lerp(current_distance, target_distance, distance_smoothing * delta)
	spring_arm.spring_length = current_distance
	
	# Apply vertical rotation to SpringArm
	spring_arm.rotation.x = camera_rotation_x
	
	# Handle composition offset with collision scaling
	if offset_scale_with_collision:
		var spring_length = spring_arm.spring_length
		var current_length = spring_arm.get_hit_length()
		var collision_ratio = current_length / spring_length
		
		# Lerp between normal offset and wall offset based on collision
		var target_offset = camera_composition_offset.lerp(wall_composition_offset, 1.0 - collision_ratio)
		
		# Smooth the offset change to prevent jarring movements
		var current_offset = spring_arm.position
		spring_arm.position = current_offset.lerp(target_offset, offset_smoothing * delta)
	else:
		spring_arm.position = camera_composition_offset

func get_camera() -> Camera3D:
	return $SpringArm3D/Camera3D
