# ClickNavigationComponent.gd - Self-contained click-to-move navigation
extends Node
class_name ClickNavigationComponent

@export_group("Click Navigation")
@export var arrival_threshold = 0.1
@export var show_destination_marker = true
@export var enable_drag_mode = true
@export var force_mouse_visible_in_cinematic = true

@export_group("Optional Visual Feedback")
@export var destination_marker: Node3D  # Optional - will work without
@export var marker_hide_delay = 0.3

var character: CharacterBody3D
var camera: Camera3D

# Navigation state
var click_destination = Vector3.ZERO
var has_destination = false
var arrival_timer = 0.0
var is_arrival_delay = false

# Drag mode state
var is_dragging = false
var drag_start_pos = Vector2.ZERO

# Cinematic override state
var mouse_forced_visible = false

func _ready():
	# Get required parent
	character = get_parent() as CharacterBody3D
	if not character:
		push_error("ClickNavigationComponent must be child of CharacterBody3D")
		return
	
	# Auto-find camera (optional - graceful fallback)
	camera = get_viewport().get_camera_3d()
	if not camera:
		print("ClickNav: No camera found - click navigation disabled")

func _input(event):
	# Handle cinematic mode mouse toggle first (works even when mouse captured)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if is_in_cinematic_mode() and force_mouse_visible_in_cinematic:
			toggle_mouse_in_cinematic()
			get_viewport().set_input_as_handled()
			return
	
	if not can_handle_input():
		return
	
	# Left mouse - start click or drag
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			start_click_or_drag(event.position)
		else:
			finish_click_or_drag()
	
	# Mouse motion during drag
	elif event is InputEventMouseMotion and is_dragging and enable_drag_mode:
		update_drag_destination(event.position)
	
	# Right click cancels when not in cinematic mode
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		cancel_input()

func _physics_process(delta):
	# Handle arrival delay timer
	if is_arrival_delay:
		arrival_timer -= delta
		if arrival_timer <= 0:
			complete_arrival()

# === PUBLIC INTERFACE (Required by character controller) ===

func is_active() -> bool:
	"""Check if this component is providing input"""
	return (has_destination or is_dragging) and not is_arrival_delay

func get_movement_input() -> Vector2:
	"""Get movement direction as 2D input"""
	if not has_destination or is_arrival_delay:
		return Vector2.ZERO
	
	# Check if we've arrived
	var distance = character.global_position.distance_to(click_destination)
	if distance < arrival_threshold:
		if is_dragging:
			# In drag mode, keep following mouse even when close
			return world_to_input_direction((click_destination - character.global_position).normalized())
		else:
			# Single click - stop when arrived
			start_arrival_delay()
			return Vector2.ZERO
	
	# Calculate direction and convert to camera-relative input
	var direction_3d = (click_destination - character.global_position).normalized()
	return world_to_input_direction(direction_3d)

func cancel_input():
	"""Cancel current navigation"""
	has_destination = false
	is_arrival_delay = false
	is_dragging = false
	hide_marker()

# === INTERNAL CLICK HANDLING ===

func can_handle_input() -> bool:
	"""Check if we should respond to input"""
	# In cinematic mode, only handle input if we forced mouse visible
	if is_in_cinematic_mode():
		return mouse_forced_visible and camera != null
	
	# Normal mode - handle input when mouse is free
	return Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and camera != null

func handle_click(screen_pos: Vector2):
	"""Handle mouse click"""
	var world_pos = screen_to_world(screen_pos)
	if world_pos != Vector3.ZERO:
		set_destination(world_pos)

func start_click_or_drag(screen_pos: Vector2):
	"""Handle start of click or drag"""
	if enable_drag_mode:
		# Start drag mode
		is_dragging = true
		drag_start_pos = screen_pos
	
	# Set initial destination (works for both click and drag)
	handle_click(screen_pos)

func finish_click_or_drag():
	"""Handle end of click or drag"""
	is_dragging = false

func update_drag_destination(screen_pos: Vector2):
	"""Update destination while dragging"""
	if not is_dragging:
		return
	
	var world_pos = screen_to_world(screen_pos)
	if world_pos != Vector3.ZERO:
		set_destination(world_pos)

