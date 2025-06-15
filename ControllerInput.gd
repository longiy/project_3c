# InputComponent.gd
extends Node
class_name InputComponent

signal movement_input_changed(input_vector: Vector2)

@export_group("Input Settings")
@export var mouse_navigation_enabled = true
@export var click_override_duration = 0.1 ## How long click input overrides WASD

@export_group("Click Navigation")
@export var destination_marker: Node3D ## Visual marker for click destination
@export var pathfinding_enabled = false ## Enable when you add NavMesh

var character: CharacterBody3D
var camera: Camera3D
var is_mouse_captured = false
var click_destination = Vector3.ZERO
var has_click_destination = false
var click_override_timer = 0.0

func _ready():
	character = get_parent() as CharacterBody3D
	if not character:
		push_error("InputComponent must be child of CharacterBody3D")
		return

func set_camera(cam: Camera3D):
	camera = cam

func _input(event):
	if not camera:
		return
		
	# Track mouse capture state
	if event.is_action_pressed("toggle_mouse_look"):
		is_mouse_captured = !is_mouse_captured
		
	# Handle click navigation when mouse is not captured
	if not is_mouse_captured and mouse_navigation_enabled:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			handle_click_navigation(event.position)

func _physics_process(delta):
	if click_override_timer > 0:
		click_override_timer -= delta
	
	var input_vector = get_final_input_vector()
	movement_input_changed.emit(input_vector)

func get_final_input_vector() -> Vector2:
	var wasd_input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	# If we have active click destination and no WASD override
	if has_click_destination and wasd_input.length() < 0.1:
		return get_click_movement_vector()
	
	# WASD input present - cancel click destination after brief delay
	if wasd_input.length() > 0.1 and has_click_destination:
		if click_override_timer <= 0:
			cancel_click_destination()
	
	return wasd_input

func handle_click_navigation(screen_pos: Vector2):
	if not camera or not character:
		return
		
	# Raycast from camera to world
	var space_state = character.get_world_3d().direct_space_state
	var from = camera.project_ray_origin(screen_pos)
	var to = from + camera.project_ray_normal(screen_pos) * 1000
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)
	
	if result:
		set_click_destination(result.position)

func set_click_destination(world_pos: Vector3):
	click_destination = world_pos
	has_click_destination = true
	click_override_timer = click_override_duration
	
	# Update visual marker
	if destination_marker:
		destination_marker.global_position = world_pos
		destination_marker.visible = true

func cancel_click_destination():
	has_click_destination = false
	if destination_marker:
		destination_marker.visible = false

func get_click_movement_vector() -> Vector2:
	if not has_click_destination or not character:
		return Vector2.ZERO
	
	var direction_3d = (click_destination - character.global_position).normalized()
	
	# Check if we've reached destination
	var distance = character.global_position.distance_to(click_destination)
	if distance < 0.5: # Arrival threshold
		cancel_click_destination()
		return Vector2.ZERO
	
	# Convert 3D direction to input vector (camera-relative)
	if camera:
		var cam_transform = camera.global_transform.basis
		var cam_forward = Vector3(-cam_transform.z.x, 0, -cam_transform.z.z).normalized()
		var cam_right = Vector3(cam_transform.x.x, 0, cam_transform.x.z).normalized()
		
		# Project movement direction onto camera axes
		var forward_dot = direction_3d.dot(cam_forward)
		var right_dot = direction_3d.dot(cam_right)
		
		return Vector2(right_dot, -forward_dot) # Note: Y is inverted for forward/back
	else:
		# Fallback to world coordinates
		return Vector2(direction_3d.x, direction_3d.z)

func is_click_navigation_active() -> bool:
	return has_click_destination
