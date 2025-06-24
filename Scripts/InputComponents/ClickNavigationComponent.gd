# ClickNavigationComponent.gd - Modular click navigation with signal-based dependencies
extends Node
class_name ClickNavigationComponent

# Signals for modular communication
signal navigation_started(destination: Vector3)
signal navigation_completed(destination: Vector3)
signal drag_mode_changed(is_dragging: bool)

@export_group("Click Navigation")
@export var camera: Camera3D
@export var destination_marker: Node3D
@export var arrival_threshold = 0.1
@export var show_cursor_preview = true
@export var marker_disappear_delay = 0.2

@export_group("Drag Mode")
@export var enable_drag_mode = true
@export var drag_update_rate = 0.01
@export var continuous_cursor_follow = true

@export_group("Component Control")
@export var enable_click_navigation = true
@export var auto_connect_to_camera = true
@export var respect_cinematic_mode = true

@export_group("External Dependencies")
@export var camera_responder: CameraResponder

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

# Cinematic mode tracking
var is_cinematic_mode_active = false

# Connection tracking
var is_connected_to_camera = false
var is_connected_to_responder = false

func _ready():
	setup_connections()

func setup_connections():
	"""Setup all modular connections"""
	character = get_parent() as CharacterBody3D
	if not character:
		push_error("ClickNavigationComponent must be child of CharacterBody3D")
		return
	
	# Setup camera connection
	if auto_connect_to_camera and not camera:
		var possible_paths = [
			"../../CAMERARIG/SpringArm3D/Camera3D",
			"../CAMERARIG/SpringArm3D/Camera3D",
			"/root/Scene/CAMERARIG/SpringArm3D/Camera3D"
		]
		
		for path in possible_paths:
			var found_camera = get_node_or_null(path) as Camera3D
			if found_camera:
				camera = found_camera
				print("✅ ClickNav: Auto-found camera at: ", path)
				break
	
	if not camera:
		push_error("Camera must be assigned or auto-found for ClickNavigationComponent")
		return
	
	# Connect to camera controller signals if available
	var camera_rig = camera.get_parent().get_parent()  # Camera3D -> SpringArm3D -> CameraRig
	if camera_rig and camera_rig.has_signal("mouse_mode_changed"):
		camera_rig.mouse_mode_changed.connect(_on_mouse_mode_changed)
		is_connected_to_camera = true
		print("✅ ClickNav: Connected to camera controller signals")
	
	# Setup camera responder connection
	if not camera_responder and respect_cinematic_mode:
		# Try to find CameraResponder
		var responder_paths = [
			"../../CAMERARIG/CameraResponder",
			"../CAMERARIG/CameraResponder",
			"/root/Scene/CAMERARIG/CameraResponder"
		]
		
		for path in responder_paths:
			var found_responder = get_node_or_null(path) as CameraResponder
			if found_responder:
				camera_responder = found_responder
				print("✅ ClickNav: Auto-found CameraResponder at: ", path)
				break
	
	# Connect to camera responder signals
	if camera_responder and camera_responder.has_signal("cinematic_mode_changed"):
		camera_responder.cinematic_mode_changed.connect(_on_cinematic_mode_changed)
		is_connected_to_responder = true
		print("✅ ClickNav: Connected to CameraResponder signals")
	
	# Initialize state
	is_mouse_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

# === SIGNAL HANDLERS ===

# Add this new method to ClickNavigationComponent.gd
func refresh_mouse_state_from_input():
	"""Refresh mouse state when cinematic mode exits"""
	# Wait a frame for Input.mouse_mode to be processed
	await get_tree().process_frame
	
	var new_mouse_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	print("📍 ClickNav: refresh_mouse_state - current: ", is_mouse_captured, " actual: ", new_mouse_captured)
	
	if new_mouse_captured != is_mouse_captured:
		is_mouse_captured = new_mouse_captured
		print("📍 ClickNav: Updated mouse state - captured: ", is_mouse_captured)
		
		# If mouse is not captured and we should handle input, show cursor preview
		if not is_mouse_captured and should_handle_input() and show_cursor_preview:
			is_showing_preview = true
			call_deferred("update_cursor_preview_current")
			print("📍 ClickNav: Cursor preview re-enabled")


