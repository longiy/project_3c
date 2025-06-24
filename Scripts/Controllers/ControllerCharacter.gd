# ControllerCharacter.gd - Updated to use node-based state machine
extends CharacterBody3D

# === INSPECTOR CONFIGURATION ===
@export_group("Movement Speeds")
@export var walk_speed = 3.0
@export var run_speed = 6.0
@export var slow_walk_speed = 1.5
@export var air_speed_multiplier = 0.6

@export_group("Jump Properties")
@export var jump_height = 6.0
@export var max_air_jumps = 1
@export var coyote_time = 0.15
@export var jump_buffer_time = 0.1

@export_group("Physics")
@export var ground_acceleration = 15.0
@export var air_acceleration = 8.0
@export var deceleration = 18.0
@export var gravity_multiplier = 1.0

@export_group("Input Response")
@export var input_deadzone = 0.05
@export var input_smoothing = 12.0
@export var min_input_duration = 0.08
@export var rotation_speed = 12.0

@export_group("Ground Detection")
@export var ground_check_distance = 0.2
@export var slope_limit_degrees = 45.0

@export_group("Components")
@export var animation_controller: AnimationController
@export var camera: Camera3D

@export_group("Debug")
@export var enable_debug_logging = false
@export var reset_position = Vector3(0, 1, 0)

# === RUNTIME VARIABLES ===
var base_gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var coyote_timer = 0.0
var jump_buffer_timer = 0.0
var jumps_remaining = 0

# Input tracking
var input_start_time = 0.0
var is_input_active = false
var smoothed_input = Vector2.ZERO
var raw_input_direction = Vector2.ZERO

# Movement modes
var is_slow_walking = false
var is_running = false

# State machine - now a child node instead of created in code
var state_machine: CharacterStateMachine
var input_components: Array[Node] = []

func _ready():
	setup_character()
	setup_state_machine()
	find_input_components()

func setup_character():
	"""Initialize character properties"""
	jumps_remaining = max_air_jumps + 1  # +1 for ground jump
	if not animation_controller:
		push_warning("No AnimationController assigned")
	if not camera:
		push_warning("No Camera assigned - movement will not be camera-relative")

func setup_state_machine():
	"""Find and initialize the state machine"""
	# Look for CharacterStateMachine child node
	state_machine = get_node("CharacterStateMachine") as CharacterStateMachine
	
	if not state_machine:
		push_error("No CharacterStateMachine child node found! Please add one to the scene.")
		return
	
	# Validate the state machine setup
	if not state_machine.validate_state_setup():
		push_error("State machine validation failed!")
		return
	
	if enable_debug_logging:
		print("✅ Character: Using node-based state machine with ", state_machine.states.size(), " states")
		
		# Print state node information
		for state_name in state_machine.states.keys():
			var state_node = state_machine.get_state_node(state_name)
			if state_node:
				print("  📝 ", state_name, " → ", state_node.name)
			else:
				print("  ⚠️ ", state_name, " → No node")

func find_input_components():
	"""Automatically find input components"""
	input_components.clear()
	for child in get_children():
		if child == null or child == state_machine:
			continue
		# Check if it's an input component (has the required methods)
		if child.has_method("get_movement_input"):
			input_components.append(child)
			if enable_debug_logging:
				print("📝 Found input component: ", child.name)
	
	if enable_debug_logging:
		print("📝 Total input components: ", input_components.size())

func _input(event):
	if state_machine:
		state_machine.handle_input(event)

func _physics_process(delta):
	update_input_tracking(delta)
	update_timers(delta)
	
	if state_machine:
		state_machine.update(delta)

