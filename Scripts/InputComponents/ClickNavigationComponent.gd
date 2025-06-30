# ClickNavigationComponent.gd - FIXED: Remove duplicate input handling
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

var camera_rig: Camera3CManager

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
	if not character:
		push_error("ClickNavigationComponent: No character assigned!")
		return
	
	if not camera:
		push_error("ClickNavigationComponent: No camera assigned!")
		return
	
	camera_rig = get_node_or_null("../../CAMERARIG") as Camera3CManager
	if not camera_rig:
		push_error("ClickNavigationComponent: No Camera3CManager found!")
		return

# FIXED: Listen to camera rig input events instead of InputManager
func _input(event):
	# Only handle input in click navigation mode
	if not camera_rig or not camera_rig.is_in_click_navigation_mode():
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		handle_click(event.position)
	elif event is InputEventMouseMotion and is_dragging:
		handle_drag(event.position)
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		is_dragging = false

func _physics_process(delta):
	if is_arrival_delay:
		arrival_timer -= delta
		if arrival_timer <= 0:
			complete_arrival()
	
	# FIXED: Continuously update cursor position during drag mode
	if is_dragging:
		var current_mouse_pos = get_viewport().get_mouse_position()
		handle_drag(current_mouse_pos)

# === CLICK HANDLING ===

func handle_click(screen_pos: Vector2):
	if enable_drag_mode:
		is_dragging = true
	
	var world_pos = screen_to_world(screen_pos)
	if world_pos != Vector3.ZERO:
		set_destination(world_pos)

func handle_drag(screen_pos: Vector2):
	if not is_dragging:
		return
	
	var world_pos = screen_to_world(screen_pos)
	if world_pos != Vector3.ZERO:
		set_destination(world_pos)

func screen_to_world(screen_pos: Vector2) -> Vector3:
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
	click_destination = world_pos
	has_destination = true
	is_arrival_delay = false
	show_marker(world_pos)

# === PUBLIC INTERFACE ===

func is_active() -> bool:
	if not camera_rig or not camera_rig.is_in_click_navigation_mode():
		return false
	
	return (has_destination and click_destination != Vector3.ZERO) or is_dragging or is_arrival_delay

func get_movement_input() -> Vector2:
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
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_cancel_time < cancel_cooldown:
		return
	
	last_cancel_time = current_time
	has_destination = false
	is_arrival_delay = false
	is_dragging = false
	hide_marker()

func world_to_input_direction(direction_3d: Vector3) -> Vector2:
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
	has_destination = false
	is_arrival_delay = true
	arrival_timer = marker_hide_delay

func complete_arrival():
	is_arrival_delay = false
	is_dragging = false
	hide_marker()

# === VISUAL FEEDBACK ===

func show_marker(world_pos: Vector3):
	if destination_marker and show_destination_marker:
		destination_marker.global_position = world_pos
		destination_marker.visible = true

func hide_marker():
	if destination_marker:
		destination_marker.visible = false

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
