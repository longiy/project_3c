# ControllerCharacter.gd - REFACTORED to use state-first design
extends CharacterBody3D

# NEW: Character state change signal
signal character_state_changed(old_state: String, new_state: String)

@export_group("Debug")
@export var reset_position = Vector3(0, 1, 0)
@export var reset_rotation = Vector3(0, 0, 0)

@export_group("Components")
@export var animation_controller: AnimationController
@export var camera: Camera3D

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

@export_group("State Machine")
@export var debug_states = false

# === STATE MACHINE ===
var state_machine: CharacterStateMachine

# === UNCHANGED VARIABLES ===
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
	# Setup state machine FIRST
	setup_state_machine()
	
	# Find input components (unchanged)
	click_navigation_component = get_node_or_null("ClickNavigationComponent") as ClickNavigationComponent
	
	for child in get_children():
		if child.has_method("get_movement_input"):
			input_components.append(child)
			print("Character: Found input component: ", child.name)
	
	if not animation_controller:
		push_warning("No AnimationController assigned - animations will not work")

func setup_state_machine():
	"""Initialize the character state machine"""
	state_machine = CharacterStateMachine.new()
	add_child(state_machine)
	
	# Setup basic movement states
	state_machine.setup_basic_states()
	
	# Connect state change signals
	state_machine.state_changed.connect(_on_character_state_changed)
	
	if debug_states:
		state_machine.state_entered.connect(_on_debug_state_entered)
		state_machine.state_exited.connect(_on_debug_state_exited)
	
	print("✅ Character state machine initialized")

func _on_character_state_changed(old_state: String, new_state: String):
	"""Handle character state changes"""
	# Emit signal for other systems (camera, audio, etc.)
	character_state_changed.emit(old_state, new_state)
	
	if debug_states:
		print("🎯 Character: ", old_state, " → ", new_state)

func _on_debug_state_entered(state_name: String):
	print("  ✅ Entered: ", state_name)

func _on_debug_state_exited(state_name: String):
	print("  ❌ Exited: ", state_name)

# === MAIN LOOPS ===

func _physics_process(delta):
	"""Main physics loop - delegated to state machine"""
	# Update input duration tracking (unchanged)
	update_input_duration_tracking(delta)
	
	# Delegate all physics to current state
	state_machine.update(delta)

func _input(event):
	"""Input handling - delegated to state machine"""
	state_machine.handle_input(event)

# === INPUT SYSTEM (UNCHANGED) ===

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

func apply_input_smoothing(raw_input: Vector2, delta: float) -> Vector2:
	"""Smooth input transitions to prevent jitter"""
	# Apply deadzone
	if raw_input.length() < input_deadzone:
		raw_input = Vector2.ZERO
	
	# Smooth the input
	smoothed_input = smoothed_input.lerp(raw_input, input_smoothing * delta)
	
	# Return smoothed input only if it's above deadzone
	return smoothed_input if smoothed_input.length() > input_deadzone else Vector2.ZERO

func cancel_all_input_components():
	"""Tell all input components to cancel their current actions"""
	for component in input_components:
		if component.has_method("cancel_input"):
			component.cancel_input()

# === MOVEMENT SYSTEM (UNCHANGED) ===

func calculate_movement_vector(input_dir: Vector2) -> Vector3:
	"""Calculate 3D movement vector from 2D input"""
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

# === UTILITY METHODS (UNCHANGED) ===

func reset_character_transform():
	"""Reset character to spawn position"""
	global_position = reset_position
	rotation_degrees = reset_rotation
	velocity = Vector3.ZERO
	smoothed_input = Vector2.ZERO
	jumps_remaining = max_jumps
	coyote_timer = 0.0
	cancel_all_input_components()
	
	# Reset state machine to grounded
	if state_machine:
		state_machine.change_state("grounded")
	
	print("Character reset to: ", reset_position)

# === PUBLIC API (UNCHANGED + NEW STATE API) ===

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

# === NEW STATE API ===

func get_current_character_state() -> String:
	"""Get current character state"""
	return state_machine.get_current_state_name() if state_machine else "unknown"

func get_previous_character_state() -> String:
	"""Get previous character state"""
	return state_machine.get_previous_state_name() if state_machine else "unknown"

func force_state_change(new_state: String):
	"""Force a state change (for cutscenes, etc.)"""
	if state_machine and state_machine.has_state(new_state):
		state_machine.change_state(new_state)
	else:
		push_warning("Cannot force change to unknown state: " + new_state)

func get_state_debug_info() -> Dictionary:
	"""Get debug information about current state"""
	if state_machine and state_machine.current_state:
		if state_machine.current_state.has_method("get_debug_info"):
			return state_machine.current_state.get_debug_info()
	
	return {"error": "No state debug info available"}

# === FUTURE EXPANSION METHODS ===

func add_combat_states():
	"""Add combat states when combat system is implemented"""
	if state_machine:
		state_machine.add_combat_states()
		print("⚔️ Combat states added to character")

func can_act() -> bool:
	"""Check if character can perform actions (not stunned, etc.)"""
	var current_state = get_current_character_state()
	var disabled_states = ["stunned", "dead", "cinematic"]
	return not current_state in disabled_states