func _on_mouse_mode_changed(captured: bool):
	"""React to camera controller mouse mode changes"""
	is_mouse_captured = captured
	
	if is_mouse_captured:
		hide_cursor_preview()
	else:
		if show_cursor_preview and enable_click_navigation:
			is_showing_preview = true
			call_deferred("update_cursor_preview_current")

func _on_cinematic_mode_changed(cinematic_active: bool):
	"""React to cinematic mode changes"""
	print("📍 ClickNav: Cinematic mode changed to: ", cinematic_active)
	is_cinematic_mode_active = cinematic_active
	
	if cinematic_active:
		# Cancel any active navigation when entering cinematic mode
		cancel_input()
		print("📍 ClickNav: Disabled due to cinematic mode")
	else:
		# When exiting cinematic mode, refresh our mouse state
		call_deferred("refresh_mouse_state_from_input")
		print("📍 ClickNav: Re-enabled after cinematic mode")

# === MODULAR CONTROL API ===

func set_enabled(enabled: bool):
	"""Enable/disable click navigation"""
	enable_click_navigation = enabled
	if not enabled:
		cancel_input()
		print("📍 ClickNav: Disabled")
	else:
		print("📍 ClickNav: Enabled")

func is_enabled() -> bool:
	return enable_click_navigation

func get_connection_status() -> Dictionary:
	"""Get connection status for debugging"""
	return {
		"connected_to_camera": is_connected_to_camera,
		"connected_to_responder": is_connected_to_responder,
		"has_camera": camera != null,
		"has_responder": camera_responder != null,
		"has_character": character != null,
		"has_marker": destination_marker != null,
		"enabled": enable_click_navigation,
		"respects_cinematic": respect_cinematic_mode,
		"cinematic_active": is_cinematic_mode_active
	}

func should_handle_input() -> bool:

	if not enable_click_navigation:
		return false
	
	if respect_cinematic_mode and is_cinematic_mode_active:
		return false
	
	if is_mouse_captured:
		return false
	
	return true

# Add this to ClickNavigationComponent.gd in _input method
func _input(event):
	if not should_handle_input():
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if enable_drag_mode:
				start_drag_mode(event.position)
			else:
				commit_to_destination(event.position)
		else:
			if is_dragging:
				stop_drag_mode()
	
	elif event is InputEventMouseMotion:
		if is_dragging and enable_drag_mode:
			update_drag_destination(event.position)
		elif show_cursor_preview and not is_dragging:
			update_cursor_preview(event.position)

func _physics_process(delta):
	if not enable_click_navigation:
		return
	
	# Handle arrival delay timer
	if is_arrival_delay_active:
		arrival_timer -= delta
		if arrival_timer <= 0:
			complete_arrival()
		return
	
	# Handle drag timer
	if is_dragging:
		drag_timer -= delta
		
		# Continuous cursor follow (Diablo style)
		if continuous_cursor_follow:
			var current_mouse_pos = get_viewport().get_mouse_position()
			var world_pos = raycast_to_world(current_mouse_pos)
			if world_pos != Vector3.ZERO:
				click_destination = world_pos
				if destination_marker:
					destination_marker.global_position = world_pos

# === PUBLIC INTERFACE FOR CHARACTER CONTROLLER ===

func is_active() -> bool:
	"""Check if this component is actively providing input"""
	if not enable_click_navigation:
		return false
	
	return has_click_destination or is_arrival_delay_active or is_dragging

