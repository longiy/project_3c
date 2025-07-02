# ClickNavigationSystem.gd - Child of CCC_ControlManager
extends Node
class_name ClickNavigationSystem

# === SIGNALS ===
signal click_destination(world_position: Vector3)
signal navigation_complete()
signal navigation_cancelled()

# === SETTINGS ===
@export var movement_speed = 3.0
@export var arrival_threshold = 0.5
@export var path_update_frequency = 10.0

# === STATE ===
var character: CharacterBody3D
var target_position: Vector3
var is_navigating: bool = false
var current_path: Array[Vector3] = []
var path_index: int = 0

# Navigation state
var path_update_timer: float = 0.0
var path_update_interval: float

func _ready():
	character = get_parent().get_parent() as CharacterBody3D  # CCC_ControlManager -> CHARACTER
	path_update_interval = 1.0 / path_update_frequency
	
	if not character:
		push_error("ClickNavigationSystem: No CharacterBody3D found!")
	
	print("✅ ClickNavigationSystem: Ready as child of CCC_ControlManager")

func _physics_process(delta):
	"""Process navigation"""
	if is_navigating:
		update_navigation(delta)

func process_input(event):
	"""Process mouse input for click navigation"""
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			handle_click_navigation(event.position)

func handle_click_navigation(screen_position: Vector2):
	"""Handle click navigation"""
	var world_position = screen_to_world_position(screen_position)
	if world_position != Vector3.ZERO:
		set_navigation_target(world_position)

func screen_to_world_position(screen_pos: Vector2) -> Vector3:
	"""Convert screen position to world position"""
	var camera = get_camera()
	if not camera:
		return Vector3.ZERO
	
	var from = camera.project_ray_origin(screen_pos)
	var to = from + camera.project_ray_normal(screen_pos) * 1000
	
	var space_state = character.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)
	
	if result:
		return result.position
	
	return Vector3.ZERO

func get_camera() -> Camera3D:
	"""Get camera reference"""
	var camera_rig = get_node_or_null("../../../CAMERARIG")
	if camera_rig:
		var spring_arm = camera_rig.get_node_or_null("SpringArm3D")
		if spring_arm:
			return spring_arm.get_node_or_null("Camera3D") as Camera3D
	
	return null

func set_navigation_target(world_position: Vector3):
	"""Set navigation target"""
	target_position = world_position
	is_navigating = true
	path_index = 0
	
	# Simple direct path for now (can be enhanced with pathfinding later)
	current_path = [character.global_position, target_position]
	
	click_destination.emit(world_position)
	print("🎯 ClickNavigationSystem: Navigating to ", world_position)

func update_navigation(delta: float):
	"""Update navigation towards target"""
	if not is_navigating or current_path.is_empty():
		return
	
	# Get current target point
	if path_index >= current_path.size():
		complete_navigation()
		return
	
	var current_target = current_path[path_index]
	var character_position = character.global_position
	var distance_to_target = character_position.distance_to(current_target)
	
	# Check if reached current waypoint
	if distance_to_target < arrival_threshold:
		path_index += 1
		if path_index >= current_path.size():
			complete_navigation()
			return
		else:
			current_target = current_path[path_index]
	
	# Calculate movement direction
	var direction_3d = (current_target - character_position).normalized()
	var direction_2d = Vector2(direction_3d.x, direction_3d.z)
	
	# This will be handled by the parent CCC_ControlManager
	# We just provide the input direction

func get_movement_input() -> Vector2:
	"""Get movement input for navigation"""
	if not is_navigating or current_path.is_empty():
		return Vector2.ZERO
	
	if path_index >= current_path.size():
		return Vector2.ZERO
	
	var current_target = current_path[path_index]
	var character_position = character.global_position
	var direction_3d = (current_target - character_position).normalized()
	
	return Vector2(direction_3d.x, direction_3d.z)

func is_active() -> bool:
	"""Check if click navigation is active"""
	return is_navigating

func cancel_navigation():
	"""Cancel current navigation"""
	if is_navigating:
		is_navigating = false
		current_path.clear()
		path_index = 0
		navigation_cancelled.emit()
		print("❌ ClickNavigationSystem: Navigation cancelled")

func complete_navigation():
	"""Complete navigation"""
	is_navigating = false
	current_path.clear()
	path_index = 0
	navigation_complete.emit()
	print("✅ ClickNavigationSystem: Navigation complete")

func cancel_input():
	"""Cancel navigation (called by CCC_ControlManager)"""
	cancel_navigation()

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get debug information"""
	return {
		"is_navigating": is_navigating,
		"target_position": target_position,
		"path_length": current_path.size(),
		"path_index": path_index,
		"current_input": get_movement_input(),
		"character_connected": character != null
	}
