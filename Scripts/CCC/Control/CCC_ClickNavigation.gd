class_name CCC_ClickNavigation
extends Node

@export_group("Navigation Settings")
@export var move_speed: float = 5.0
@export var stopping_distance: float = 0.5
@export var click_button: MouseButton = MOUSE_BUTTON_LEFT

@export_group("3C Integration")
@export var camera_controller: CCC_CameraController

var target_position: Vector3 = Vector3.ZERO
var is_navigating: bool = false
var is_active_flag: bool = true
var character: CharacterBody3D

signal navigation_started()
signal navigation_reached()
signal navigation_cancelled()

func _ready():
	# Find character reference
	var parent = get_parent()
	while parent and not parent is CharacterBody3D:
		parent = parent.get_parent()
	character = parent

func _input(event):
	if not is_active_flag:
		return
	
	if event is InputEventMouseButton:
		if event.button_index == click_button and event.pressed:
			handle_click(event.position)

func handle_click(screen_position: Vector2):
	if not camera_controller:
		return
	
	var camera = camera_controller.get_active_camera()
	if not camera:
		return
	
	var from = camera.project_ray_origin(screen_position)
	var to = from + camera.project_ray_normal(screen_position) * 1000
	
	var space_state = character.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)
	
	if result:
		set_target_position(result.position)

func set_target_position(position: Vector3):
	target_position = position
	is_navigating = true
	navigation_started.emit()

func get_movement_input() -> Vector2:
	if not is_active_flag or not is_navigating or not character:
		return Vector2.ZERO
	
	var character_position = character.global_position
	var direction_to_target = target_position - character_position
	direction_to_target.y = 0  # Remove vertical component
	
	var distance = direction_to_target.length()
	
	# Check if we've reached the target
	if distance <= stopping_distance:
		is_navigating = false
		navigation_reached.emit()
		return Vector2.ZERO
	
	# Convert 3D direction to 2D input
	var normalized_direction = direction_to_target.normalized()
	return Vector2(normalized_direction.x, normalized_direction.z)

func is_active() -> bool:
	return is_active_flag and is_navigating

func set_active(active: bool):
	is_active_flag = active
	
	if not active:
		cancel_input()

func cancel_input():
	if is_navigating:
		is_navigating = false
		navigation_cancelled.emit()

func get_target_position() -> Vector3:
	return target_position

func is_navigation_active() -> bool:
	return is_navigating

func get_distance_to_target() -> float:
	if not character or not is_navigating:
		return 0.0
	
	var character_position = character.global_position
	var direction_to_target = target_position - character_position
	direction_to_target.y = 0
	return direction_to_target.length()

func get_debug_info() -> Dictionary:
	return {
		"click_nav_active": is_active_flag,
		"click_nav_navigating": is_navigating,
		"click_nav_target": target_position,
		"click_nav_distance": get_distance_to_target()
	}