# Control3CManager.gd - Control Axis with 3C Configuration
extends Node
class_name Control3CManager

# === SIGNALS ===
signal movement_started(direction: Vector2, magnitude: float)
signal movement_updated(direction: Vector2, magnitude: float)
signal movement_stopped()
signal jump_pressed()
signal sprint_started()
signal sprint_stopped()
signal slow_walk_started()
signal slow_walk_stopped()
signal reset_pressed()
signal click_navigation(world_position: Vector3)

# === 3C CONFIGURATION ===
var active_3c_config: CharacterConfig

# === STATE ===
var character: CharacterBody3D
var camera_3c_manager: Camera3CManager

var current_raw_input = Vector2.ZERO
var last_sent_input = Vector2.ZERO
var movement_active = false
var movement_start_time = 0.0

var input_components: Array[Node] = []
var movement_update_timer = 0.0
var movement_update_interval: float = 1.0 / 60.0

var wasd_is_overriding = false

var click_destination: Vector3 = Vector3.ZERO
var has_click_destination: bool = false


func _ready():
	character = get_parent() as CharacterBody3D
	if not character:
		push_error("Control3CManager must be child of CharacterBody3D")
		return
	
	camera_3c_manager = get_node_or_null("../../CAMERARIG") as Camera3CManager
	if not camera_3c_manager:
		push_warning("No Camera3CManager found - click navigation may not work")
	
	call_deferred("find_input_components")

func configure_from_3c(config: CharacterConfig):
	"""Configure control behavior based on 3C settings"""
	active_3c_config = config
	
	movement_update_interval = 1.0 / 60.0  # Base update rate
	
	match config.control_type:
		CharacterConfig.ControlType.DIRECT:
			setup_direct_control()
		CharacterConfig.ControlType.TARGET_BASED:
			setup_target_based_control()
		CharacterConfig.ControlType.GUIDED:
			setup_guided_control()
		CharacterConfig.ControlType.CONSTRUCTIVE:
			setup_constructive_control()

func setup_direct_control():
	"""WASD-style direct control - immediate response"""
	# High precision, immediate response
	pass

func setup_target_based_control():
	"""Click-to-move style control - target selection"""
	# Click navigation primary, WASD override
	pass

func setup_guided_control():
	"""Assisted control - suggestions and guidance"""
	# Mixed input with assistance
	pass

func setup_constructive_control():
	"""Building/creation control - complex interactions"""
	# Multi-modal construction inputs
	pass

func _input(event):
	if not active_3c_config:
		return
	
	# Handle discrete inputs
	if event.is_action_pressed("jump"):
		jump_pressed.emit()
	elif event.is_action_pressed("reset"):
		reset_pressed.emit()
	elif event.is_action_pressed("sprint"):
		sprint_started.emit()
	elif event.is_action_released("sprint"):
		sprint_stopped.emit()
	elif event.is_action_pressed("walk"):
		slow_walk_started.emit()
	elif event.is_action_released("walk"):
		slow_walk_stopped.emit()
	
	# Handle click navigation for target-based control
	if active_3c_config.control_type == CharacterConfig.ControlType.TARGET_BASED:
		handle_click_navigation(event)

func handle_click_navigation(event):
	"""Handle click-to-move input"""
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if camera_3c_manager and camera_3c_manager.camera:
			var click_pos = perform_ground_raycast(event.position)
			if click_pos != Vector3.ZERO:
				click_navigation.emit(click_pos)
				# Set up pathfinding/movement toward click position
				setup_click_destination(click_pos)

func setup_click_destination(world_pos: Vector3):
	"""Set up movement toward clicked position"""
	# Store destination for navigation
	click_destination = world_pos
	has_click_destination = true
	
	# Show destination marker if available
	show_destination_marker(world_pos)

func show_destination_marker(world_pos: Vector3):
	"""Show visual marker at destination"""
	var marker = get_node_or_null("../../CURSOR")
	if marker:
		marker.global_position = world_pos
		marker.visible = true

func get_click_navigation_input() -> Vector2:
	"""Get movement input for click navigation"""
	if not has_click_destination:
		return Vector2.ZERO
	
	var distance = character.global_position.distance_to(click_destination)
	var arrival_threshold = 0.1
	
	if distance < arrival_threshold:
		has_click_destination = false
		hide_destination_marker()
		return Vector2.ZERO
	
	# Calculate direction toward destination
	var direction_3d = (click_destination - character.global_position).normalized()
	return world_to_input_direction(direction_3d)

func world_to_input_direction(direction_3d: Vector3) -> Vector2:
	"""Convert 3D world direction to 2D input direction"""
	if not camera_3c_manager or not camera_3c_manager.camera:
		return Vector2(direction_3d.x, direction_3d.z)
	
	var camera_transform = camera_3c_manager.camera.global_transform
	var cam_forward = -camera_transform.basis.z
	var cam_right = camera_transform.basis.x
	
	cam_forward.y = 0
	cam_right.y = 0
	cam_forward = cam_forward.normalized()
	cam_right = cam_right.normalized()
	
	var forward_dot = direction_3d.dot(cam_forward)
	var right_dot = direction_3d.dot(cam_right)
	
	return Vector2(right_dot, -forward_dot)

func hide_destination_marker():
	"""Hide destination marker"""
	var marker = get_node_or_null("../../CURSOR")
	if marker:
		marker.visible = false

