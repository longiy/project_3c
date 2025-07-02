# TargetControlComponent.gd
# Handles point-and-click navigation
# Casts rays to ground and generates navigation commands

extends Node
class_name TargetControlComponent

# Command signals
signal navigate_command(target_position: Vector3)
signal destination_command(show: bool, position: Vector3)

# References
var input_priority_manager: InputPriorityManager
var camera_system: CameraSystem
var cursor_marker: Node3D

# Navigation state
var is_dragging: bool = false
var is_navigating: bool = false
var navigation_target: Vector3
var navigation_timeout: float = 2.0
var last_navigation_time: float = 0.0

# Raycast properties
@export_group("Raycast Settings")
@export var raycast_distance: float = 1000.0
@export var ground_layer_mask: int = 1  # Environment layer

func _ready():
	# Get references
	input_priority_manager = get_node("../../InputCore/InputPriorityManager")
	if input_priority_manager:
		input_priority_manager.register_component(InputPriorityManager.InputType.TARGET, self)
	
	camera_system = get_node("../../../CAMERA") as CameraSystem
	if not camera_system:
		push_error("TargetControlComponent: CAMERA system not found")
		return
	
	# Get cursor marker reference
	cursor_marker = get_node("../../CURSOR")
	if cursor_marker:
		cursor_marker.visible = false
	
	print("TargetControlComponent: Initialized successfully")

func _process(delta):
	# Check navigation timeout
	if is_navigating:
		var time_since_nav = Time.get_ticks_msec() / 1000.0 - last_navigation_time
		if time_since_nav > navigation_timeout:
			stop_navigation()

func process_input(event: InputEvent):
	# Main input processing - called by InputPriorityManager
	if event is InputEventMouseButton:
		process_mouse_button(event)
	elif event is InputEventMouseMotion:
		process_mouse_motion(event)

func process_fallback_input(event: InputEvent):
	# No fallback behavior for click navigation
	pass

func process_mouse_button(event: InputEventMouseButton):
	# Handle mouse button events for click and drag
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Start click/drag operation
			if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
				var target = raycast_to_ground(event.position)
				if target != Vector3.ZERO:
					start_navigation(target)
					is_dragging = true
					print("TargetControlComponent: Started drag mode at ", target)
		else:
			# End drag operation
			if is_dragging:
				is_dragging = false
				# Final navigation target is already set during drag
				print("TargetControlComponent: Drag operation completed")
			else:
				print("TargetControlComponent: Mouse released but was not dragging")
			
func process_mouse_motion(event: InputEventMouseMotion):
	# Handle continuous drag updates
	if is_dragging and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		var target = raycast_to_ground(event.position)
		if target != Vector3.ZERO:
			# Update navigation target while dragging
			update_navigation_target(target)
			print("TargetControlComponent: Drag update to ", target)
			
			# Keep input priority active during drag AND update activity timestamp
			if input_priority_manager:
				input_priority_manager.set_active_input(InputPriorityManager.InputType.TARGET)
				# Force update activity to prevent timeout during drag
				input_priority_manager.update_input_activity(InputPriorityManager.InputType.TARGET)

func raycast_to_ground(screen_pos: Vector2) -> Vector3:
	# Cast ray from camera to ground
	if not camera_system:
		return Vector3.ZERO
	
	var camera = camera_system.get_camera_core()
	if not camera:
		return Vector3.ZERO
	
	# Get ray from camera
	var from = camera.project_ray_origin(screen_pos)
	var to = from + camera.project_ray_normal(screen_pos) * raycast_distance
	
	# Perform raycast
	var space_state = camera.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = ground_layer_mask
	
	var result = space_state.intersect_ray(query)
	
	if result:
		return result.position
	
	return Vector3.ZERO

func start_navigation(target_position: Vector3):
	# Start navigation to target position
	navigation_target = target_position
	is_navigating = true
	last_navigation_time = Time.get_ticks_msec() / 1000.0
	
	# Set this input as active priority
	if input_priority_manager:
		input_priority_manager.set_active_input(InputPriorityManager.InputType.TARGET)
		# Update activity timestamp to prevent immediate timeout
		input_priority_manager.update_input_activity(InputPriorityManager.InputType.TARGET)
	
	# Show cursor marker at target
	show_destination_marker(target_position)
	
	# Emit navigation command
	navigate_command.emit(target_position)
	
	print("TargetControlComponent: Navigation started to ", target_position)

func update_navigation_target(target_position: Vector3):
	# Update existing navigation during drag
	if not is_navigating:
		return
	
	navigation_target = target_position
	last_navigation_time = Time.get_ticks_msec() / 1000.0
	
	# Update marker position
	show_destination_marker(target_position)
	
	# Update activity timestamp to prevent timeout during drag
	if input_priority_manager:
		input_priority_manager.update_input_activity(InputPriorityManager.InputType.TARGET)
	
	# Emit new navigation command
	navigate_command.emit(target_position)

func stop_navigation():
	# Stop current navigation
	is_navigating = false
	is_dragging = false
	
	# Hide cursor marker
	hide_destination_marker()
	
	# Reset to direct control priority
	if input_priority_manager:
		input_priority_manager.reset_to_direct_control()
	
	print("TargetControlComponent: Navigation stopped")

func show_destination_marker(position: Vector3):
	# Show visual marker at destination
	if cursor_marker:
		cursor_marker.global_position = position
		cursor_marker.visible = true
		destination_command.emit(true, position)

func hide_destination_marker():
	# Hide destination marker
	if cursor_marker:
		cursor_marker.visible = false
		destination_command.emit(false, Vector3.ZERO)

func on_destination_reached():
	# Called when character reaches navigation target
	stop_navigation()

# Public API for other systems
func get_is_navigating() -> bool:
	return is_navigating

func get_navigation_target() -> Vector3:
	return navigation_target if is_navigating else Vector3.ZERO

func cancel_navigation():
	# Cancel current navigation
	stop_navigation()

# Debug info
func get_debug_info() -> Dictionary:
	return {
		"is_navigating": is_navigating,
		"is_dragging": is_dragging,
		"navigation_target": navigation_target,
		"time_since_last_nav": Time.get_ticks_msec() / 1000.0 - last_navigation_time if is_navigating else 0.0,
		"cursor_marker_visible": cursor_marker.visible if cursor_marker else false
	}
