# InputComponent.gd - Complete script with drag mode
extends Node
class_name InputComponent

@export_group("Click Navigation")
@export var camera: Camera3D  # Assign in editor
@export var destination_marker: Node3D  # Assign in editor
@export var arrival_threshold = 0.5
@export var show_cursor_preview = true
@export var marker_disappear_delay = 1.0
@export var click_override_duration = 0.1  # How long click overrides WASD

@export_group("Drag Mode")
@export var enable_drag_mode = true  # Enable hold-and-drag navigation
@export var drag_update_rate = 0.05  # How often to update destination while dragging (seconds)

var character: CharacterBody3D
var is_mouse_captured = true

# Click navigation state
var click_destination = Vector3.ZERO
var has_click_destination = false
var click_override_timer = 0.0

# Preview state
var is_showing_preview = false

# Arrival state
var is_arrival_delay_active = false
var arrival_timer = 0.0

# Drag mode state
var is_dragging = false
var drag_timer = 0.0

# Current input state - this is what gets polled
var current_input_vector = Vector2.ZERO

func _ready():
	character = get_parent() as CharacterBody3D
	if not character:
		push_error("InputComponent must be child of CharacterBody3D")
		return
	
	if not camera:
		push_error("Camera must be assigned to InputComponent")
		return
	
	# Connect to camera's mouse mode signal
	var camera_rig = camera.get_parent().get_parent()  # Camera3D -> SpringArm3D -> CameraRig
	if camera_rig.has_signal("mouse_mode_changed"):
		camera_rig.mouse_mode_changed.connect(_on_mouse_mode_changed)
	
	# Initialize state
	is_mouse_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func _on_mouse_mode_changed(captured: bool):
	is_mouse_captured = captured
	
	if is_mouse_captured:
		hide_cursor_preview()
	else:
		if show_cursor_preview:
			is_showing_preview = true
			call_deferred("update_cursor_preview_current")

func _input(event):
	# ONLY handle click navigation when mouse is visible
	if not is_mouse_captured:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Start drag mode or single click
				if enable_drag_mode:
					start_drag_mode(event.position)
				else:
					commit_to_destination(event.position)
			else:
				# Stop drag mode when releasing mouse
				if is_dragging:
					stop_drag_mode()
		elif event is InputEventMouseMotion:
			if is_dragging and enable_drag_mode:
				# Update destination while dragging
				update_drag_destination(event.position)
			elif show_cursor_preview and not is_dragging:
				# Normal cursor preview (only when not dragging)
				update_cursor_preview(event.position)

func _physics_process(delta):
	# Handle arrival delay timer
	if is_arrival_delay_active:
		arrival_timer -= delta
		if arrival_timer <= 0:
			complete_arrival()
		return
	
	# Handle drag timer
	if is_dragging:
		drag_timer -= delta
	
	if click_override_timer > 0:
		click_override_timer -= delta
	
	# Update current input state (for polling)
	current_input_vector = calculate_current_input()

func calculate_current_input() -> Vector2:
	"""Calculate current input - this gets polled by Character"""
	var wasd_input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	# WASD input cancels click navigation and drag mode
	if wasd_input.length() > 0.1:
		if (has_click_destination or is_dragging) and click_override_timer <= 0:
			cancel_all_navigation()
		return wasd_input
	
	# Use click/drag navigation if active
	if has_click_destination or is_dragging:
		return get_click_movement_vector()
	
	# Fall back to WASD (should be zero if no input)
	return wasd_input

# PUBLIC METHOD: This gets polled by Character
func get_current_input() -> Vector2:
	"""Public method for Character to poll current input state"""
	return current_input_vector

func update_cursor_preview(screen_pos: Vector2):
	if not camera or not character or not destination_marker or not is_showing_preview:
		return
		
	var world_pos = raycast_to_world(screen_pos)
	if world_pos != Vector3.ZERO:
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
	
	if destination_marker:
		destination_marker.global_position = world_pos
		destination_marker.visible = true

func cancel_all_navigation():
	"""Cancel both click navigation and drag mode"""
	has_click_destination = false
	is_dragging = false
	
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
	if not character:
		return Vector2.ZERO
	
	# Make sure we have a valid destination
	if not has_click_destination and not is_dragging:
		return Vector2.ZERO
	
	var direction_3d = (click_destination - character.global_position).normalized()
	
	# Check arrival (only for single clicks, not drag mode)
	if not is_dragging and has_click_destination:
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

func start_drag_mode(screen_pos: Vector2):
	"""Start drag mode - continuous destination updates"""
	var world_pos = raycast_to_world(screen_pos)
	if world_pos != Vector3.ZERO:
		is_dragging = true
		drag_timer = 0.0
		set_click_destination(world_pos)
		print("InputComponent: Started drag mode")

func update_drag_destination(screen_pos: Vector2):
	"""Update destination while dragging (with rate limiting)"""
	if drag_timer <= 0:
		var world_pos = raycast_to_world(screen_pos)
		if world_pos != Vector3.ZERO:
			set_click_destination(world_pos)
			drag_timer = drag_update_rate  # Rate limit updates

func stop_drag_mode():
	"""Stop drag mode"""
	is_dragging = false
	print("InputComponent: Stopped drag mode")

func start_arrival_delay():
	"""Start the arrival delay - marker stays visible for a bit"""
	has_click_destination = false
	is_arrival_delay_active = true
	arrival_timer = marker_disappear_delay

func complete_arrival():
	"""Complete the arrival process and clean up"""
	is_arrival_delay_active = false
	
	if not is_mouse_captured and show_cursor_preview:
		is_showing_preview = true
		update_cursor_preview_current()
	elif destination_marker:
		destination_marker.visible = false

func update_cursor_preview_current():
	if is_showing_preview:
		var mouse_pos = get_viewport().get_mouse_position()
		update_cursor_preview(mouse_pos)

func is_active() -> bool:
	"""Check if this component is actively controlling input"""
	return has_click_destination or is_arrival_delay_active or is_dragging

# Legacy function for compatibility
func cancel_click_destination():
	"""Legacy function - now calls cancel_all_navigation"""
	cancel_all_navigation()