func update_input_tracking(delta):
	"""Track input duration and smoothing"""
	raw_input_direction = get_current_input()
	var has_input_now = raw_input_direction.length() > input_deadzone
	
	# Track input duration
	if has_input_now and not is_input_active:
		input_start_time = Time.get_ticks_msec() / 1000.0
		is_input_active = true
	elif not has_input_now and is_input_active:
		is_input_active = false
	
	# Apply smoothing
	if raw_input_direction.length() < input_deadzone:
		raw_input_direction = Vector2.ZERO
	
	smoothed_input = smoothed_input.lerp(raw_input_direction, input_smoothing * delta)
	if smoothed_input.length() < input_deadzone:
		smoothed_input = Vector2.ZERO

func update_timers(delta):
	"""Update jump-related timers"""
	coyote_timer = max(0.0, coyote_timer - delta)
	jump_buffer_timer = max(0.0, jump_buffer_timer - delta)

func get_current_input() -> Vector2:
	"""Input arbitration - WASD wins, then components"""
	# Check WASD first
	var wasd_input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if wasd_input.length() > input_deadzone:
		cancel_all_input_components()
		return wasd_input
	
	# Check input components safely
	for component in input_components:
		if component == null or not is_instance_valid(component):
			continue
		
		# Check if component is active
		var is_active = false
		if component.has_method("is_active"):
			is_active = component.is_active()
		elif component.has_method("get_movement_input"):
			# Fallback: if no is_active method, check if it returns non-zero input
			var test_input = component.get_movement_input()
			is_active = test_input.length() > input_deadzone
		
		if is_active and component.has_method("get_movement_input"):
			return component.get_movement_input()
	
	return Vector2.ZERO

func cancel_all_input_components():
	"""Cancel all active input components"""
	for component in input_components:
		if component.has_method("cancel_input"):
			component.cancel_input()

# === MOVEMENT CALCULATION ===

func calculate_movement_vector(input_dir: Vector2) -> Vector3:
	"""Convert 2D input to 3D movement relative to camera"""
	if input_dir.length() == 0:
		return Vector3.ZERO
	
	var movement_vector = Vector3.ZERO
	
	if camera:
		# Camera-relative movement
		var cam_transform = camera.global_transform.basis
		var cam_forward = Vector3(-cam_transform.z.x, 0, -cam_transform.z.z).normalized()
		var cam_right = Vector3(cam_transform.x.x, 0, cam_transform.x.z).normalized()
		movement_vector = cam_right * input_dir.x + cam_forward * (-input_dir.y)
	else:
		# World-space fallback
		movement_vector = Vector3(input_dir.x, 0, input_dir.y)
	
	return movement_vector.normalized()

func get_target_speed() -> float:
	"""Get target speed based on current movement mode"""
	update_movement_modes()
	
	if is_slow_walking:
		return slow_walk_speed
	elif is_running:
		return run_speed
	else:
		return walk_speed

func update_movement_modes():
	"""Update movement mode flags"""
	is_slow_walking = Input.is_action_pressed("walk")
	is_running = Input.is_action_pressed("sprint") and not is_slow_walking

func get_target_acceleration() -> float:
	"""Get acceleration based on ground state"""
	return ground_acceleration if is_on_floor() else air_acceleration

# === PHYSICS HELPERS ===

func apply_gravity(delta: float):
	"""Apply gravity if not grounded"""
	if not is_on_floor():
		velocity.y -= (base_gravity * gravity_multiplier) * delta

func apply_movement(movement_vector: Vector3, target_speed: float, acceleration: float, delta: float):
	"""Apply movement with acceleration"""
	if movement_vector.length() > 0:
		# Apply acceleration toward target
		velocity.x = move_toward(velocity.x, movement_vector.x * target_speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, movement_vector.z * target_speed, acceleration * delta)
		
		# Handle rotation
		rotate_toward_movement(movement_vector, delta)

func apply_deceleration(delta: float):
	"""Apply deceleration when no input"""
	velocity.x = move_toward(velocity.x, 0, deceleration * delta)
	velocity.z = move_toward(velocity.z, 0, deceleration * delta)

func rotate_toward_movement(movement_direction: Vector3, delta: float):
	"""Rotate character to face movement direction"""
	if movement_direction.length() > 0:
		var target_rotation = atan2(movement_direction.x, movement_direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)

