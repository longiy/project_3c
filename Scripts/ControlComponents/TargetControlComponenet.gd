# TargetControlComponent.gd
# Handles point-and-click navigation
# Casts rays to ground and generates navigation commands

extends Node
class_name TargetControlComponent

# Command signals
signal navigate_command(target_position: Vector3)
signal destination_command(show: bool, position: Vector3)
signal character_look_command(target_direction: Vector3)
signal stop_navigation_command()

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

var drag_time_threshold: float = 0.1  # seconds - adjust as needed
var click_start_time: float = 0.0
var has_drag_started: bool = false

@export var character_core: CharacterBody3D
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
	
	# Connect character rotation signal
	connect_to_character_rotation()
	
func _process(delta):
	# Check navigation timeout
	if is_navigating:
		var time_since_nav = Time.get_ticks_msec() / 1000.0 - last_navigation_time
		if time_since_nav > navigation_timeout:
			stop_navigation()

func connect_to_character_rotation():
	# Connect to MovementComponent or CharacterComponent for rotation
	var movement_component = get_node("../../../CHARACTER/CharacterComponents/MovementComponent")
	if movement_component and movement_component.has_method("_on_character_look_command"):
		character_look_command.connect(movement_component._on_character_look_command)
	else:
		# Try connecting to CharacterCore directly if it has rotation handling
		var character_core = get_node("../../../CHARACTER/CharacterCore")
		if character_core and character_core.has_method("_on_character_look_command"):
			character_look_command.connect(character_core._on_character_look_command)

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
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			click_start_time = Time.get_ticks_msec() / 1000.0
			has_drag_started = false
			var target = raycast_to_ground(event.position)
			if target != Vector3.ZERO:
				start_navigation(target)
		else:
			# Mouse released
			var hold_duration = Time.get_ticks_msec() / 1000.0 - click_start_time
			
			if has_drag_started or hold_duration > drag_time_threshold:
				# Was dragging or held long enough - stop immediately
				stop_navigation_command.emit()
				stop_navigation()
			# Otherwise let normal click navigation continue
			
			is_dragging = false
			has_drag_started = false
			
func process_mouse_motion(event: InputEventMouseMotion):
	if is_navigating and Input.is_action_pressed("click"):  # mouse1 still held
		var hold_duration = Time.get_ticks_msec() / 1000.0 - click_start_time
		
		if hold_duration > drag_time_threshold and not has_drag_started:
			has_drag_started = true
			is_dragging = true
		
		if has_drag_started:
			var target = raycast_to_ground(event.position)
			if target != Vector3.ZERO:
				update_navigation_target(target)

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

# Modify start_navigation to include rotation
func start_navigation(target_position: Vector3):
	# Start navigation to target position
	navigation_target = target_position
	is_navigating = true
	last_navigation_time = Time.get_ticks_msec() / 1000.0
	
	# Set this input as active priority
	if input_priority_manager:
		input_priority_manager.set_active_input(InputPriorityManager.InputType.TARGET)
		# Update activity timestamp to prevent immediate timeout
		if input_priority_manager.has_method("update_input_activity"):
			input_priority_manager.update_input_activity(InputPriorityManager.InputType.TARGET)
	
	# Show cursor marker at target
	show_destination_marker(target_position)
	
	# Calculate and emit character rotation towards target
	emit_character_rotation_towards_target()
	
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
	
	# Continuously rotate character towards new target during drag
	emit_character_rotation_towards_target()
	
	# Emit new navigation command
	navigate_command.emit(target_position)

# Add this new helper function
func emit_character_rotation_towards_target():
	if not character_core:
		var character_core_node = get_node("../../../CHARACTER/CharacterCore")
		if character_core_node:
			character_core = character_core_node
	
	if character_core and navigation_target != Vector3.ZERO:
		var character_pos = character_core.global_position
		var direction_to_target = (navigation_target - character_pos)
		
		# Only rotate on Y axis (horizontal plane)
		direction_to_target.y = 0
		direction_to_target = direction_to_target.normalized()
		
		# Emit the direction for character rotation
		character_look_command.emit(direction_to_target)

func stop_navigation():
	# Stop current navigation
	is_navigating = false
	is_dragging = false  # ADD THIS LINE
	
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
		"is_dragging": is_dragging,  # ADD THIS LINE
		"navigation_target": navigation_target,
		"time_since_last_nav": Time.get_ticks_msec() / 1000.0 - last_navigation_time if is_navigating else 0.0,
		"cursor_marker_visible": cursor_marker.visible if cursor_marker else false
	}
