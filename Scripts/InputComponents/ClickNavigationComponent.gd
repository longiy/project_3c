# ClickNavigationComponent.gd - FIXED: Proper activation and camera mode integration
extends Node
class_name ClickNavigationComponent

@export_group("Click Navigation")
@export var arrival_threshold = 0.1
@export var show_destination_marker = true
@export var enable_drag_mode = true

@export_group("Explicit References")
@export var character: CharacterBody3D  # Drag CHARACTER node here
@export var camera: Camera3D  # Drag Camera3D node here
@export var destination_marker: Node3D  # Optional - drag MARKER node here

@export_group("Optional Visual Feedback")
@export var marker_hide_delay = 0.3

# Component references
var input_manager: InputManager
var camera_rig: CameraRig

# Navigation state
var click_destination = Vector3.ZERO
var has_destination = false
var arrival_timer = 0.0
var is_arrival_delay = false

# Drag mode state
var is_dragging = false

func _ready():
	# Validate explicit references
	if not character:
		push_error("ClickNavigationComponent: No character assigned!")
		return
	
	if not camera:
		push_error("ClickNavigationComponent: No camera assigned!")
		return
	
	# Get component references
	input_manager = character.get_node_or_null("InputManager")
	if not input_manager:
		push_error("ClickNavigationComponent: No InputManager found!")
		return
	
	camera_rig = get_node_or_null("../../CAMERARIG") as CameraRig
	if not camera_rig:
		push_error("ClickNavigationComponent: No CameraRig found!")
		return
	
	# Connect to InputManager for click events
	if input_manager.has_signal("click_input_received"):
		input_manager.click_input_received.connect(_on_click_input_received)
		print("🖱️ ClickNav: Connected to InputManager click signals")
	
	print("🖱️ ClickNav: FIXED - Ready for camera mode integration")

func _physics_process(delta):
	# Handle arrival delay timer
	if is_arrival_delay:
		arrival_timer -= delta
		if arrival_timer <= 0:
			complete_arrival()
	
	# Update drag destination continuously
	if is_dragging and is_active():
		update_drag_to_current_cursor_position()

# === INPUT HANDLING ===

func _on_click_input_received(event_type: String, event_data: Dictionary):
	"""Handle click input from InputManager - FIXED"""
	# Always process clicks in click nav mode (removed activation check)
	if not camera_rig or not camera_rig.is_in_click_navigation_mode():
		return
	
	match event_type:
		"left_click_pressed":
			var screen_pos = event_data.get("position", Vector2.ZERO)
			start_click_or_drag(screen_pos)
		
		"left_click_released":
			finish_click_or_drag()
		
		"mouse_motion":
			if is_dragging:
				var screen_pos = event_data.get("position", Vector2.ZERO)
				update_drag_destination(screen_pos)

# === PUBLIC INTERFACE (Required by InputManager) ===

func is_active() -> bool:
	"""FIXED: Check if this component should be providing input"""
	# Only active in click navigation mode AND (has destination OR is dragging)
	if not camera_rig or not camera_rig.is_in_click_navigation_mode():
		return false
	
	# FIXED: Active if we have destination, are dragging, or are in arrival delay
	return (has_destination or is_dragging or is_arrival_delay)

func get_movement_input() -> Vector2:
	"""Get movement direction as 2D input"""
	if not has_destination or is_arrival_delay:
		return Vector2.ZERO
	
	# Check if we've arrived
	var distance = character.global_position.distance_to(click_destination)
	if distance < arrival_threshold:
		if is_dragging:
			# Continue moving while dragging
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
	print("🖱️ ClickNav: Navigation cancelled")

# === CLICK HANDLING ===

func start_click_or_drag(screen_pos: Vector2):
	"""Handle start of click or drag"""
	print("🖱️ ClickNav: Click at ", screen_pos)
	
	if enable_drag_mode:
		is_dragging = true
	
	handle_click(screen_pos)