func perform_ground_raycast(screen_pos: Vector2) -> Vector3:
	"""Raycast from camera to ground"""
	if not camera_3c_manager or not camera_3c_manager.camera:
		return Vector3.ZERO
	
	var camera = camera_3c_manager.camera
	var from = camera.project_ray_origin(screen_pos)
	var to = from + camera.project_ray_normal(screen_pos) * 1000
	
	var space_state = character.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1  # Ground layer
	
	var result = space_state.intersect_ray(query)
	if result:
		return result.position
	
	return Vector3.ZERO

func _process(delta):
	if not active_3c_config:
		return
	
	movement_update_timer += delta
	
	if movement_update_timer >= movement_update_interval:
		movement_update_timer = 0.0
		process_continuous_input()

func process_continuous_input():
	"""Process movement input based on 3C configuration"""
	current_raw_input = get_processed_movement_input()
	
	var input_magnitude = current_raw_input.length()
	var deadzone = active_3c_config.input_deadzone
	
	# Apply deadzone
	if input_magnitude < deadzone:
		if movement_active:
			movement_active = false
			movement_stopped.emit()
		current_raw_input = Vector2.ZERO
		last_sent_input = Vector2.ZERO
		return
	
	# Apply input smoothing based on control precision
	var smoothing = active_3c_config.input_smoothing * (2.0 - active_3c_config.control_precision)
	current_raw_input = last_sent_input.lerp(current_raw_input, 1.0 - smoothing)
	
	# Normalize if over deadzone
	if input_magnitude > deadzone:
		current_raw_input = current_raw_input.normalized() * min(input_magnitude, 1.0)
	
	# Emit movement signals
	if not movement_active:
		movement_active = true
		movement_start_time = Time.get_ticks_msec() / 1000.0
		movement_started.emit(current_raw_input, current_raw_input.length())
	else:
		movement_updated.emit(current_raw_input, current_raw_input.length())
	
	last_sent_input = current_raw_input

func get_processed_movement_input() -> Vector2:
	"""Get movement input based on control type and camera mode"""
	if not camera_3c_manager:
		return get_direct_wasd_input()
	
	var camera_mode = camera_3c_manager.get_current_mode()
	
	# Control type specific input processing
	match active_3c_config.control_type:
		CharacterConfig.ControlType.DIRECT:
			return get_direct_wasd_input()
		
		CharacterConfig.ControlType.TARGET_BASED:
			return get_target_based_input(camera_mode)
		
		CharacterConfig.ControlType.GUIDED:
			return get_guided_input(camera_mode)
		
		CharacterConfig.ControlType.CONSTRUCTIVE:
			return get_constructive_input(camera_mode)
	
	return Vector2.ZERO

func get_direct_wasd_input() -> Vector2:
	"""Pure WASD input"""
	var wasd_input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if wasd_input.length() > active_3c_config.input_deadzone:
		cancel_all_input_components()
		return wasd_input
	return Vector2.ZERO

func get_target_based_input(camera_mode) -> Vector2:
	"""Target-based input with WASD override"""
	# WASD override in click navigation mode
	if camera_mode == Camera3CManager.CameraMode.CLICK_NAVIGATION:
		var wasd_input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		if wasd_input.length() > active_3c_config.input_deadzone:
			wasd_is_overriding = true
			has_click_destination = false  # Cancel click navigation
			hide_destination_marker()
			return wasd_input
		
		# Check for click navigation movement
		wasd_is_overriding = false
		var click_input = get_click_navigation_input()
		if click_input.length() > active_3c_config.input_deadzone:
			return click_input
		
		# Check input components for other navigation
		for component in input_components:
			if is_component_active(component):
				var component_input = component.get_movement_input()
				if component_input and component_input.length() > active_3c_config.input_deadzone:
					return component_input
	else:
		# In orbit mode - WASD only
		wasd_is_overriding = false
		has_click_destination = false
		hide_destination_marker()
		var wasd_input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		if wasd_input.length() > active_3c_config.input_deadzone:
			cancel_all_input_components()
			return wasd_input
	
	return Vector2.ZERO

func get_guided_input(camera_mode) -> Vector2:
	"""Guided input with assistance"""
	# Base WASD input with potential modifications
	var base_input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	# Apply guidance based on context (simplified for now)
	return base_input

func get_constructive_input(camera_mode) -> Vector2:
	"""Constructive input for building/creation"""
	# Complex input processing for construction scenarios
	var base_input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	# Apply construction-specific modifiers
	return base_input

func cancel_all_input_components():
	"""Cancel all input components"""
	for component in input_components:
		if component and component.has_method("cancel_input"):
			component.cancel_input()

func find_input_components():
	"""Find all input components"""
	input_components.clear()
	for child in character.get_children():
		if child != self and child.has_method("get_movement_input"):
			input_components.append(child)

func is_component_active(component: Node) -> bool:
	"""Check if input component is active"""
	return is_instance_valid(component) and component.has_method("is_active") and component.is_active()

# === UTILITY FUNCTIONS ===

func get_movement_duration() -> float:
	if movement_active:
		return (Time.get_ticks_msec() / 1000.0) - movement_start_time
	return 0.0

func is_movement_active() -> bool:
	return movement_active

func get_current_input_direction() -> Vector2:
	return current_raw_input

func get_debug_info() -> Dictionary:
	return {
		"movement_active": movement_active,
		"current_input": current_raw_input,
		"movement_duration": get_movement_duration(),
		"component_count": input_components.size(),
		"control_type": CharacterConfig.ControlType.keys()[active_3c_config.control_type] if active_3c_config else "none",
		"wasd_overriding": wasd_is_overriding,
		"control_precision": active_3c_config.control_precision if active_3c_config else 0.0
	}
