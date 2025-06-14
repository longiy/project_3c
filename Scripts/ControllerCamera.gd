extends Node3D

@export var target_character: CharacterBody3D ## Drag your character here
@export var camera_distance = 5.0 ## Distance from character
@export var camera_height = 2.0 ## Height offset above character
@export var mouse_sensitivity = 0.002 ## Mouse look sensitivity
@export var vertical_limit_min = -80.0 ## Minimum vertical look angle (degrees)
@export_range(-80.0, -10.0) var vertical_limit_max = -20.0 ## Maximum vertical look angle (degrees)
@export var collision_margin = 0.2 ## Space to maintain from walls
@export var camera_smoothing = 10.0 ## How smoothly camera follows
@export var follow_smoothing = 8.0 ## How smoothly camera follows character position

@onready var camera_arm = $CameraArm
@onready var camera_3d = $CameraArm/Camera3D
var character: CharacterBody3D

var mouse_delta = Vector2.ZERO
var camera_rotation_x = 0.0
var current_distance = 0.0

func _ready():
	# Capture mouse on start
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Get character reference
	character = target_character
	if not character:
		push_error("No target character assigned to camera!")
		return
	
	# Initialize distance
	current_distance = camera_distance
	
	# Set initial camera rotation to look down at character
	camera_rotation_x = deg_to_rad(-20.0)
	
	# Position camera system initially at character
	if character:
		global_position = character.global_position + Vector3(0, camera_height, 0)

func _input(event):
	# Handle mouse capture toggle
	if event.is_action_pressed("ui_cancel"):
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
		rotation.y -= mouse_delta.x * mouse_sensitivity
		
		# Vertical rotation (X-axis) - clamp to limits
		camera_rotation_x -= mouse_delta.y * mouse_sensitivity
		camera_rotation_x = clamp(camera_rotation_x, 
			deg_to_rad(vertical_limit_min), 
			deg_to_rad(vertical_limit_max))
		
		mouse_delta = Vector2.ZERO
	
	# Position the camera system at character with height offset
	var target_position = character.global_position + Vector3(0, camera_height, 0)
	global_position = global_position.lerp(target_position, follow_smoothing * delta)
	
	# Apply vertical rotation to camera arm
	camera_arm.rotation.x = camera_rotation_x
	
	# Calculate camera position with collision check
	var camera_offset = Vector3(0, 0, current_distance)
	var desired_camera_pos = camera_arm.global_position + camera_arm.transform.basis * camera_offset
	
	# Check for collisions and adjust distance with smoothing
	var collision_distance = check_camera_collision(global_position, desired_camera_pos)
	
	# Smooth collision distance changes to prevent shaking
	var target_distance = collision_distance if collision_distance < camera_distance else camera_distance
	current_distance = lerp(current_distance, target_distance, camera_smoothing * delta)
	
	# Position camera at adjusted distance
	camera_3d.position.z = current_distance

func check_camera_collision(from: Vector3, to: Vector3) -> float:
	var space_state = get_world_3d().direct_space_state
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	# Exclude the character from collision check
	if character:
		query.exclude = [character.get_rid()]
	
	# Enable collision with all layers
	query.collision_mask = 0xFFFFFFFF
	
	var result = space_state.intersect_ray(query)
	
	print("Raycast from: ", from.round(), " to: ", to.round())
	print("Distance: ", from.distance_to(to))
	
	if result:
		print("HIT: ", result.collider.name, " at ", result.position.round())
		var hit_distance = from.distance_to(result.position) - collision_margin
		return max(hit_distance, 0.5)
	else:
		print("NO HIT detected")
		return camera_distance
