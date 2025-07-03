# TargetControlComponent.gd
# Point-and-click navigation
# Simple fix: Replace InputPriorityManager with InputCore

extends Node
class_name TargetControlComponent

# ===== SIGNALS =====
signal navigate_command(target_position: Vector3)
signal destination_command(show: bool, position: Vector3)
signal character_look_command(target_direction: Vector3)
signal stop_navigation_command()

# ===== EXPORTS & CONFIGURATION =====
@export var character_core: CharacterBody3D
@export var input_core: InputCore  # CHANGED: input_priority_manager → input_core
@export var camera_system: CameraSystem
@export var cursor_marker: Node3D

@export_group("Raycast Settings")
@export var raycast_distance: float = 1000.0
@export var ground_layer_mask: int = 1

@export_group("Input Timing")
@export var drag_time_threshold: float = 0.1
@export var navigation_timeout: float = 2.0

# ===== NAVIGATION STATE =====
var is_navigating: bool = false
var navigation_target: Vector3
var last_navigation_time: float = 0.0

# ===== INPUT STATE =====
var is_dragging: bool = false
var has_drag_started: bool = false
var click_start_time: float = 0.0

# ===== INITIALIZATION =====
func _ready():
	find_system_references()
	setup_signal_connections()
	setup_cursor_marker()
	print("TargetControlComponent: Initialized successfully")

func find_system_references():
	# CHANGED: input_priority_manager → input_core
	if not input_core:
		input_core = get_node("../../InputCore")
	if input_core:
		input_core.register_component(InputCore.InputType.TARGET, self)
	
	if not camera_system:
		camera_system = get_node("../../../CAMERA") as CameraSystem
	if not camera_system:
		push_error("TargetControlComponent: CAMERA system not found")
		return

func setup_signal_connections():
	connect_to_character_rotation()

func setup_cursor_marker():
	# Fallback to node path if export not set
	if not cursor_marker:
		cursor_marker = get_node("../../../CursorMarker")
	
	if cursor_marker:
		cursor_marker.visible = false

func connect_to_character_rotation():
	if character_look_command.is_connected(_on_character_look_command):
		return
	
	character_look_command.connect(_on_character_look_command)

func _on_character_look_command(direction: Vector3):
	print("TargetControlComponent: Character look towards ", direction)

# ===== INPUT PROCESSING =====
func process_input(event: InputEvent):
	if event is InputEventMouseButton:
		process_mouse_button(event)
	elif event is InputEventMouseMotion:
		process_mouse_motion(event)

func process_fallback_input(event: InputEvent):
	# No fallback behavior for click navigation
	pass

func process_mouse_button(event: InputEventMouseButton):
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			handle_mouse_press(event)
		else:
			handle_mouse_release()

func handle_mouse_press(event: InputEventMouseButton):
	click_start_time = Time.get_ticks_msec() / 1000.0
	has_drag_started = false
	var target = raycast_to_ground(event.position)
	if target != Vector3.ZERO:
		start_navigation(target)

func handle_mouse_release():
	var hold_duration = Time.get_ticks_msec() / 1000.0 - click_start_time
	
	if has_drag_started or hold_duration > drag_time_threshold:
		stop_navigation_command.emit()
		stop_navigation()
	else:
		pass
	
	reset_input_state()

func reset_input_state():
	is_dragging = false
	has_drag_started = false

func process_mouse_motion(event: InputEventMouseMotion):
	if is_navigating and Input.is_action_pressed("click"):
		var hold_duration = Time.get_ticks_msec() / 1000.0 - click_start_time
		
		if hold_duration > drag_time_threshold and not has_drag_started:
			start_drag_mode()
		
		if has_drag_started:
			handle_drag_motion(event)

func start_drag_mode():
	has_drag_started = true
	is_dragging = true

func handle_drag_motion(event: InputEventMouseMotion):
	var target = raycast_to_ground(event.position)
	if target != Vector3.ZERO:
		update_navigation_target(target)

# ===== RAYCAST OPERATIONS =====
func raycast_to_ground(screen_pos: Vector2) -> Vector3:
	if not camera_system:
		return Vector3.ZERO
	
	var camera = camera_system.get_camera_core()
	if not camera:
		return Vector3.ZERO
	
	var from = camera.project_ray_origin(screen_pos)
	var to = from + camera.project_ray_normal(screen_pos) * raycast_distance
	
	var space_state = camera.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = ground_layer_mask
	
	var result = space_state.intersect_ray(query)
	
	if result:
		return result.position
	
	return Vector3.ZERO

# ===== NAVIGATION MANAGEMENT =====
func start_navigation(target_position: Vector3):
	navigation_target = target_position
	is_navigating = true
	last_navigation_time = Time.get_ticks_msec() / 1000.0
	
	activate_input_priority()
	show_destination_marker(target_position)
	emit_character_rotation_towards_target()
	navigate_command.emit(target_position)
	
	print("TargetControlComponent: Navigation started to ", target_position)

func update_navigation_target(target_position: Vector3):
	if not is_navigating:
		return
	
	navigation_target = target_position
	last_navigation_time = Time.get_ticks_msec() / 1000.0
	
	show_destination_marker(target_position)
	update_input_activity()
	emit_character_rotation_towards_target()
	navigate_command.emit(target_position)

func stop_navigation():
	is_navigating = false
	is_dragging = false
	
	hide_destination_marker()
	reset_input_priority()
	
	print("TargetControlComponent: Navigation stopped")

func activate_input_priority():
	# CHANGED: input_priority_manager → input_core
	if input_core:
		input_core.force_input_type(InputCore.InputType.TARGET)
		update_input_activity()

func update_input_activity():
	# CHANGED: input_priority_manager → input_core
	if input_core and input_core.has_method("update_activity_tracking"):
		input_core.update_activity_tracking(InputCore.InputType.TARGET)

func reset_input_priority():
	# CHANGED: input_priority_manager → input_core
	if input_core:
		input_core.reset_to_direct_control()

# ===== CHARACTER ROTATION =====
func emit_character_rotation_towards_target():
	var char_core = character_core
	if not char_core:
		char_core = get_node("../../../CHARACTER/CharacterCore")
		character_core = char_core
	
	if char_core and navigation_target != Vector3.ZERO:
		var character_pos = char_core.global_position
		var direction_to_target = (navigation_target - character_pos)
		
		direction_to_target.y = 0
		direction_to_target = direction_to_target.normalized()
		
		character_look_command.emit(direction_to_target)

# ===== UI FEEDBACK =====
func show_destination_marker(position: Vector3):
	if cursor_marker:
		cursor_marker.global_position = position
		cursor_marker.visible = true
		destination_command.emit(true, position)

func hide_destination_marker():
	if cursor_marker:
		cursor_marker.visible = false
		destination_command.emit(false, Vector3.ZERO)

# ===== PUBLIC API =====
func on_destination_reached():
	stop_navigation()

func get_is_navigating() -> bool:
	return is_navigating

func get_navigation_target() -> Vector3:
	return navigation_target if is_navigating else Vector3.ZERO

func cancel_navigation():
	stop_navigation()

# ===== DEBUG =====
func get_debug_info() -> Dictionary:
	return {
		"is_navigating": is_navigating,
		"is_dragging": is_dragging,
		"navigation_target": navigation_target,
		"time_since_last_nav": Time.get_ticks_msec() / 1000.0 - last_navigation_time if is_navigating else 0.0,
		"cursor_marker_visible": cursor_marker.visible if cursor_marker else false
	}
