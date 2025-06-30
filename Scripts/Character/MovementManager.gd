# MovementManager.gd - Single source of truth for all movement
extends Node
class_name MovementManager

# === SIGNALS ===
signal movement_changed(is_moving: bool, direction: Vector2, speed: float)
signal mode_changed(is_running: bool, is_slow_walking: bool)

# === MOVEMENT SETTINGS ===
@export_group("Movement Speeds")
@export var walk_speed = 3.0
@export var run_speed = 6.0
@export var slow_walk_speed = 1.5
@export var air_speed_multiplier = 0.6

@export_group("Physics")
@export var ground_acceleration = 15.0
@export var air_acceleration = 8.0
@export var deceleration = 18.0
@export var rotation_speed = 12.0

# === STATE ===
var character: CharacterBody3D
var camera: Camera3D

# Movement state
var is_movement_active: bool = false
var current_input_direction: Vector2 = Vector2.ZERO
var input_magnitude: float = 0.0

# Movement modes
var is_running: bool = false
var is_slow_walking: bool = false

# Signal emission tracking
var last_emitted_speed: float = 0.0
var last_emitted_running: bool = false
var last_emitted_slow: bool = false

func _ready():
	character = get_parent() as CharacterBody3D
	if not character:
		push_error("MovementManager must be child of CharacterBody3D")

func setup_camera_reference(camera_ref: Camera3D):
	camera = camera_ref

func _physics_process(delta):
	emit_speed_changes()

# === ACTION HANDLERS ===

func handle_movement_action(action_name: String, context: Dictionary = {}):
	match action_name:
		"move_start":
			set_movement_active(true, context.get("direction", Vector2.ZERO), context.get("magnitude", 0.0))
		"move_update":
			if is_movement_active:
				set_movement_direction(context.get("direction", Vector2.ZERO), context.get("magnitude", 0.0))
		"move_end":
			set_movement_active(false, Vector2.ZERO, 0.0)

func handle_mode_action(action_name: String):
	match action_name:
		"sprint_start":
			set_running(true)
		"sprint_end":
			set_running(false)
		"slow_walk_start":
			set_slow_walking(true)
		"slow_walk_end":
			set_slow_walking(false)

# === STATE MANAGEMENT ===

func set_movement_active(active: bool, direction: Vector2 = Vector2.ZERO, magnitude: float = 0.0):
	is_movement_active = active
	current_input_direction = direction
	input_magnitude = magnitude
	
	var current_speed = get_movement_speed()
	movement_changed.emit(active, direction, current_speed)

func set_movement_direction(direction: Vector2, magnitude: float):
	current_input_direction = direction
	input_magnitude = magnitude
	
	var current_speed = get_movement_speed()
	movement_changed.emit(is_movement_active, direction, current_speed)

func set_running(value: bool):
	if is_running != value:
		is_running = value
		emit_mode_changes()

func set_slow_walking(value: bool):
	if is_slow_walking != value:
		is_slow_walking = value
		emit_mode_changes()

func emit_mode_changes():
	if is_running != last_emitted_running or is_slow_walking != last_emitted_slow:
		last_emitted_running = is_running
		last_emitted_slow = is_slow_walking
		mode_changed.emit(is_running, is_slow_walking)

func emit_speed_changes():
	if not character:
		return
	
	var current_speed = get_movement_speed()
	if abs(current_speed - last_emitted_speed) > 0.5:
		last_emitted_speed = current_speed
		movement_changed.emit(is_movement_active, current_input_direction, current_speed)

# === MOVEMENT CALCULATIONS ===

func calculate_movement_vector(input_dir: Vector2) -> Vector3:
	if input_dir.length() == 0:
		return Vector3.ZERO
	
	var movement_vector = Vector3.ZERO
	
	if camera:
		var cam_transform = camera.global_transform.basis
		var cam_forward = Vector3(-cam_transform.z.x, 0, -cam_transform.z.z).normalized()
		var cam_right = Vector3(cam_transform.x.x, 0, cam_transform.x.z).normalized()
		movement_vector = cam_right * input_dir.x + cam_forward * (-input_dir.y)
	else:
		movement_vector = Vector3(input_dir.x, 0, input_dir.y)
	
	return movement_vector.normalized()

func get_target_speed() -> float:
	if is_slow_walking:
		return slow_walk_speed
	elif is_running:
		return run_speed
	else:
		return walk_speed

func get_acceleration(is_grounded: bool) -> float:
	return ground_acceleration if is_grounded else air_acceleration

# === MOVEMENT APPLICATION ===

func apply_ground_movement(delta: float):
	if not character:
		return
	
	if is_movement_active and current_input_direction.length() > 0:
		var movement_3d = calculate_movement_vector(current_input_direction)
		var target_speed = get_target_speed()
		var acceleration = get_acceleration(character.is_on_floor())
		
		apply_movement(movement_3d, target_speed, acceleration, delta)
	else:
		apply_deceleration(delta)

func apply_air_movement(delta: float):
	if not character:
		return
	
	if is_movement_active and current_input_direction.length() > 0:
		var movement_3d = calculate_movement_vector(current_input_direction)
		var base_speed = get_target_speed()
		var air_speed = base_speed * air_speed_multiplier
		var air_accel = air_acceleration
		
		apply_movement(movement_3d, air_speed, air_accel, delta)

func apply_movement(movement_vector: Vector3, target_speed: float, acceleration: float, delta: float):
	if movement_vector.length() > 0:
		character.velocity.x = move_toward(character.velocity.x, movement_vector.x * target_speed, acceleration * delta)
		character.velocity.z = move_toward(character.velocity.z, movement_vector.z * target_speed, acceleration * delta)
		apply_rotation(movement_vector, delta)

func apply_deceleration(delta: float):
	character.velocity.x = move_toward(character.velocity.x, 0, deceleration * delta)
	character.velocity.z = move_toward(character.velocity.z, 0, deceleration * delta)

func apply_rotation(movement_direction: Vector3, delta: float):
	if movement_direction.length() > 0:
		var target_rotation = atan2(movement_direction.x, movement_direction.z)
		character.rotation.y = lerp_angle(character.rotation.y, target_rotation, rotation_speed * delta)

# === STATE QUERIES ===

func get_target_movement_state() -> String:
	if not is_movement_active:
		return "idle"
	
	if is_running and not is_slow_walking:
		return "running"
	else:
		return "walking"

func should_transition_to_state(current_state: String) -> String:
	var target_state = get_target_movement_state()
	return target_state if target_state != current_state else ""

# === UTILITY ===

func get_movement_speed() -> float:
	if not character:
		return 0.0
	return Vector3(character.velocity.x, 0, character.velocity.z).length()

func get_movement_direction() -> Vector3:
	if not character:
		return Vector3.ZERO
	var horizontal_velocity = Vector3(character.velocity.x, 0, character.velocity.z)
	return horizontal_velocity.normalized() if horizontal_velocity.length() > 0.1 else Vector3.ZERO

func is_moving(threshold: float = 0.1) -> bool:
	return get_movement_speed() > threshold

# === DEBUG ===

func get_debug_info() -> Dictionary:
	return {
		"movement_active": is_movement_active,
		"input_direction": current_input_direction,
		"input_magnitude": input_magnitude,
		"is_running": is_running,
		"is_slow_walking": is_slow_walking,
		"target_state": get_target_movement_state(),
		"current_speed": get_movement_speed(),
		"camera_connected": camera != null
	}
