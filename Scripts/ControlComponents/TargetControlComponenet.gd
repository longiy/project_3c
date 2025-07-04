# TargetControlComponent.gd
# STEP 4: Verified signal connections with proper error handling

extends Node
class_name TargetControlComponent

# ===== SIGNALS =====
signal navigate_command(target_position: Vector3)
signal destination_command(show: bool, position: Vector3)
signal character_look_command(target_direction: Vector3)
signal stop_navigation_command()

# ===== EXPORTS & CONFIGURATION =====
@export var character_core: CharacterBody3D
@export var input_core: InputCore
@export var camera_system: CameraSystem
@export var cursor_marker: Node3D
@export var movement_component: MovementComponent

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

func _ready():
	find_system_references()
	setup_signal_connections()
	setup_cursor_marker()
	print("TargetControlComponent: Initialized successfully")

func find_system_references():
	if not input_core:
		push_error("TargetControlComponent: input_core not assigned")
		return
	
	input_core.register_component(InputCore.InputType.TARGET, self)
	
	if not camera_system:
		push_error("TargetControlComponent: camera_system not assigned")
		return
	
	if not cursor_marker:
		push_error("TargetControlComponent: cursor_marker not assigned")

func setup_signal_connections():
	connect_to_movement_component()

func setup_cursor_marker():
	if not cursor_marker:
		push_error("TargetControlComponent: cursor_marker not assigned")
	if cursor_marker:
		cursor_marker.visible = false

func connect_to_movement_component():
	if not movement_component:
		push_error("TargetControlComponent: movement_component not assigned in Inspector")
		return
	
	# Connect all navigation signals to MovementComponent with verification
	if movement_component.has_method("_on_navigate_command"):
		if not navigate_command.is_connected(movement_component._on_navigate_command):
			navigate_command.connect(movement_component._on_navigate_command)
			print("TargetControlComponent: Connected navigate_command to MovementComponent")
		else:
			print("TargetControlComponent: navigate_command already connected")
	else:
		push_error("TargetControlComponent: MovementComponent missing _on_navigate_command method")
	
	if movement_component.has_method("_on_character_look_command"):
		if not character_look_command.is_connected(movement_component._on_character_look_command):
			character_look_command.connect(movement_component._on_character_look_command)
			print("TargetControlComponent: Connected character_look_command to MovementComponent")
		else:
			print("TargetControlComponent: character_look_command already connected")
	else:
		push_error("TargetControlComponent: MovementComponent missing _on_character_look_command method")
	
	if movement_component.has_method("_on_stop_navigation_command"):
		if not stop_navigation_command.is_connected(movement_component._on_stop_navigation_command):
			stop_navigation_command.connect(movement_component._on_stop_navigation_command)
			print("TargetControlComponent: Connected stop_navigation_command to MovementComponent")
		else:
			print("TargetControlComponent: stop_navigation_command already connected")
	else:
		push_error("TargetControlComponent: MovementComponent missing _on_stop_navigation_command method")
	
	# STEP 4: Connect to movement feedback signals for bidirectional communication
	if movement_component.has_signal("navigation_state_changed"):
		if not movement_component.navigation_state_changed.is_connected(_on_movement_navigation_state_changed):
			movement_component.navigation_state_changed.connect(_on_movement_navigation_state_changed)
			print("TargetControlComponent: Connected to MovementComponent.navigation_state_changed")

# ===== BIDIRECTIONAL COMMUNICATION =====
func _on_movement_navigation_state_changed(is_nav: bool, target: Vector3):
	# Sync our state with MovementComponent
	if not is_nav and is_navigating:
		# Navigation was stopped by MovementComponent
		is_navigating = false
		hide_destination_marker()
		print("TargetControlComponent: Navigation stopped by MovementComponent")

# ===== FRAME PROCESSING =====
func _process(delta):
	update_cursor_during_drag()
	check_navigation_timeout()

func update_cursor_during_drag():
	# Only update cursor if not in orbit mode
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return
		
	# Use clicknav action instead of "click"
	if Input.is_action_pressed("clicknav") and (is_dragging or has_drag_started):
		var mouse_pos = get_viewport().get_mouse_position()
		var target = raycast_to_ground(mouse_pos)
		if target != Vector3.ZERO:
			show_destination_marker(target)
			
			if has_drag_started:
				update_navigation_target(target)

func check_navigation_timeout():
	if is_navigating:
		var time_since_nav = Time.get_ticks_msec() / 1000.0 - last_navigation_time
		if time_since_nav > navigation_timeout:
			stop_navigation()

# ===== INPUT PROCESSING =====
func process_input(event: InputEvent):
	# Only process input when not in orbit mode
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return  # Orbit mode is active - ignore all target control input
	
	# Main input processing - called by InputCore
	if event is InputEventMouseButton:
		process_mouse_button(event)
	elif event is InputEventMouseMotion:
		process_mouse_motion(event)

func process_fallback_input(event: InputEvent):
	# Minimal fallback processing for click events
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		var mouse_pos = get_viewport().get_mouse_position()
		var target = raycast_to_ground(mouse_pos)
		if target != Vector3.ZERO:
			finalize_navigation(target)

func process_mouse_button(event: InputEventMouseButton):
	if event.is_action("clicknav"):  # Left click
		if event.pressed:
			handle_click_start(event.position)
		else:
			handle_click_release(event.position)

func process_mouse_motion(event: InputEventMouseMotion):
	# Track dragging state during click
	if Input.is_action_pressed("clicknav"):
		var time_held = Time.get_ticks_msec() / 1000.0 - click_start_time
		if time_held > drag_time_threshold and not has_drag_started:
			has_drag_started = true
			is_dragging = true

func handle_click_start(mouse_pos: Vector2):
	click_start_time = Time.get_ticks_msec() / 1000.0
	is_dragging = false
	has_drag_started = false

func handle_click_release(mouse_pos: Vector2):
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
	
	# ADDED: Emit look command to make character face target immediately
	if character_core:
		var current_position = character_core.global_position
		var direction_to_target = (target_position - current_position).normalized()
		direction_to_target.y = 0  # Keep on horizontal plane
		
		if direction_to_target.length() > 0.1:
			character_look_command.emit(direction_to_target)

func update_navigation_target(target_position: Vector3):
	if is_navigating:
		navigation_target = target_position
		last_navigation_time = Time.get_ticks_msec() / 1000.0
		navigate_command.emit(target_position)
		
		# ADDED: Emit look command to make character face cursor during drag
		if character_core:
			var current_position = character_core.global_position
			var direction_to_target = (target_position - current_position).normalized()
			direction_to_target.y = 0  # Keep on horizontal plane
			
			if direction_to_target.length() > 0.1:
				character_look_command.emit(direction_to_target)

func finalize_navigation(target_position: Vector3):
	navigation_target = target_position
	is_navigating = true
	last_navigation_time = Time.get_ticks_msec() / 1000.0
	
	navigate_command.emit(target_position)
	
	# ADDED: Emit look command to make character face target immediately
	if character_core:
		var current_position = character_core.global_position
		var direction_to_target = (target_position - current_position).normalized()
		direction_to_target.y = 0  # Keep on horizontal plane
		
		if direction_to_target.length() > 0.1:
			character_look_command.emit(direction_to_target)

func stop_navigation():
	is_navigating = false
	hide_destination_marker()
	# Don't emit stop command if cancelled by orbit mode
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
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
