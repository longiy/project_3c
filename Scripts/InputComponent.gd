# InputComponent.gd - Consolidated input handling
extends Node
class_name InputComponent

signal movement_input_changed(input_vector: Vector2)

@export_group("Input Settings")
@export var mouse_navigation_enabled = true
@export var click_override_duration = 0.1 ## How long click input overrides WASD

@export_group("Click Navigation")
@export var destination_marker: Node3D ## Visual marker for click destination
@export var arrival_threshold = 0.5 ## Distance to consider destination reached
@export var show_cursor_preview = true ## Show marker at cursor position before clicking
@export var marker_disappear_delay = 1.0 ## How long marker stays after arrival (seconds)

var character: CharacterBody3D
var camera: Camera3D
var is_mouse_captured = true

# Click navigation state
var click_destination = Vector3.ZERO
var has_click_destination = false
var click_override_timer = 0.0

# Preview state
var is_showing_preview = false
var preview_position = Vector3.ZERO

# Arrival delay state
var is_arrival_delay_active = false
var arrival_timer = 0.0

func _ready():
	character = get_parent() as CharacterBody3D
	if not character:
		push_error("InputComponent must be child of CharacterBody3D")
		return
	
	# Get camera reference from scene
	var camera_rig = get_node("../../CAMERARIG")
	if camera_rig:
		camera = camera_rig.get_node("SpringArm3D/Camera3D")
		if camera:
			print("InputComponent: Camera found")
		else:
			push_error("Camera not found in expected path")
	
	# Initialize mouse state
	is_mouse_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	
	# Start preview if mouse is visible
	if not is_mouse_captured and show_cursor_preview and mouse_navigation_enabled:
		is_showing_preview = true

func on_mouse_mode_changed(captured: bool):
	"""Called by camera when mouse mode changes"""
	is_mouse_captured = captured
	
	if is_mouse_captured:
		# Mouse captured - hide preview
		hide_cursor_preview()
	else:
		# Mouse visible - start preview if enabled
		if show_cursor_preview and mouse_navigation_enabled:
			is_showing_preview = true
			# Update preview immediately
			call_deferred("update_cursor_preview_current")

func update_cursor_preview_current():
	"""Update preview at current mouse position"""
	if is_showing_preview:
		var mouse_pos = get_viewport().get_mouse_position()
		update_cursor_preview(mouse_pos)

func _input(event):
	if not camera or not mouse_navigation_enabled:
		return
		
	# Handle click navigation when mouse is visible
	if not is_mouse_captured:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			commit_to_destination(event.position)
		elif event is InputEventMouseMotion and show_cursor_preview:
			update_cursor_preview(event.position)

func _physics_process(delta):
	# Handle arrival delay timer
	if is_arrival_delay_active:
		arrival_timer -= delta
		if arrival_timer <= 0:
			complete_arrival()
		return  # Don't process other input during arrival delay
	
	if click_override_timer > 0:
		click_override_timer -= delta
	
	var input_vector = get_final_input_vector()
	movement_input_changed.emit(input_vector)

func get_final_input_vector() -> Vector2:
	var wasd_input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	# WASD input cancels click navigation
	if wasd_input.length() > 0.1 and has_click_destination:
		if click_override_timer <= 0:
			cancel_click_destination()
		return wasd_input
	
	# Use click navigation if active and no WASD input
	if has_click_destination and wasd_input.length() < 0.1:
		return get_click_movement_vector()
	
	return wasd_input

func update_cursor_preview(screen_pos: Vector2):
	if not camera or not character or not destination_marker or not is_showing_preview:
		return
		
	var world_pos = raycast_to_world(screen_pos)
	if world_pos != Vector3.ZERO:
		preview_position = world_pos
		destination_marker.global_position = world_pos
		destination_marker.visible = true

func commit_to_destination(screen_pos: Vector2):
	if not is_showing_preview:
		return
		
	var world_pos = raycast_to_world(screen_pos)
	if world_pos != Vector3.ZERO:
		set_click_destination(world_pos)

func raycast_to_world(screen_pos: Vector2) -> Vector3:
	if not camera:
		return Vector3.ZERO
	
	var space_state = character.get_world_3d().direct_space_state
	var from = camera.project_ray_origin(screen_pos)
	var to = from + camera.project_ray_normal(screen_pos) * 1000
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1  # Only hit ground/environment layer
	
	var result = space_state.intersect_ray(query)
	return result.position if result else Vector3.ZERO

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
	
	# Return to preview mode if mouse is visible
	if not is_mouse_captured and show_cursor_preview and destination_marker:
		is_showing_preview = true
		update_cursor_preview_current()
	elif destination_marker:
		destination_marker.visible = false

func hide_cursor_preview():
	is_showing_preview = false
	if destination_marker and not has_click_destination:
		destination_marker.visible = false

func get_click_movement_vector() -> Vector2:
	if not has_click_destination or not character:
		return Vector2.ZERO
	
	var direction_3d = (click_destination - character.global_position).normalized()
	
	# Check arrival
	var distance = character.global_position.distance_to(click_destination)
	if distance < arrival_threshold:
		start_arrival_delay()
		return Vector2.ZERO
	
	# Convert to camera-relative movement
	if camera:
		var cam_transform = camera.global_transform.basis
		var cam_forward = Vector3(-cam_transform.z.x, 0, -cam_transform.z.z).normalized()
		var cam_right = Vector3(cam_transform.x.x, 0, cam_transform.x.z).normalized()
		
		var forward_dot = direction_3d.dot(cam_forward)
		var right_dot = direction_3d.dot(cam_right)
		
		return Vector2(right_dot, -forward_dot)
	else:
		return Vector2(direction_3d.x, direction_3d.z)

func start_arrival_delay():
	"""Start the arrival delay - marker stays visible for a bit"""
	has_click_destination = false
	is_arrival_delay_active = true
	arrival_timer = marker_disappear_delay
	print("InputComponent: Arrived at destination, starting delay")

func complete_arrival():
	"""Complete the arrival process and clean up"""
	is_arrival_delay_active = false
	
	# Return to preview mode if mouse is visible
	if not is_mouse_captured and show_cursor_preview:
		is_showing_preview = true
		update_cursor_preview_current()
	elif destination_marker:
		destination_marker.visible = false
	
	print("InputComponent: Arrival delay complete")

func is_click_navigation_active() -> bool:
	return has_click_destination