func get_movement_input() -> Vector2:
	"""Get movement input vector for character controller"""
	if not enable_click_navigation or is_arrival_delay_active or not has_click_destination:
		return Vector2.ZERO
	
	var direction_3d = (click_destination - character.global_position).normalized()
	
	# Check arrival for BOTH single clicks and drag mode
	var distance = character.global_position.distance_to(click_destination)
	if distance < arrival_threshold:
		if is_dragging:
			if continuous_cursor_follow:
				return convert_to_camera_relative(direction_3d)
			else:
				return Vector2.ZERO
		else:
			start_arrival_delay()
			return Vector2.ZERO
	
	return convert_to_camera_relative(direction_3d)

func cancel_input():
	"""Cancel all navigation - called by character controller when WASD pressed"""
	has_click_destination = false
	is_dragging = false
	is_arrival_delay_active = false
	
	if is_dragging:
		drag_mode_changed.emit(false)
		is_dragging = false
	
	# Handle cursor preview based on current state
	if should_handle_input() and show_cursor_preview and destination_marker:
		is_showing_preview = true
		update_cursor_preview_current()
	elif destination_marker:
		destination_marker.visible = false

# === INTERNAL CLICK NAVIGATION LOGIC ===

func update_cursor_preview(screen_pos: Vector2):
	if not should_handle_input() or not destination_marker or not is_showing_preview:
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
		navigation_started.emit(world_pos)

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
		drag_mode_changed.emit(true)
		print("📍 ClickNav: Started drag mode")

func update_drag_destination(screen_pos: Vector2):
	"""Update destination while dragging (with rate limiting)"""
	if drag_timer <= 0:
		var world_pos = raycast_to_world(screen_pos)
		if world_pos != Vector3.ZERO:
			set_click_destination(world_pos)
			drag_timer = drag_update_rate

func stop_drag_mode():
	"""Stop drag mode"""
	is_dragging = false
	drag_mode_changed.emit(false)
	print("📍 ClickNav: Stopped drag mode")

func start_arrival_delay():
	"""Start the arrival delay - marker stays visible for a bit"""
	var final_destination = click_destination
	has_click_destination = false
	is_arrival_delay_active = true
	arrival_timer = marker_disappear_delay
	navigation_completed.emit(final_destination)

func complete_arrival():
	"""Complete the arrival process and clean up"""
	is_arrival_delay_active = false
	
	if should_handle_input() and show_cursor_preview:
		is_showing_preview = true
		update_cursor_preview_current()
	elif destination_marker:
		destination_marker.visible = false

func update_cursor_preview_current():
	if is_showing_preview and should_handle_input():
		var mouse_pos = get_viewport().get_mouse_position()
		update_cursor_preview(mouse_pos)

func convert_to_camera_relative(direction_3d: Vector3) -> Vector2:
	"""Convert 3D world direction to camera-relative 2D input"""
	if camera:
		var cam_transform = camera.global_transform.basis
		var cam_forward = Vector3(-cam_transform.z.x, 0, -cam_transform.z.z).normalized()
		var cam_right = Vector3(cam_transform.x.x, 0, cam_transform.x.z).normalized()
		
		var forward_dot = direction_3d.dot(cam_forward)
		var right_dot = direction_3d.dot(cam_right)
		
		return Vector2(right_dot, -forward_dot)
	else:
		return Vector2(direction_3d.x, direction_3d.z)

# === DEBUG AND TESTING ===

func get_debug_info() -> Dictionary:
	"""Get debug information"""
	var connection_status = get_connection_status()
	
	var debug_info = {
		"has_destination": has_click_destination,
		"is_dragging": is_dragging,
		"is_arrival_delay": is_arrival_delay_active,
		"is_showing_preview": is_showing_preview,
		"mouse_captured": is_mouse_captured,
		"should_handle_input": should_handle_input(),
		"current_destination": click_destination,
		"arrival_timer": arrival_timer
	}
	
	debug_info.merge(connection_status)
	return debug_info
