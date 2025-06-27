# MovementCalculator.gd - Centralized movement calculations
extends Node
class_name MovementCalculator

@export_group("Movement Settings")
@export var walk_speed = 3.0
@export var run_speed = 6.0
@export var slow_walk_speed = 1.5
@export var air_speed_multiplier = 0.6

@export_group("Physics")
@export var ground_acceleration = 15.0
@export var air_acceleration = 8.0
@export var deceleration = 18.0
@export var rotation_speed = 12.0

var character: CharacterBody3D
var camera: Camera3D

func _ready():
	character = get_parent() as CharacterBody3D
	if not character:
		push_error("MovementCalculator must be child of CharacterBody3D")

func setup_camera_reference(camera_ref: Camera3D):
	camera = camera_ref

# === CORE MOVEMENT CALCULATIONS ===

func calculate_movement_vector(input_dir: Vector2) -> Vector3:
	"""Convert 2D input to 3D movement vector relative to camera"""
	if input_dir.length() == 0:
		return Vector3.ZERO
	
	var movement_vector = Vector3.ZERO
	
	if camera:
		var cam_transform = camera.global_transform.basis
		var cam_forward = Vector3(-cam_transform.z.x, 0, -cam_transform.z.z).normalized()
		var cam_right = Vector3(cam_transform.x.x, 0, cam_transform.x.z).normalized()
		
		movement_vector = cam_right * input_dir.x + cam_forward * (-input_dir.y)
	else:
		# Fallback to world-space movement
		movement_vector = Vector3(input_dir.x, 0, input_dir.y)
	
	return movement_vector.normalized()

func get_target_speed(is_running: bool, is_slow_walking: bool) -> float:
	"""Get target speed based on movement mode"""
	if is_slow_walking:
		return slow_walk_speed
	elif is_running:
		return run_speed
	else:
		return walk_speed

func get_acceleration(is_grounded: bool) -> float:
	"""Get acceleration based on ground state"""
	return ground_acceleration if is_grounded else air_acceleration

func get_air_speed_modifier() -> float:
	"""Get air movement speed modifier"""
	return air_speed_multiplier

# === MOVEMENT APPLICATION ===

func apply_movement(movement_vector: Vector3, target_speed: float, acceleration: float, delta: float):
	"""Apply movement to character with acceleration"""
	if movement_vector.length() > 0:
		character.velocity.x = move_toward(character.velocity.x, movement_vector.x * target_speed, acceleration * delta)
		character.velocity.z = move_toward(character.velocity.z, movement_vector.z * target_speed, acceleration * delta)
		
		apply_rotation(movement_vector, delta)

func apply_deceleration(delta: float):
	"""Apply deceleration when no input"""
	character.velocity.x = move_toward(character.velocity.x, 0, deceleration * delta)
	character.velocity.z = move_toward(character.velocity.z, 0, deceleration * delta)

func apply_rotation(movement_direction: Vector3, delta: float):
	"""Rotate character toward movement direction"""
	if movement_direction.length() > 0:
		var target_rotation = atan2(movement_direction.x, movement_direction.z)
		character.rotation.y = lerp_angle(character.rotation.y, target_rotation, rotation_speed * delta)

# === UTILITY FUNCTIONS ===

func get_movement_speed() -> float:
	"""Get current horizontal movement speed"""
	return Vector3(character.velocity.x, 0, character.velocity.z).length()

func get_movement_direction() -> Vector3:
	"""Get current movement direction (normalized)"""
	var horizontal_velocity = Vector3(character.velocity.x, 0, character.velocity.z)
	return horizontal_velocity.normalized() if horizontal_velocity.length() > 0.1 else Vector3.ZERO

func is_moving(threshold: float = 0.1) -> bool:
	"""Check if character is moving above threshold"""
	return get_movement_speed() > threshold

# === AIR MOVEMENT HELPERS ===

func apply_air_movement(movement_vector: Vector3, is_running: bool, is_slow_walking: bool, delta: float):
	"""Apply movement while in air with reduced control"""
	var base_speed = get_target_speed(is_running, is_slow_walking)
	var air_speed = base_speed * air_speed_multiplier
	var air_accel = air_acceleration
	
	apply_movement(movement_vector, air_speed, air_accel, delta)

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	return {
		"current_speed": get_movement_speed(),
		"movement_direction": get_movement_direction(),
		"is_moving": is_moving(),
		"target_speeds": {
			"walk": walk_speed,
			"run": run_speed,
			"slow_walk": slow_walk_speed
		},
		"physics": {
			"ground_accel": ground_acceleration,
			"air_accel": air_acceleration,
			"deceleration": deceleration,
			"rotation_speed": rotation_speed
		},
		"camera_connected": camera != null
	}