func perform_jump(jump_force: float):
	"""Execute a jump with given force"""
	velocity.y = jump_force
	if jumps_remaining > 0:
		jumps_remaining -= 1
	
	if enable_debug_logging:
		print("🦘 Jump! Force: ", jump_force, " Remaining: ", jumps_remaining)

# === GROUND STATE MANAGEMENT ===

func update_ground_state():
	"""Update ground-related timers and jump counts"""
	if is_on_floor():
		coyote_timer = coyote_time
		jumps_remaining = max_air_jumps + 1  # Reset jumps
	elif coyote_timer > 0 and was_grounded_last_frame():
		# Still in coyote time
		pass
	else:
		# Fully airborne
		pass

func was_grounded_last_frame() -> bool:
	"""Check if character was grounded in previous frame"""
	# This would need to be tracked, for now return false
	return false

# === INPUT HELPERS ===

func get_input_duration() -> float:
	"""Get how long current input has been active"""
	if is_input_active:
		return (Time.get_ticks_msec() / 1000.0) - input_start_time
	return 0.0

func is_input_sustained(min_duration: float = 0.3) -> bool:
	"""Check if input has been sustained for minimum duration"""
	return get_input_duration() >= min_duration

func should_process_input() -> bool:
	"""Check if input should be processed (respects minimum duration)"""
	return is_input_active and (
		get_input_duration() >= min_input_duration or 
		get_movement_speed() > 0.5
	)

func get_current_input_direction() -> Vector2:
	"""Get current input direction for animation blend spaces"""
	return smoothed_input

# === JUMP HELPERS ===

func can_jump() -> bool:
	"""Check if character can jump"""
	return (is_on_floor() or coyote_timer > 0) and jumps_remaining > 0

func can_air_jump() -> bool:
	"""Check if character can air jump"""
	return not is_on_floor() and jumps_remaining > 0

func handle_jump_input():
	"""Handle jump input with buffering"""
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time

func try_consume_jump_buffer() -> bool:
	"""Try to consume jump buffer if conditions are met"""
	if jump_buffer_timer > 0 and can_jump():
		jump_buffer_timer = 0.0
		return true
	return false

# === UTILITY METHODS ===

func get_movement_speed() -> float:
	"""Get current horizontal movement speed"""
	return Vector3(velocity.x, 0, velocity.z).length()

func get_smoothed_input() -> Vector2:
	"""Get current smoothed input"""
	return smoothed_input

func reset_character():
	"""Reset character to initial state"""
	global_position = reset_position
	velocity = Vector3.ZERO
	smoothed_input = Vector2.ZERO
	jumps_remaining = max_air_jumps + 1
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	cancel_all_input_components()
	
	if state_machine:
		state_machine.change_state("idle")
	
	if enable_debug_logging:
		print("🔄 Character reset")

# === PUBLIC API ===

func get_current_state_name() -> String:
	"""Get current state name"""
	return state_machine.get_current_state_name() if state_machine else "none"

func get_previous_state_name() -> String:
	"""Get previous state name"""
	return state_machine.get_previous_state_name() if state_machine else "none"

func force_state_change(state_name: String):
	"""Force change to specific state (for debugging)"""
	if state_machine and state_machine.has_state(state_name):
		state_machine.change_state(state_name)

func get_debug_info() -> Dictionary:
	"""Get comprehensive debug information"""
	return {
		"current_state": get_current_state_name(),
		"movement_speed": get_movement_speed(),
		"is_grounded": is_on_floor(),
		"jumps_remaining": jumps_remaining,
		"coyote_timer": coyote_timer,
		"input_duration": get_input_duration(),
		"is_running": is_running,
		"is_slow_walking": is_slow_walking,
		"smoothed_input": smoothed_input,
		"raw_input": raw_input_direction,
		"state_machine_valid": state_machine != null,
		"current_state_node": state_machine.get_current_state_node().name if state_machine and state_machine.get_current_state_node() else "None"
	}
