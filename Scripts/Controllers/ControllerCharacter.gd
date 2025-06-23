# ControllerCharacter.gd - State machine only implementation
extends CharacterBody3D

@export_group("Debug")
@export var reset_position = Vector3(0, 1, 0)
@export var reset_rotation = Vector3(0, 0, 0)

# TO THIS:
@export_group("Components") 
@export var animation_controller: AnimationController
@export var camera: Camera3D
@export var state_machine: StateMachineCharacter  # NEW: Reference to scene node

@export_group("Movement Speeds")
@export var slow_walk_speed = 2.0
@export var walk_speed = 3.0
@export var run_speed = 6.0

@export_group("Movement Physics")
@export var slow_walk_acceleration = 12.0
@export var walk_acceleration = 15.0
@export var run_acceleration = 20.0
@export var deceleration = 18.0
@export var gravity_multiplier = 1

@export_group("Input Smoothing")
@export var input_deadzone = 0.05
@export var min_input_duration = 0.08
@export var input_smoothing = 12.0

@export_group("Rotation")
@export var rotation_speed = 6
@export var camera_relative_movement = true

@export_group("Jumping")
@export var jump_velocity = 6
@export var max_jumps = 2
@export var coyote_time = 0.1
@export var ground_check_distance = 0.2



# Movement duration tracking
var input_start_time = 0.0
var is_input_active = false
var last_input_direction = Vector2.ZERO
var smoothed_input = Vector2.ZERO

# Runtime variables
var base_gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var coyote_timer = 0.0
var jumps_remaining = 0
var is_running = false
var is_slow_walking = false

# Input components
var click_navigation_component: ClickNavigationComponent
var input_components: Array[Node] = []

func _ready():
	# Find input components automatically
	click_navigation_component = get_node_or_null("ClickNavigationComponent") as ClickNavigationComponent
	
	for child in get_children():
		if child.has_method("get_movement_input"):
			input_components.append(child)
	
	if input_components.size() > 0:
		print("Character: Found ", input_components.size(), " input components")
	
	if not animation_controller:
		push_warning("No AnimationController assigned - animations will not work")
	# Initialize state machine if assigned
	if state_machine:
		state_machine.setup_basic_states()
		print("✅ Character: State machine ready")
	else:
		push_error("StateMachine not assigned to CHARACTER!")
		
func _input(event):
	"""Forward input to state machine"""
	if state_machine:
		state_machine.handle_input(event)

func _physics_process(delta):
	"""Main physics update - only state machine logic"""
	update_input_duration_tracking(delta)
	
	if state_machine:
		state_machine.update(delta)

func update_input_duration_tracking(delta: float):
	"""Track input duration for minimum input filtering"""
	var raw_input = get_current_input()
	var has_input_now = raw_input.length() > input_deadzone
	
	if has_input_now and not is_input_active:
		input_start_time = Time.get_ticks_msec() / 1000.0
		is_input_active = true
	elif not has_input_now and is_input_active:
		is_input_active = false
	
	last_input_direction = raw_input

func apply_input_smoothing(raw_input: Vector2, delta: float) -> Vector2:
	"""Smooth input transitions to prevent jitter"""
	# Apply deadzone
	if raw_input.length() < input_deadzone:
		raw_input = Vector2.ZERO
	
	# Smooth the input
	smoothed_input = smoothed_input.lerp(raw_input, input_smoothing * delta)
	
	# Return smoothed input only if it's above deadzone
	return smoothed_input if smoothed_input.length() > input_deadzone else Vector2.ZERO

func get_current_input() -> Vector2:
	"""Input arbitration - WASD always wins, then check input components"""
	
	# 1. WASD input has highest priority
	var wasd_input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	if wasd_input.length() > input_deadzone:
		cancel_all_input_components()
		return wasd_input
	
	# 2. Check input components
	for component in input_components:
		if component.has_method("is_active") and component.is_active():
			if component.has_method("get_movement_input"):
				return component.get_movement_input()
	
	return Vector2.ZERO

func cancel_all_input_components():
	"""Tell all input components to cancel their current actions"""
	for component in input_components:
		if component.has_method("cancel_input"):
			component.cancel_input()

func calculate_movement_vector(input_dir: Vector2) -> Vector3:
	"""Convert 2D input to 3D movement vector"""
	var movement_vector = Vector3.ZERO
	
	if camera_relative_movement and camera:
		var cam_transform = camera.global_transform.basis
		var cam_forward = Vector3(-cam_transform.z.x, 0, -cam_transform.z.z).normalized()
		var cam_right = Vector3(cam_transform.x.x, 0, cam_transform.x.z).normalized()
		
		movement_vector = cam_right * input_dir.x + cam_forward * (-input_dir.y)
	else:
		movement_vector.x = input_dir.x
		movement_vector.z = input_dir.y
	
	return movement_vector

func reset_character_transform():
	"""Reset character to initial state"""
	global_position = reset_position
	rotation_degrees = reset_rotation
	velocity = Vector3.ZERO
	smoothed_input = Vector2.ZERO
	jumps_remaining = max_jumps
	coyote_timer = 0.0
	cancel_all_input_components()
	print("Character reset to: ", reset_position)

# === PUBLIC API METHODS ===

func get_movement_speed() -> float:
	"""Get current horizontal movement speed"""
	return Vector3(velocity.x, 0, velocity.z).length()

func get_current_input_direction() -> Vector2:
	"""Get current smoothed input direction"""
	return smoothed_input

func get_input_duration() -> float:
	"""Get how long current input has been active"""
	if is_input_active:
		var current_time = Time.get_ticks_msec() / 1000.0
		return current_time - input_start_time
	else:
		return 0.0

func is_input_sustained(min_duration: float = 0.3) -> bool:
	"""Check if input has been active for minimum duration"""
	return get_input_duration() >= min_duration

func get_current_character_state() -> String:
	"""Get current character state"""
	if state_machine:
		return state_machine.get_current_state_name()
	else:
		return "unknown"

func get_previous_character_state() -> String:
	"""Get previous character state"""
	if state_machine:
		return state_machine.get_previous_state_name()
	else:
		return "unknown"

func get_state_debug_info() -> Dictionary:
	"""Get debug information about current state"""
	if state_machine and state_machine.current_state:
		if state_machine.current_state.has_method("get_debug_info"):
			return state_machine.current_state.get_debug_info()
	
	return {
		"state_name": get_current_character_state(),
		"time_in_state": 0.0,
		"character_speed": get_movement_speed(),
		"character_grounded": is_on_floor()
	}
