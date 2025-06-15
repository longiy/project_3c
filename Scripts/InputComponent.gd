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
@export var show_cursor_preview = true ## Show marker at cursor position before clicking

var character: CharacterBody3D
var camera: Camera3D
var is_mouse_captured = false
var click_destination = Vector3.ZERO
var has_click_destination = false
var click_override_timer = 0.0

# New preview variables
var is_showing_preview = false
var preview_position = Vector3.ZERO

func _ready():
	character = get_parent() as CharacterBody3D
	if not character:
		push_error("InputComponent must be child of CharacterBody3D")
		return
	
	# Initialize mouse state properly
	is_mouse_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	
	# If starting with visible mouse, enable preview immediately
	if not is_mouse_captured and show_cursor_preview and mouse_navigation_enabled:
		is_showing_preview = true
		print("Initial preview mode enabled")

func set_camera(cam: Camera3D):
	camera = cam

func _input(event):
	if not camera:
		return
		
	# Track mouse capture state (but don't change it - ControllerCamera.gd handles that)
	if event.is_action_pressed("toggle_mouse_look"):
		# Wait for the camera script to process first, then check state
		call_deferred("check_mouse_state_change")
		
	# Handle click navigation when mouse is visible
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and mouse_navigation_enabled:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			commit_to_destination(event.position)
		elif event is InputEventMouseMotion and show_cursor_preview:
			# Always try to update preview when mouse moves and cursor is visible
			update_cursor_preview(event.position)

func check_mouse_state_change():
	var was_captured = is_mouse_captured
	is_mouse_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	
	# Debug prints
	print("Mouse state changed - Captured: ", is_mouse_captured, " Was: ", was_captured)
	
	if is_mouse_captured and was_captured != is_mouse_captured:
		# Just became captured
		hide_cursor_preview()
		print("Hiding preview - mouse captured")
	elif not is_mouse_captured and was_captured != is_mouse_captured:
		# Just became visible
		if show_cursor_preview and mouse_navigation_enabled:
			is_showing_preview = true
			print("Starting preview - mouse visible, is_showing_preview: ", is_showing_preview)
			# Get current mouse position and start preview immediately
			var mouse_pos = get_viewport().get_mouse_position()
			print("Immediate preview at mouse position: ", mouse_pos)
			update_cursor_preview(mouse_pos)

func delayed_preview_start():
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and is_showing_preview:
		var mouse_pos = get_viewport().get_mouse_position()
		print("Starting preview at mouse position: ", mouse_pos)
		update_cursor_preview(mouse_pos)

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

func update_cursor_preview(screen_pos: Vector2):
	if not camera or not character or not destination_marker:
		print("Missing components for preview")
		return
		
	# Debug the inputs
	print("Updating preview at screen pos: ", screen_pos)
	print("Mouse mode: ", Input.mouse_mode)
	print("Is showing preview: ", is_showing_preview)
		
	# Raycast from camera to world
	var space_state = character.get_world_3d().direct_space_state
	var from = camera.project_ray_origin(screen_pos)
	var to = from + camera.project_ray_normal(screen_pos) * 1000
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)
	
	if result:
		preview_position = result.position
		destination_marker.global_position = preview_position
		destination_marker.visible = true
		print("Preview updated to world pos: ", preview_position)
	else:
		print("No raycast hit found")

func commit_to_destination(screen_pos: Vector2):
	if is_showing_preview:
		# Use the current preview position as destination
		set_click_destination(preview_position)
		# DON'T disable preview mode - keep it active for next click
		# is_showing_preview = false  # <-- This was the problem!
		
		print("Committed to destination: ", preview_position)
		# Optional: Change marker appearance to show it's now a committed destination
		# You could add visual feedback here (different color, etc.)

func hide_cursor_preview():
	is_showing_preview = false
	if destination_marker and not has_click_destination:
		destination_marker.visible = false

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
	print("Cancelled click destination")
	
	# If we're in preview mode and mouse is visible, continue showing preview
	if is_showing_preview and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and destination_marker:
		# Keep marker visible and update to current cursor position
		var current_mouse_pos = get_viewport().get_mouse_position()
		update_cursor_preview(current_mouse_pos)
		print("Restored preview mode after cancelling destination")
	elif destination_marker:
		destination_marker.visible = false
		print("Hidden marker - not in preview mode")

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