func screen_to_world(screen_pos: Vector2) -> Vector3:
	"""Convert screen position to world position via raycast"""
	if not camera:
		return Vector3.ZERO
	
	var space_state = character.get_world_3d().direct_space_state
	var from = camera.project_ray_origin(screen_pos)
	var to = from + camera.project_ray_normal(screen_pos) * 1000
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1  # Only ground layer
	
	var result = space_state.intersect_ray(query)
	return result.position if result else Vector3.ZERO

func set_destination(world_pos: Vector3):
	"""Set new click destination"""
	click_destination = world_pos
	has_destination = true
	show_marker(world_pos)

func world_to_input_direction(direction_3d: Vector3) -> Vector2:
	"""Convert 3D world direction to 2D input relative to camera"""
	if not camera:
		# Fallback to world-space
		return Vector2(direction_3d.x, direction_3d.z)
	
	# Camera-relative conversion
	var cam_basis = camera.global_transform.basis
	var cam_forward = Vector3(-cam_basis.z.x, 0, -cam_basis.z.z).normalized()
	var cam_right = Vector3(cam_basis.x.x, 0, cam_basis.x.z).normalized()
	
	var forward_dot = direction_3d.dot(cam_forward)
	var right_dot = direction_3d.dot(cam_right)
	
	return Vector2(right_dot, -forward_dot)

# === CINEMATIC MODE DETECTION AND MOUSE TOGGLE ===

func is_in_cinematic_mode() -> bool:
	"""Detect if we're in cinematic mode by checking common patterns"""
	# Method 1: Check if Input.mouse_mode was forced visible recently
	# (This catches when cinematic mode sets mouse visible)
	
	# Method 2: Look for CameraCinema component and check its state
	var camera_cinema = find_camera_cinema()
	if camera_cinema and camera_cinema.has_method("is_in_cinematic_mode"):
		return camera_cinema.is_in_cinematic_mode()
	
	# Method 3: Heuristic - if mouse was captured but is now visible without user input
	# (This is a simple fallback that works in most cases)
	return false  # Default to false if we can't detect

func find_camera_cinema() -> Node:
	"""Try to find CameraCinema component (optional)"""
	# Look in common locations
	var camera_rig = get_node_or_null("../../CAMERARIG")
	if camera_rig:
		var cinema = camera_rig.get_node_or_null("CameraCinema")
		if cinema:
			return cinema
	
	# Could add more search patterns here
	return null

func toggle_mouse_in_cinematic():
	"""Toggle mouse visibility in cinematic mode"""
	if mouse_forced_visible:
		# Hide mouse and disable click nav
		mouse_forced_visible = false
		cancel_input()
		print("ClickNav: Mouse hidden in cinematic mode")
	else:
		# Show mouse and enable click nav
		mouse_forced_visible = true
		print("ClickNav: Mouse shown in cinematic mode")

# === ARRIVAL HANDLING ===

func start_arrival_delay():
	"""Start arrival delay - brief pause before hiding marker"""
	has_destination = false
	is_arrival_delay = true
	arrival_timer = marker_hide_delay

func complete_arrival():
	"""Complete arrival and clean up"""
	is_arrival_delay = false
	is_dragging = false  # Stop dragging on arrival
	hide_marker()

# === OPTIONAL VISUAL FEEDBACK ===

func show_marker(world_pos: Vector3):
	"""Show destination marker if available"""
	if destination_marker and show_destination_marker:
		destination_marker.global_position = world_pos
		destination_marker.visible = true

func hide_marker():
	"""Hide destination marker if available"""
	if destination_marker:
		destination_marker.visible = false

# === DEBUG ===

func get_debug_info() -> Dictionary:
	"""Get debug information"""
	return {
		"has_destination": has_destination,
		"is_dragging": is_dragging,
		"can_handle_input": can_handle_input(),
		"is_in_cinematic_mode": is_in_cinematic_mode(),
		"mouse_forced_visible": mouse_forced_visible,
		"has_camera": camera != null,
		"has_marker": destination_marker != null,
		"current_destination": click_destination,
		"distance_to_dest": character.global_position.distance_to(click_destination) if has_destination else 0.0
	}
