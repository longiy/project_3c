# ControllerCharacter.gd - Updated to use node-based state machine
extends CharacterBody3D

# === INSPECTOR CONFIGURATION ===
@export_group("Movement Speeds")
@export var walk_speed = 3.0
@export var run_speed = 6.0
@export var slow_walk_speed = 1.5
@export var air_speed_multiplier = 0.6

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
@export var input_manager: InputManager  # NEW
@export var jump_system: JumpSystem  # NEW


@export_group("Debug")
@export var enable_debug_logging = false
@export var reset_position = Vector3(0, 1, 0)

# === RUNTIME VARIABLES ===
var base_gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# Movement modes
var is_slow_walking = false
var is_running = false

# State machine - now a child node instead of created in code
var state_machine: CharacterStateMachine

func _ready():
	setup_character()
	setup_state_machine()

# === UPDATE setup_character() ===
func setup_character():
	"""Initialize character properties"""
	if not animation_controller:
		push_warning("No AnimationController assigned")
	if not camera:
		push_warning("No Camera assigned - movement will not be camera-relative")
	if not input_manager:
		push_warning("No InputManager assigned - input will not work")
	if not jump_system:
		push_warning("No JumpSystem assigned - jumping will not work")

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

func _input(event):
	if state_machine:
		state_machine.handle_input(event)

func _physics_process(delta):
	
	if state_machine:
		state_machine.update(delta)

func get_current_input() -> Vector2:
	"""Get current input - delegated to InputManager"""
	return input_manager.get_current_input() if input_manager else Vector2.ZERO

# === UPDATE cancel_all_input_components() ===
func cancel_all_input_components():
	"""Cancel all active input components - delegated to InputManager"""
	if input_manager:
		input_manager.cancel_all_input_components()
		
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
	"""Execute a jump - delegated to JumpSystem"""
	if jump_system:
		jump_system.perform_jump(jump_force)

# === GROUND STATE MANAGEMENT ===

func update_ground_state():
	"""Update ground-related timers and jump counts - delegated to JumpSystem"""
	if jump_system:
		jump_system.update_ground_state()

# === INPUT HELPERS ===

func get_input_duration() -> float:
	"""Get how long current input has been active - delegated to InputManager"""
	return input_manager.get_input_duration() if input_manager else 0.0
	
func is_input_sustained(min_duration: float = 0.3) -> bool:
	"""Check if input has been sustained for minimum duration - delegated to InputManager"""
	return input_manager.is_input_sustained(min_duration) if input_manager else false

func should_process_input() -> bool:
	"""Check if input should be processed - delegated to InputManager"""
	return input_manager.should_process_input() if input_manager else false

# === UPDATE get_current_input_direction() ===
func get_current_input_direction() -> Vector2:
	"""Get current input direction for animation blend spaces"""
	return get_smoothed_input()  # Now uses InputManager

# === JUMP HELPERS ===

func can_jump() -> bool:
	"""Check if character can jump - delegated to JumpSystem"""
	return jump_system.can_jump() if jump_system else false

func can_air_jump() -> bool:
	"""Check if character can air jump - delegated to JumpSystem"""
	return jump_system.can_air_jump() if jump_system else false


func handle_jump_input():
	"""Handle jump input with buffering - delegated to JumpSystem"""
	if jump_system:
		jump_system.handle_jump_input()

func try_consume_jump_buffer() -> bool:
	"""Try to consume jump buffer - delegated to JumpSystem"""
	return jump_system.try_consume_jump_buffer() if jump_system else false

# === UTILITY METHODS ===

func get_movement_speed() -> float:
	"""Get current horizontal movement speed"""
	return Vector3(velocity.x, 0, velocity.z).length()

func get_smoothed_input() -> Vector2:
	"""Get current smoothed input - delegated to InputManager"""
	return input_manager.get_smoothed_input() if input_manager else Vector2.ZERO

func reset_character():
	"""Reset character to initial state"""
	global_position = reset_position
	velocity = Vector3.ZERO
	cancel_all_input_components()
	
	# Reset jump system
	if jump_system:
		jump_system.reset_jump_state()
	
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

# === UPDATE get_debug_info() ===
func get_debug_info() -> Dictionary:
	"""Get comprehensive debug information"""
	var base_info = {
		"current_state": get_current_state_name(),
		"movement_speed": get_movement_speed(),
		"is_grounded": is_on_floor(),
		"is_running": is_running,
		"is_slow_walking": is_slow_walking,
		"state_machine_valid": state_machine != null,
		"current_state_node": state_machine.get_current_state_node().name if state_machine and state_machine.get_current_state_node() else "None"
	}
	
	# Add input info from InputManager
	if input_manager:
		var input_info = input_manager.get_debug_info()
		base_info["input_duration"] = input_info.input_duration
		base_info["smoothed_input"] = input_info.smoothed_input
		base_info["raw_input"] = input_info.raw_input
		base_info["input_active"] = input_info.is_active
	else:
		base_info["input_duration"] = 0.0
		base_info["smoothed_input"] = Vector2.ZERO
		base_info["raw_input"] = Vector2.ZERO
		base_info["input_active"] = false
	
	# Add jump info from JumpSystem
	if jump_system:
		var jump_info = jump_system.get_debug_info()
		base_info["jumps_remaining"] = jump_info.jumps_remaining
		base_info["coyote_timer"] = jump_info.coyote_timer
		base_info["jump_buffer_timer"] = jump_info.jump_buffer_timer
		base_info["can_jump"] = jump_info.can_jump
		base_info["can_air_jump"] = jump_info.can_air_jump
	else:
		base_info["jumps_remaining"] = 0
		base_info["coyote_timer"] = 0.0
		base_info["jump_buffer_timer"] = 0.0
		base_info["can_jump"] = false
		base_info["can_air_jump"] = false
	
	return base_info
