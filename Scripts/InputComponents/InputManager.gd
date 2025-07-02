# InputManager.gd - FIXED: WASD overrides but doesn't cancel click navigation
extends Node
class_name InputManager

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

# === SETTINGS ===
@export_group("Input Settings")
@export var input_deadzone = 0.05
@export var movement_update_frequency = 60

# === STATE ===
var character: CharacterBody3D
var camera_rig: CameraController

var current_raw_input = Vector2.ZERO
var last_sent_input = Vector2.ZERO
var movement_active = false
var movement_start_time = 0.0

var input_components: Array[Node] = []
var movement_update_timer = 0.0
var movement_update_interval: float

# FIXED: Track WASD override state
var wasd_is_overriding = false

func _ready():
	character = get_parent() as CharacterBody3D
	if not character:
		push_error("InputManager must be child of CharacterBody3D")
		return
	
	movement_update_interval = 1.0 / movement_update_frequency
	
	camera_rig = get_node_or_null("../../CAMERARIG") as CameraController
	if not camera_rig:
		push_warning("No CameraController found - click navigation may not work")
	
	call_deferred("find_input_components")

func _input(event):
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

func _physics_process(delta):
	handle_movement_input(delta)

func handle_movement_input(delta: float):
	movement_update_timer += delta
	
	var new_input = get_current_movement_input()
	var input_magnitude = new_input.length()
	var has_input = input_magnitude > input_deadzone
	
	if not has_input:
		new_input = Vector2.ZERO
	
	var was_moving = movement_active
	var is_moving = has_input
	
	# Movement state changes
	if is_moving and not was_moving:
		movement_active = true
		movement_start_time = Time.get_ticks_msec() / 1000.0
		current_raw_input = new_input
		last_sent_input = new_input
		movement_started.emit(new_input, input_magnitude)
	
	elif not is_moving and was_moving:
		movement_active = false
		current_raw_input = Vector2.ZERO
		last_sent_input = Vector2.ZERO
		movement_stopped.emit()
		
		# FIXED: When movement stops, clear click navigation if WASD was overriding
		if wasd_is_overriding:
			cancel_all_input_components()
			wasd_is_overriding = false
	
	elif is_moving and movement_update_timer >= movement_update_interval:
		if new_input.distance_to(last_sent_input) > 0.1:
			current_raw_input = new_input
			last_sent_input = new_input
			movement_updated.emit(new_input, input_magnitude)
		movement_update_timer = 0.0

# FIXED: New input priority logic
func get_current_movement_input() -> Vector2:
	# Check camera mode first
	if camera_rig and camera_rig.is_in_click_navigation_mode():
		# In click navigation mode - check WASD first (override priority)
		var wasd_input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		if wasd_input.length() > input_deadzone:
			# WASD is active - this overrides click navigation
			wasd_is_overriding = true
			return wasd_input
		else:
			# No WASD input - check click navigation
			wasd_is_overriding = false
			for component in input_components:
				if is_component_active(component):
					var component_input = component.get_movement_input()
					if component_input and component_input.length() > input_deadzone:
						return component_input
	else:
		# In orbit mode - WASD only
		wasd_is_overriding = false
		var wasd_input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		if wasd_input.length() > input_deadzone:
			cancel_all_input_components()  # Cancel click nav when switching to orbit
			return wasd_input
	
	return Vector2.ZERO

# Keep existing methods but remove the problematic cancel call
func cancel_all_input_components():
	for component in input_components:
		if component and component.has_method("cancel_input"):
			component.cancel_input()

# Rest of the methods stay the same...
func find_input_components():
	input_components.clear()
	for child in character.get_children():
		if child != self and child.has_method("get_movement_input"):
			input_components.append(child)

func is_component_active(component: Node) -> bool:
	return is_instance_valid(component) and component.has_method("is_active") and component.is_active()

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
		"camera_mode": camera_rig.get_mode_name(camera_rig.get_current_mode()) if camera_rig else "unknown",
		"wasd_overriding": wasd_is_overriding  # ADDED: Debug info
	}
