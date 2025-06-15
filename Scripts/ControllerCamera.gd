extends Node3D

@export_group("Target & Following")
@export var target_character: CharacterBody3D ## Drag your character here
@export var camera_height = 2.0 ## Height offset above character
@export var follow_smoothing = 8.0 ## How smoothly camera follows character position

@export_group("Mouse Controls")
@export var mouse_sensitivity = 0.002 ## Mouse look sensitivity
@export var enable_mouse_yaw = true ## Enable/disable horizontal mouse rotation
@export var enable_mouse_pitch = true ## Enable/disable vertical mouse rotation
@export var allow_mouse_toggle = true ## Allow Mouse2 to toggle mouse capture

@export_group("Rotation Limits")
@export var vertical_limit_min = -80.0 ## Minimum vertical look angle (degrees)
@export var vertical_limit_max = 50.0 ## Maximum vertical look angle (degrees)
@export var enable_horizontal_limits = false ## Enable/disable horizontal rotation limits
@export var horizontal_limit_min = -90.0 ## Minimum horizontal look angle (degrees)
@export var horizontal_limit_max = 90.0 ## Maximum horizontal look angle (degrees)

@export_group("Composition & Framing")
@export var camera_composition_offset = Vector3(0, 0.5, 0) ## Offset for composition (doesn't affect follow height)
@export var offset_scale_with_collision = true ## Scale composition offset based on collision distance
@export var offset_smoothing = 8.0 ## How smoothly offset scales with collision

@onready var spring_arm = $SpringArm3D

var character: CharacterBody3D
var mouse_delta = Vector2.ZERO
var camera_rotation_x = 0.0
var current_offset_scale = 1.0

func _ready():
	# Capture mouse on start
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Get character reference
	character = target_character
	if not character:
		push_error("No target character assigned to camera!")
		return
	
	# Set initial camera rotation to look down at character
	camera_rotation_x = deg_to_rad(-20.0)
	
	# Position camera system initially at character
	if character:
		global_position = character.global_position + Vector3(0, camera_height, 0)

func _input(event):
	# Handle mouse capture toggle
	if event.is_action_pressed("toggle_mouse_look"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Capture mouse movement only when mouse is captured
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event is InputEventMouseMotion:
		mouse_delta = event.relative

func _physics_process(delta):
	if not character:
		return
	
	# Handle mouse look rotation
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Horizontal rotation (Y-axis) - rotate around character
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
		
		# Vertical rotation (X-axis) - clamp to limits
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
	
	# Scale composition offset based on SpringArm collision distance
	if offset_scale_with_collision:
		var spring_length = spring_arm.spring_length
		var current_length = spring_arm.get_hit_length()
		var target_scale = current_length / spring_length
		
		# Smooth the scale change to prevent shaking
		current_offset_scale = lerp(current_offset_scale, target_scale, offset_smoothing * delta)
		
		# Apply smoothed scaled offset
		var scaled_offset = camera_composition_offset * current_offset_scale
		spring_arm.position = scaled_offset
	else:
		spring_arm.position = camera_composition_offset
