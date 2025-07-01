class_name CCC_CharacterMovement
extends Node

@export_group("Movement Settings")
@export var walk_speed: float = 5.0
@export var run_speed: float = 8.0
@export var acceleration: float = 10.0
@export var deceleration: float = 10.0

@export_group("3C Integration")
@export var camera_controller: CCC_CameraController

var character: CharacterBody3D
var current_input_direction: Vector2 = Vector2.ZERO
var target_velocity: Vector3 = Vector3.ZERO
var is_running: bool = false

signal movement_state_changed(is_moving: bool)

func _ready():
	if not character:
		character = get_parent() as CharacterBody3D

func process_movement(delta: float, input_direction: Vector2):
	current_input_direction = input_direction
	calculate_target_velocity()
	apply_movement(delta)

func set_input_direction(input_direction: Vector2):
	current_input_direction = input_direction

func calculate_target_velocity():
	if current_input_direction.length() > 0.1:
		var movement_direction = get_movement_direction()
		var current_speed = run_speed if is_running else walk_speed
		target_velocity = movement_direction * current_speed
	else:
		target_velocity = Vector3.ZERO

func get_movement_direction() -> Vector3:
	if not camera_controller:
		# Fallback to world-space movement
		return Vector3(current_input_direction.x, 0, current_input_direction.y).normalized()
	
	# Get camera-relative movement direction
	var camera_basis = camera_controller.get_camera_basis()
	var forward = -camera_basis.z
	var right = camera_basis.x
	
	# Project onto horizontal plane
	forward.y = 0
	right.y = 0
	forward = forward.normalized()
	right = right.normalized()
	
	return (forward * current_input_direction.y + right * current_input_direction.x).normalized()

func apply_movement(delta: float):
	var current_horizontal = Vector3(character.velocity.x, 0, character.velocity.z)
	var acceleration_rate = acceleration if target_velocity.length() > 0 else deceleration
	
	var new_horizontal = current_horizontal.move_toward(target_velocity, acceleration_rate * delta)
	
	character.velocity.x = new_horizontal.x
	character.velocity.z = new_horizontal.z
	
	# Emit movement state change
	var is_moving = new_horizontal.length() > 0.1
	movement_state_changed.emit(is_moving)

func set_running(running: bool):
	is_running = running

func get_horizontal_speed() -> float:
	return Vector2(character.velocity.x, character.velocity.z).length()

func get_movement_direction_normalized() -> Vector3:
	var horizontal_velocity = Vector3(character.velocity.x, 0, character.velocity.z)
	return horizontal_velocity.normalized() if horizontal_velocity.length() > 0.1 else Vector3.ZERO

func stop_movement():
	target_velocity = Vector3.ZERO
	current_input_direction = Vector2.ZERO

func get_debug_info() -> Dictionary:
	return {
		"movement_input_direction": current_input_direction,
		"movement_target_velocity": target_velocity,
		"movement_horizontal_speed": get_horizontal_speed(),
		"movement_is_running": is_running,
		"movement_direction": get_movement_direction_normalized()
	}