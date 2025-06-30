# ClickNavigationComponent.gd - REFACTORED: Clean integration with InputManager
extends Node
class_name ClickNavigationComponent

@export_group("Click Navigation")
@export var arrival_threshold = 0.1
@export var show_destination_marker = true
@export var enable_drag_mode = true

@export_group("Explicit References")
@export var character: CharacterBody3D
@export var camera: Camera3D
@export var destination_marker: Node3D

@export_group("Optional Visual Feedback")
@export var marker_hide_delay = 0.3

# === SIGNALS ===
signal destination_set(world_position: Vector3)
signal destination_reached()
signal navigation_cancelled()

# Component references
var camera_rig: CameraController
var input_manager: InputManager

# Navigation state
var click_destination = Vector3.ZERO
var has_destination = false
var arrival_timer = 0.0
var is_arrival_delay = false

# Drag mode state
var is_dragging = false

# Prevent constant cancellation
var last_cancel_time = 0.0
var cancel_cooldown = 0.1

func _ready():
	validate_setup()
	find_component_references()
	connect_to_input_system()

func validate_setup():
	"""Validate required components are assigned"""
	if not character:
		push_error("ClickNavigationComponent: No character assigned!")
		return
	
	if not camera:
		push_error("ClickNavigationComponent: No camera assigned!")
		return

func find_component_references():
	"""Find required component references"""
	camera_rig = get_node_or_null("../../CAMERARIG") as CameraController
	if not camera_rig:
		push_error("ClickNavigationComponent: No CameraController found!")
		return
	
	input_manager = get_node_or_null("../InputManager") as InputManager
	if not input_manager:
		push_error("ClickNavigationComponent: No InputManager found!")
		return

func connect_to_input_system():
	"""REFACTORED: Register with InputManager instead of handling input directly"""
	if input_manager:
		# Register as specialized input component
		input_manager.register_click_navigation_component(self)
		
		# Connect to InputManager's click navigation signal
		if input_manager.has_signal("click_navigation_requested"):
			input_manager.click_navigation_requested.connect(_on_click_navigation_requested)
		
		if input_manager.has_signal("drag_navigation_updated"):
			input_manager.drag_navigation_updated.connect(_on_drag_navigation_updated)
		
		if input_manager.has_signal("drag_navigation_ended"):
			input_manager.drag_navigation_ended.connect(_on_drag_navigation_ended)

func _physics_process(delta):
	if is_arrival_delay:
		arrival_timer -= delta
		if arrival_timer <= 0:
			complete_arrival()

# === SIGNAL HANDLERS (Called by InputManager) ===

func _on_click_navigation_requested(screen_pos: Vector2):
	"""Handle click navigation request from InputManager"""
	if not camera_rig or not camera_rig.is_in_click_navigation_mode():
		return
	
	if enable_drag_mode:
		is_dragging = true
	
	var world_pos = screen_to_world(screen_pos)
	if world_pos != Vector3.ZERO:
		set_destination(world_pos)

func _on_drag_navigation_updated(screen_pos: Vector2):
	"""Handle drag navigation update from InputManager"""
	if not is_dragging:
		return
	
	if not camera_rig or not camera_rig.is_in_click_navigation_mode():
		return
	
	var world_pos = screen_to_world(screen_pos)
	if world_pos != Vector3.ZERO:
		set_destination(world_pos)

func _on_drag_navigation_ended():
	"""Handle drag navigation end from InputManager"""
	is_dragging = false

# === PATHFINDING LOGIC ===

func screen_to_world(screen_pos: Vector2) -> Vector3:
	"""Convert screen position to world position via raycast"""
	if not camera:
		return Vector3.ZERO
	
	var space_state = character.get_world_3d().direct_space_state
	var from = camera.project_ray_origin(screen_pos)
	var to = from + camera.project_ray_normal(screen_pos) * 1000
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	
	var result = space_state.intersect_ray(query)
	if result:
		return result.position
	else:
		return Vector3.ZERO

func set_destination(world_pos: Vector3):
	"""Set navigation destination"""
	click_destination = world_pos
	has_destination = true
	is_arrival_delay = false
	show_marker(world_pos)
	
	# Emit signal for other systems
	destination_set.emit(world_pos)

# === PUBLIC INTERFACE (Called by InputManager) ===

func is_active() -> bool:
	"""Check if click navigation is providing movement input"""
	if not camera_rig or not camera_rig.is_in_click_navigation_mode():
		return false
	
	return (has_destination and click_destination != Vector3.ZERO) or is_dragging or is_arrival_delay

func get_movement_input() -> Vector2:
	"""Get movement input for character controller"""
	if not has_destination or is_arrival_delay:
		return Vector2.ZERO
	
	var distance = character.global_position.distance_to(click_destination)
	
	if distance < arrival_threshold:
		if is_dragging:
			return world_to_input_direction((click_destination - character.global_position).normalized())
		else:
			start_arrival_delay()
			return Vector2.ZERO
	
	var direction_3d = (click_destination - character.global_position).normalized()
	var input_2d = world_to_input_direction(direction_3d)
	
	return input_2d

func cancel_input():
	"""Cancel current navigation (called by InputManager for WASD override)"""
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_cancel_time < cancel_cooldown:
		return
	
	last_cancel_time = current_time
	has_destination = false
	is_arrival_delay = false
	is_dragging = false
	hide_marker()
	
	# Emit signal for other systems
	navigation_cancelled.emit()

func get_input_type() -> String:
	"""Return input type for InputManager classification"""
	return "target_based_navigation"

func world_to_input_direction(direction_3d: Vector3) -> Vector2:
	"""Convert world direction to input space direction"""
	if not camera_rig:
		return Vector2(direction_3d.x, direction_3d.z)
	
	var cam_forward = camera_rig.get_camera_forward()
	var cam_right = camera_rig.get_camera_right()
	
	cam_forward.y = 0
	cam_right.y = 0
	cam_forward = cam_forward.normalized()
	cam_right = cam_right.normalized()
	
	var forward_dot = direction_3d.dot(cam_forward)
	var right_dot = direction_3d.dot(cam_right)
	
	return Vector2(right_dot, -forward_dot)

# === ARRIVAL HANDLING ===

func start_arrival_delay():
	"""Start arrival delay sequence"""
	has_destination = false
	is_arrival_delay = true
	arrival_timer = marker_hide_delay
	
	# Emit signal for other systems
	destination_reached.emit()

func complete_arrival():
	"""Complete arrival sequence"""
	is_arrival_delay = false
	is_dragging = false
	hide_marker()

# === VISUAL FEEDBACK ===

func show_marker(world_pos: Vector3):
	"""Show destination marker at world position"""
	if destination_marker and show_destination_marker:
		destination_marker.global_position = world_pos
		destination_marker.visible = true

func hide_marker():
	"""Hide destination marker"""
	if destination_marker:
		destination_marker.visible = false

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get debug information for DebugUI"""
	return {
		"has_destination": has_destination,
		"is_dragging": is_dragging,
		"is_active": is_active(),
		"camera_mode": camera_rig.get_mode_name(camera_rig.get_current_mode()) if camera_rig else "unknown",
		"in_click_nav_mode": camera_rig.is_in_click_navigation_mode() if camera_rig else false,
		"current_destination": click_destination,
		"distance_to_dest": character.global_position.distance_to(click_destination) if has_destination else 0.0,
		"arrival_delay": is_arrival_delay,
		"marker_visible": destination_marker.visible if destination_marker else false,
		"input_manager_connected": input_manager != null,
		"registered_with_input": true if input_manager else false
	}
