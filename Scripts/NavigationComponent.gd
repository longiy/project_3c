# NavigationComponent.gd - Create this as a new file
extends Node
class_name NavigationComponent

signal navigation_target_changed(target: Vector3)
signal navigation_cancelled()

@export var destination_marker: Node3D
@export var arrival_threshold = 0.5
@export var show_cursor_preview = true
@export var marker_disappear_delay = 1.0 ## How long marker stays after arrival (seconds)

var character: CharacterBody3D
var current_destination = Vector3.ZERO
var has_destination = false

# Preview state
var is_showing_preview = false
var preview_position = Vector3.ZERO

# Arrival delay
var arrival_timer = 0.0
var is_arrival_delay_active = false

func _ready():
	character = get_parent() as CharacterBody3D
	if not character:
		push_error("NavigationComponent must be child of CharacterBody3D")
		return
	
	# Connect to InputManager signals
	if InputManager:
		InputManager.click_navigation.connect(_on_click_navigation)
		InputManager.movement_input.connect(_on_movement_input)
		InputManager.mouse_mode_changed.connect(_on_mouse_mode_changed)
		print("NavigationComponent connected to InputManager")
	else:
		push_error("InputManager autoload not found!")

func _on_click_navigation(world_pos: Vector3):
	print("Navigation: Click received at ", world_pos)
	set_destination(world_pos)

func _on_movement_input(direction: Vector2):
	# WASD cancels click navigation
	if has_destination and direction.length() > 0.1:
		print("Navigation: Cancelled by WASD input")
		cancel_navigation()

func _on_mouse_mode_changed(is_camera_mode: bool):
	print("Navigation: Mouse mode changed, camera mode: ", is_camera_mode)
	if is_camera_mode:
		# Entering camera mode - hide marker
		hide_preview()
	else:
		# Entering cursor mode - show preview
		if show_cursor_preview:
			start_preview()

func set_destination(world_pos: Vector3):
	current_destination = world_pos
	has_destination = true
	is_showing_preview = false  # Stop preview mode when we have a real destination
	
	if destination_marker:
		destination_marker.global_position = world_pos
		destination_marker.visible = true
		# Optional: Change marker appearance to show it's a destination, not preview
		# You could scale it up or change material here
	
	navigation_target_changed.emit(world_pos)
	print("Navigation: Destination set to ", world_pos)

func cancel_navigation():
	has_destination = false
	navigation_cancelled.emit()
	
	# Return to preview mode if in cursor navigation
	if InputManager and InputManager.current_mode == InputManager.InputMode.CURSOR_NAVIGATION:
		start_preview()
	else:
		hide_preview()

func start_preview():
	is_showing_preview = true
	print("Navigation: Starting preview mode")
	update_preview_marker()

func hide_preview():
	is_showing_preview = false
	if destination_marker and not has_destination:
		destination_marker.visible = false
	print("Navigation: Hiding preview")

func update_preview_marker():
	if not is_showing_preview or not destination_marker or not InputManager:
		return
		
	var cursor_pos = InputManager.get_current_cursor_world_position()
	if cursor_pos != Vector3.ZERO:
		preview_position = cursor_pos
		destination_marker.global_position = cursor_pos
		destination_marker.visible = true

func _physics_process(_delta):
	# Handle arrival delay timer
	if is_arrival_delay_active:
		arrival_timer -= _delta
		if arrival_timer <= 0:
			complete_arrival()
		return  # Don't update preview during arrival delay
	
	# Only update preview when in preview mode (not when walking to destination)
	if is_showing_preview and not has_destination:
		update_preview_marker()
	
	# Check arrival at destination
	if has_destination and character:
		var distance = character.global_position.distance_to(current_destination)
		if distance < arrival_threshold:
			print("Navigation: Arrived at destination")
			start_arrival_delay()

func start_arrival_delay():
	has_destination = false
	is_arrival_delay_active = true
	arrival_timer = marker_disappear_delay
	navigation_cancelled.emit()
	print("Navigation: Starting arrival delay")

func complete_arrival():
	is_arrival_delay_active = false
	
	# Return to preview mode if in cursor navigation
	if InputManager and InputManager.current_mode == InputManager.InputMode.CURSOR_NAVIGATION:
		start_preview()
	else:
		hide_preview()
	print("Navigation: Arrival delay complete")

func get_navigation_direction() -> Vector2:
	if not has_destination:
		return Vector2.ZERO
		
	var direction_3d = (current_destination - character.global_position).normalized()
	
	# Convert to camera-relative movement
	if InputManager and InputManager.camera:
		var camera = InputManager.camera
		var cam_transform = camera.global_transform.basis
		var cam_forward = Vector3(-cam_transform.z.x, 0, -cam_transform.z.z).normalized()
		var cam_right = Vector3(cam_transform.x.x, 0, cam_transform.x.z).normalized()
		
		var forward_dot = direction_3d.dot(cam_forward)
		var right_dot = direction_3d.dot(cam_right)
		
		return Vector2(right_dot, -forward_dot)
	else:
		# Fallback to world coordinates
		return Vector2(direction_3d.x, direction_3d.z)

func is_navigation_active() -> bool:
	return has_destination
