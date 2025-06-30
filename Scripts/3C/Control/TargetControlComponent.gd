# TargetControlComponent.gd - Click-to-move control handling
extends Node
class_name TargetControlComponent

# === SIGNALS ===
signal click_target_received(world_position: Vector3)
signal navigation_started(destination: Vector3)
signal navigation_completed()
signal navigation_failed(reason: String)

# === EXPORTS ===
@export_group("Required References")
@export var camera_core: CameraCore
@export var target_movement_component: Node  # TargetMovementComponent
@export var config_component: Node  # 3CConfigComponent

@export_group("Click Properties")
@export var ground_layer_mask: int = 1  # Which layers to raycast against
@export var show_destination_marker: bool = true
@export var enable_debug_output: bool = false

# === CLICK STATE ===
var last_click_position: Vector3 = Vector3.ZERO
var click_pending: bool = false
var navigation_active: bool = false

func _ready():
	validate_setup()
	
	if enable_debug_output:
		print("TargetControlComponent: Initialized")

func validate_setup():
	"""Validate required references"""
	if not camera_core:
		push_error("TargetControlComponent: camera_core reference required")
	
	if not target_movement_component:
		push_error("TargetControlComponent: target_movement_component reference required")
	
	if not config_component:
		push_error("TargetControlComponent: config_component reference required")

# === INPUT HANDLING ===

func handle_input(event: InputEvent):
	"""Handle input events routed from InputManager"""
	if event is InputEventMouseButton:
		handle_mouse_click(event)

func handle_mouse_click(event: InputEventMouseButton):
	"""Handle mouse click for navigation"""
	# Only process left click on press
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	
	# Only process if mouse is visible (not captured for camera)
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return
	
	var click_position = perform_ground_raycast(event.position)
	
	if click_position != Vector3.ZERO:
		process_click_navigation(click_position)
	else:
		if enable_debug_output:
			print("TargetControlComponent: Click raycast failed")

# === RAYCAST LOGIC ===

func perform_ground_raycast(screen_position: Vector2) -> Vector3:
	"""Perform raycast from camera to ground"""
	if not camera_core:
		return Vector3.ZERO
	
	var viewport = camera_core.get_viewport()
	if not viewport:
		return Vector3.ZERO
	
	# Create raycast from camera
	var ray_origin = camera_core.project_ray_origin(screen_position)
	var ray_direction = camera_core.project_ray_normal(screen_position)
	
	# Setup raycast query
	var space_state = camera_core.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		ray_origin,
		ray_origin + ray_direction * 1000.0,  # Cast far
		ground_layer_mask
	)
	
	var result = space_state.intersect_ray(query)
	
	if result:
		if enable_debug_output:
			print("TargetControlComponent: Ground hit at ", result.position)
		return result.position
	
	return Vector3.ZERO

# === NAVIGATION PROCESSING ===

func process_click_navigation(world_position: Vector3):
	"""Process click navigation to world position"""
	last_click_position = world_position
	click_pending = true
	
	# Emit signal for other components
	click_target_received.emit(world_position)
	
	# Send to target movement component
	if target_movement_component and target_movement_component.has_method("navigate_to_position"):
		target_movement_component.navigate_to_position(world_position)
		navigation_active = true
		navigation_started.emit(world_position)
		
		if enable_debug_output:
			print("TargetControlComponent: Navigation started to ", world_position)
	
	# Show destination marker if enabled
	if show_destination_marker:
		show_destination_visual(world_position)

func show_destination_visual(position: Vector3):
	"""Show visual marker at destination (placeholder for now)"""
	# This could spawn a visual marker, play a particle effect, etc.
	# For now, just debug output
	if enable_debug_output:
		print("TargetControlComponent: Destination marker shown at ", position)

# === NAVIGATION CALLBACKS ===

func _on_navigation_completed():
	"""Called when navigation reaches destination"""
	navigation_active = false
	click_pending = false
	navigation_completed.emit()
	
	if enable_debug_output:
		print("TargetControlComponent: Navigation completed")

func _on_navigation_failed(reason: String):
	"""Called when navigation fails"""
	navigation_active = false
	click_pending = false
	navigation_failed.emit(reason)
	
	if enable_debug_output:
		print("TargetControlComponent: Navigation failed - ", reason)

# === NAVIGATION CONTROL ===

func cancel_navigation():
	"""Cancel current navigation"""
	if navigation_active and target_movement_component:
		if target_movement_component.has_method("cancel_navigation"):
			target_movement_component.cancel_navigation()
	
	navigation_active = false
	click_pending = false
	
	if enable_debug_output:
		print("TargetControlComponent: Navigation cancelled")

func is_navigation_possible(world_position: Vector3) -> bool:
	"""Check if navigation to position is possible"""
	# Basic validation - could be enhanced with pathfinding checks
	return world_position != Vector3.ZERO

# === PUBLIC API ===

func get_last_click_position() -> Vector3:
	"""Get last clicked world position"""
	return last_click_position

func is_navigation_active() -> bool:
	"""Check if navigation is currently active"""
	return navigation_active

func is_click_pending() -> bool:
	"""Check if a click is pending processing"""
	return click_pending

func set_ground_layer_mask(mask: int):
	"""Set which layers to raycast against"""
	ground_layer_mask = mask

func set_destination_marker_enabled(enabled: bool):
	"""Enable/disable destination marker display"""
	show_destination_marker = enabled

# === RAYCAST UTILITIES ===

func test_ground_position(world_position: Vector3) -> bool:
	"""Test if a world position is valid ground"""
	# Cast straight down from position
	var space_state = camera_core.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		world_position + Vector3(0, 1, 0),  # Start slightly above
		world_position + Vector3(0, -1, 0), # Cast down
		ground_layer_mask
	)
	
	var result = space_state.intersect_ray(query)
	return result != null

func get_ground_height_at_position(world_position: Vector3) -> float:
	"""Get ground height at specific world position"""
	var space_state = camera_core.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		Vector3(world_position.x, world_position.y + 10, world_position.z),
		Vector3(world_position.x, world_position.y - 10, world_position.z),
		ground_layer_mask
	)
	
	var result = space_state.intersect_ray(query)
	if result:
		return result.position.y
	
	return world_position.y

# === CONFIGURATION ===

func get_config_value(property_name: String, default_value):
	"""Get configuration value safely"""
	if config_component and config_component.has_method("get_config_value"):
		return config_component.get_config_value(property_name, default_value)
	return default_value

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get debug information about target control component"""
	return {
		"last_click_position": last_click_position,
		"navigation_active": navigation_active,
		"click_pending": click_pending,
		"ground_layer_mask": ground_layer_mask,
		"destination_marker_enabled": show_destination_marker,
		"mouse_mode": Input.mouse_mode,
		"can_receive_clicks": Input.mouse_mode == Input.MOUSE_MODE_VISIBLE
	}