func finish_click_or_drag():
	"""Handle end of click or drag"""
	print("🖱️ ClickNav: Click finished, dragging=", is_dragging)
	is_dragging = false

func handle_click(screen_pos: Vector2):
	"""Handle mouse click - convert to world position"""
	var world_pos = screen_to_world(screen_pos)
	if world_pos != Vector3.ZERO:
		set_destination(world_pos)
		print("🖱️ ClickNav: Moving to ", world_pos)
	else:
		print("🖱️ ClickNav: No valid destination found")

func update_drag_destination(screen_pos: Vector2):
	"""Update destination while dragging"""
	if not is_dragging:
		return
	
	var world_pos = screen_to_world(screen_pos)
	if world_pos != Vector3.ZERO:
		set_destination(world_pos)

func update_drag_to_current_cursor_position():
	"""Update destination to current cursor position during drag"""
	if not is_dragging:
		return
	
	var current_mouse_pos = get_viewport().get_mouse_position()
	var world_pos = screen_to_world(current_mouse_pos)
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
	if result:
		print("🖱️ ClickNav: Raycast hit at ", result.position)
		return result.position
	else:
		print("🖱️ ClickNav: Raycast missed")
		return Vector3.ZERO

func set_destination(world_pos: Vector3):
	"""Set new click destination"""
	click_destination = world_pos
	has_destination = true
	is_arrival_delay = false  # Clear any arrival delay
	show_marker(world_pos)
	print("🖱️ ClickNav: Destination set to ", world_pos)

func world_to_input_direction(direction_3d: Vector3) -> Vector2:
	"""Convert 3D world direction to 2D input relative to camera - FIXED AXES"""
	if not camera_rig:
		return Vector2(direction_3d.x, direction_3d.z)
	
	# Use camera rig's forward/right vectors
	var cam_forward = camera_rig.get_camera_forward()
	var cam_right = camera_rig.get_camera_right()
	
	# Project to ground plane
	cam_forward.y = 0
	cam_right.y = 0
	cam_forward = cam_forward.normalized()
	cam_right = cam_right.normalized()
	
	var forward_dot = direction_3d.dot(cam_forward)
	var right_dot = direction_3d.dot(cam_right)
	
	# FIXED: Invert Y axis to match WASD input convention
	# WASD: W=forward=-Y, S=backward=+Y, A=left=-X, D=right=+X
	return Vector2(right_dot, -forward_dot)

# === ARRIVAL HANDLING ===

func start_arrival_delay():
	"""Start arrival delay"""
	print("🖱️ ClickNav: Arrived at destination")
	has_destination = false
	is_arrival_delay = true
	arrival_timer = marker_hide_delay

func complete_arrival():
	"""Complete arrival and clean up"""
	print("🖱️ ClickNav: Arrival complete")
	is_arrival_delay = false
	is_dragging = false
	hide_marker()

# === VISUAL FEEDBACK ===

func show_marker(world_pos: Vector3):
	"""Show destination marker"""
	if destination_marker and show_destination_marker:
		destination_marker.global_position = world_pos
		destination_marker.visible = true
		print("🖱️ ClickNav: Marker shown at ", world_pos)

func hide_marker():
	"""Hide destination marker"""
	if destination_marker:
		destination_marker.visible = false
		print("🖱️ ClickNav: Marker hidden")

# === DEBUG ===

func get_debug_info() -> Dictionary:
	return {
		"has_destination": has_destination,
		"is_dragging": is_dragging,
		"is_active": is_active(),
		"camera_mode": camera_rig.get_mode_name(camera_rig.get_current_mode()) if camera_rig else "unknown",
		"in_click_nav_mode": camera_rig.is_in_click_navigation_mode() if camera_rig else false,
		"current_destination": click_destination,
		"distance_to_dest": character.global_position.distance_to(click_destination) if has_destination else 0.0,
		"arrival_delay": is_arrival_delay,
		"marker_visible": destination_marker.visible if destination_marker else false
	}
