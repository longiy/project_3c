# TargetControlComponent.gd
# Handles point-and-click navigation
# PHASE 2: Updated to reference InputCore directly

extends Node
class_name TargetControlComponent

# ===== SIGNALS =====
signal navigate_command(target_position: Vector3)
signal destination_command(show: bool, position: Vector3)
signal character_look_command(target_direction: Vector3)
signal stop_navigation_command()

# ===== EXPORTS & CONFIGURATION =====
@export var character_core: CharacterBody3D
# UPDATED: Reference InputCore instead of InputPriorityManager
@export var input_core: InputCore
@export var camera_system: CameraSystem
@export var cursor_marker: Node3D

@export_group("Raycast Settings")
@export var raycast_distance: float = 1000.0
@export var ground_layer_mask: int = 1  # Environment layer

@export_group("Input Timing")
@export var drag_time_threshold: float = 0.1  # seconds - adjust as needed
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
	# UPDATED: Register with InputCore directly
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
		cursor_marker = get_node("../../CURSOR")
	if cursor_marker:
		cursor_marker.visible = false

func connect_to_character_rotation():
	# Connect to MovementComponent or CharacterComponent for rotation
	var movement_component_path = "../../../CHARACTER/CharacterComponents/MovementComponent"
	var character_core_path = "../../../CHARACTER/CharacterCore"
	
	var movement_component = get_node(movement_component_path)
	if movement_component and movement_component.has_method("_on_character_look_command"):
		character_look_command.connect(movement_component._on_character_look_command)
	else:
		# Try connecting to CharacterCore directly if it has rotation handling
		var character_core_node = get_node(character_core_path)
		if character_core_node and character_core_node.has_method("_on_character_look_command"):
			character_look_command.connect(character_core_node._on_character_look_command)

# ===== FRAME PROCESSING =====
func _process(delta):
	update_cursor_during_drag()
	check_navigation_timeout()

func update_cursor_during_drag():
	# Update cursor position while mouse button is held, even without motion
	if Input.is_action_pressed("click") and (is_dragging or has_drag_started):
		var mouse_pos = get_viewport().get_mouse_position()
		var target = raycast_to_ground(mouse_pos)
		if target != Vector3.ZERO:
			# Update marker position regardless of motion
			show_destination_marker(target)
			
			# Only update navigation if drag has started
			if has_drag_started:
				update_navigation_target(target)

func check_navigation_timeout():
	if is_navigating:
		var time_since_nav = Time.get_ticks_msec() / 1000.0 - last_navigation_time
		if time_since_nav > navigation_timeout:
			stop_navigation()

# ===== INPUT PROCESSING =====
func process_input(event: InputEvent):
	# Main input processing - called by InputCore
	if event is InputEventMouseButton:
		process_mouse_button(event)
	elif event is InputEventMouseMotion:
		process_mouse_motion(event)

func process_fallback_input(event: InputEvent):
	# Minimal fallback processing for click events
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			var target = raycast_to_ground(get_viewport().get_mouse_position())
			if target != Vector3.ZERO:
				start_navigation(target)

func process_mouse_button(event: InputEventMouseButton):
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			handle_click_start(event.position)
		else:
			handle_click_release(event.position)

func process_mouse_motion(event: InputEventMouseMotion):
	# UPDATED: Check activity with InputCore
	var is_active = input_core and input_core.is_input_active(InputCore.InputType.TARGET)
	
	if Input.is_action_pressed("click") and is_active:
		handle_drag_motion(event.position)

# ===== CLICK HANDLING =====
func handle_click_start(mouse_pos: Vector2):
	click_start_time = Time.get_ticks_msec() / 1000.0
	is_dragging = false
	has_drag_started = false
	
	# UPDATED: Set as active input
	if input_core:
		input_core.set_active_input(InputCore.InputType.TARGET)

func handle_click_release(mouse_pos: Vector2):
	var click_duration = Time.get_ticks_msec() / 1000.0 - click_start_time
	
	if click_duration < drag_time_threshold:
		# Quick click - immediate navigation
		handle_quick_click(mouse_pos)
	else:
		# Drag release - finalize drag navigation
		handle_drag_release(mouse_pos)
	
	# Reset drag state
	is_dragging = false
	has_drag_started = false

func handle_quick_click(mouse_pos: Vector2):
	var target = raycast_to_ground(mouse_pos)
	if target != Vector3.ZERO:
		start_navigation(target)

func handle_drag_motion(mouse_pos: Vector2):
	var current_time = Time.get_ticks_msec() / 1000.0
	var drag_duration = current_time - click_start_time
	
	if drag_duration >= drag_time_threshold and not has_drag_started:
		has_drag_started = true
		is_dragging = true
	
	if has_drag_started:
		var target = raycast_to_ground(mouse_pos)
		if target != Vector3.ZERO:
			show_destination_marker(target)
			update_navigation_target(target)

func handle_drag_release(mouse_pos: Vector2):
	if has_drag_started:
		var target = raycast_to_ground(mouse_pos)
		if target != Vector3.ZERO:
			finalize_navigation(target)

# ===== NAVIGATION CONTROL =====
func start_navigation(target_position: Vector3):
	navigation_target = target_position
	is_navigating = true
	last_navigation_time = Time.get_ticks_msec() / 1000.0
	
	show_destination_marker(target_position)
	navigate_command.emit(target_position)

func update_navigation_target(target_position: Vector3):
	if is_navigating:
		navigation_target = target_position
		last_navigation_time = Time.get_ticks_msec() / 1000.0
		navigate_command.emit(target_position)

func finalize_navigation(target_position: Vector3):
	navigation_target = target_position
	is_navigating = true
	last_navigation_time = Time.get_ticks_msec() / 1000.0
	
	navigate_command.emit(target_position)

func stop_navigation():
	is_navigating = false
	hide_destination_marker()
	stop_navigation_command.emit()

# ===== VISUAL FEEDBACK =====
func show_destination_marker(position: Vector3):
	if cursor_marker:
		cursor_marker.global_position = position
		cursor_marker.visible = true
		destination_command.emit(true, position)

func hide_destination_marker():
	if cursor_marker:
		cursor_marker.visible = false
		destination_command.emit(false, Vector3.ZERO)

# ===== RAYCASTING =====
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

# ===== PUBLIC API =====
func get_is_navigating() -> bool:
	return is_navigating

func get_navigation_target() -> Vector3:
	return navigation_target

func force_stop_navigation():
	stop_navigation()
