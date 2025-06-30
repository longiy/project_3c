# DirectMovementComponent.gd - WASD movement physics
extends Node
class_name CCC_DirectMovementComponent

# === SIGNALS ===
signal movement_started()
signal movement_stopped()
signal speed_changed(new_speed: float)

# === EXPORTS ===
@export_group("Required References")
@export var character_core: CCC_CharacterCore
@export var camera_core: CCC_CameraCore
@export var config_component: Node  # 3CConfigComponent

@export_group("Movement Properties")
@export var enable_camera_relative: bool = true
@export var enable_debug_output: bool = false

# === MOVEMENT STATE ===
var current_input_direction: Vector2 = Vector2.ZERO
var current_movement_direction: Vector3 = Vector3.ZERO
var current_speed: float = 0.0
var target_speed: float = 0.0
var is_moving: bool = false

# === JUMP STATE ===
var jump_requested: bool = false
var can_jump: bool = true

func _ready():
	validate_setup()
	
	if enable_debug_output:
		print("DirectMovementComponent: Initialized")

func validate_setup():
	"""Validate required references"""
	if not character_core:
		push_error("DirectMovementComponent: character_core reference required")
	
	if not camera_core:
		push_error("DirectMovementComponent: camera_core reference required")
	
	if not config_component:
		push_error("DirectMovementComponent: config_component reference required")

func _physics_process(delta):
	process_movement(delta)
	process_jumping()

# === MOVEMENT PROCESSING ===

func process_movement(delta: float):
	"""Process movement input and apply to character"""
	if not character_core:
		return
	
	# Calculate target speed based on input magnitude
	var input_magnitude = current_input_direction.length()
	target_speed = calculate_target_speed(input_magnitude)
	
	# Smooth speed transitions
	var acceleration = get_config_value("acceleration", 15.0)
	var deceleration = get_config_value("deceleration", 20.0)
	var speed_change_rate = acceleration if target_speed > current_speed else deceleration
	
	current_speed = move_toward(current_speed, target_speed, speed_change_rate * delta)
	
	# Calculate movement direction
	if input_magnitude > 0:
		current_movement_direction = calculate_movement_direction(current_input_direction)
	else:
		current_movement_direction = Vector3.ZERO
	
	# Apply movement to character
	var movement_velocity = current_movement_direction * current_speed
	character_core.apply_movement_velocity(movement_velocity)
	
	# Update movement state
	update_movement_state()

func calculate_target_speed(input_magnitude: float) -> float:
	"""Calculate target speed based on input magnitude"""
	if input_magnitude <= 0:
		return 0.0
	
	if config_component and config_component.has_method("get_speed_for_input_magnitude"):
		return config_component.get_speed_for_input_magnitude(input_magnitude)
	
	# Fallback speed calculation
	var walk_speed = get_config_value("walk_speed", 3.0)
	var run_speed = get_config_value("run_speed", 6.0)
	var sprint_speed = get_config_value("sprint_speed", 9.0)
	
	if input_magnitude <= 0.5:
		return walk_speed
	elif input_magnitude <= 0.8:
		return run_speed
	else:
		return sprint_speed

func calculate_movement_direction(input_dir: Vector2) -> Vector3:
	"""Calculate world movement direction from input"""
	if not enable_camera_relative or not camera_core:
		# World-relative movement
		return Vector3(input_dir.x, 0, input_dir.y).normalized()
	
	# Camera-relative movement
	var camera_forward = camera_core.get_forward_direction()
	var camera_right = camera_core.get_right_direction()
	
	# Remove Y component for ground movement
	camera_forward.y = 0
	camera_right.y = 0
	
	camera_forward = camera_forward.normalized()
	camera_right = camera_right.normalized()
	
	return (camera_forward * input_dir.y + camera_right * input_dir.x).normalized()

func update_movement_state():
	"""Update movement state and emit signals"""
	var was_moving = is_moving
	is_moving = current_speed > 0.1
	
	if is_moving != was_moving:
		if is_moving:
			movement_started.emit()
			if enable_debug_output:
				print("DirectMovementComponent: Movement started")
		else:
			movement_stopped.emit()
			if enable_debug_output:
				print("DirectMovementComponent: Movement stopped")
	
	# Always emit speed changes for smooth animation blending
	speed_changed.emit(current_speed)

# === JUMP PROCESSING ===

func process_jumping():
	"""Process jump requests"""
	if not character_core or not jump_requested:
		return
	
	jump_requested = false
	
	if can_jump and character_core.is_grounded():
		var jump_height = get_config_value("jump_height", 3.0)
		var jump_velocity = sqrt(2 * character_core.base_gravity * character_core.gravity_multiplier * jump_height)
		
		character_core.apply_impulse_force(Vector3(0, jump_velocity, 0))
		
		if enable_debug_output:
			print("DirectMovementComponent: Jump executed with velocity ", jump_velocity)

# === INPUT HANDLERS ===

func handle_movement_input(input_direction: Vector2):
	"""Handle movement input from control components"""
	current_input_direction = input_direction
	
	if enable_debug_output and input_direction.length() > 0:
		print("DirectMovementComponent: Movement input received: ", input_direction)

func handle_jump_input():
	"""Handle jump input from control components"""
	jump_requested = true
	
	if enable_debug_output:
		print("DirectMovementComponent: Jump input received")

# === PUBLIC API ===

func get_current_speed() -> float:
	"""Get current movement speed"""
	return current_speed

func get_current_direction() -> Vector3:
	"""Get current movement direction"""
	return current_movement_direction

func get_input_direction() -> Vector2:
	"""Get current input direction"""
	return current_input_direction

func is_currently_moving() -> bool:
	"""Check if currently moving"""
	return is_moving

func set_camera_relative_movement(enabled: bool):
	"""Enable/disable camera-relative movement"""
	enable_camera_relative = enabled
	
	if enable_debug_output:
		print("DirectMovementComponent: Camera-relative movement set to ", enabled)

# === CONFIGURATION ===

func get_config_value(property_name: String, default_value):
	"""Get configuration value safely"""
	if config_component and config_component.has_method("get_config_value"):
		return config_component.get_config_value(property_name, default_value)
	return default_value

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get debug information about movement component"""
	return {
		"input_direction": current_input_direction,
		"movement_direction": current_movement_direction,
		"current_speed": current_speed,
		"target_speed": target_speed,
		"is_moving": is_moving,
		"camera_relative": enable_camera_relative,
		"jump_requested": jump_requested,
		"can_jump": can_jump
	}
