# ClickNavigationComponent.gd - Pure click navigation, no WASD logic
extends Node
class_name ClickNavigationComponent

@export_group("Click Navigation")
@export var camera: Camera3D  # Assign in editor
@export var destination_marker: Node3D  # Assign in editor
@export var arrival_threshold = 0.5
@export var show_cursor_preview = true
@export var marker_disappear_delay = 1.0

@export_group("Drag Mode")
@export var enable_drag_mode = true
@export var drag_update_rate = 0.05  # Seconds between updates while dragging

var character: CharacterBody3D
var is_mouse_captured = true

# Click navigation state
var click_destination = Vector3.ZERO
var has_click_destination = false

# Preview state
var is_showing_preview = false

# Arrival state
var is_arrival_delay_active = false
var arrival_timer = 0.0

# Drag mode state
var is_dragging = false
var drag_timer = 0.0

func _ready():
	character = get_parent() as CharacterBody3D
	if not character:
		push_error("ClickNavigationComponent must be child of CharacterBody3D")
		return
	
	if not camera:
		push_error("Camera must be assigned to ClickNavigationComponent")
		return
	
	# Connect to camera's mouse mode signal if available
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

# === PUBLIC INTERFACE FOR CHARACTER CONTROLLER ===

func is_active() -> bool:
	"""Check if this component is actively providing input"""
	return has_click_destination or is_arrival_delay_active or is_dragging

func get_movement_input() -> Vector2:
	"""Get movement input vector for character controller"""
	if not is_active():
		return Vector2.ZERO
	
	var direction_3d = (click_destination - character.global_position).normalized()
	
	# Check arrival (only for single clicks, not drag mode)
	if not is_dragging and has_click_destination:
		var distance = character.global_position.distance_to(click_destination)
		if distance < arrival_threshold:
			start_arrival_delay()
			return Vector2.ZERO
	
	# Convert to camera-relative movement if camera available
	if camera:
		var cam_transform = camera.global_transform.basis
		var cam_forward = Vector3(-cam_transform.z.x, 0, -cam_transform.z.z).normalized()
		var cam_right = Vector3(cam_transform.x.x, 0, cam_transform.x.z).normalized()
		
		var forward_dot = direction_3d.dot(cam_forward)
		var right_dot = direction_3d.dot(cam_right)
		
		return Vector2(right_dot, -forward_dot)
	else:
		# Fallback to world coordinates
		return Vector2(direction_3d.x, direction_3d.z)

func cancel_input():
	"""Cancel all navigation - called by character controller when WASD pressed"""
	has_click_destination = false
	is_dragging = false
	is_arrival_delay_active = false
	
	if not is_mouse_captured and show_cursor_preview and destination_marker:
		is_showing_preview = true
		update_cursor_preview_current()
	elif destination_marker:
		destination_marker.visible = false

# === INTERNAL CLICK NAVIGATION LOGIC ===

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
	
	if destination_marker:
		destination_marker.global_position = world_pos
		destination_marker.visible = true

func hide_cursor_preview():
	is_showing_preview = false
	if destination_marker and not has_click_destination:
		destination_marker.visible = false

func start_drag_mode(screen_pos: Vector2):
	"""Start drag mode - continuous destination updates"""
	var world_pos = raycast_to_world(screen_pos)
	if world_pos != Vector3.ZERO:
		is_dragging = true
		drag_timer = 0.0
		set_click_destination(world_pos)
		print("ClickNav: Started drag mode")

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
	print("ClickNav: Stopped drag mode")

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
