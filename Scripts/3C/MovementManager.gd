# MovementManager.gd - 3C Framework Integration
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

# === 3C CONFIGURATION ===

func configure_from_3c(config: CharacterConfig):
	"""Apply 3C configuration to movement parameters"""
	walk_speed = config.walk_speed
	run_speed = config.run_speed
	slow_walk_speed = config.slow_walk_speed
	ground_acceleration = config.ground_acceleration
	air_acceleration = config.air_acceleration
	deceleration = config.deceleration
	rotation_speed = config.rotation_speed
	
	# Apply character responsiveness modifier
	var responsiveness = config.character_responsiveness
	ground_acceleration *= responsiveness
	air_acceleration *= responsiveness
	rotation_speed *= responsiveness
	
	print("🎮 MovementManager: 3C config applied - walk_speed: ", walk_speed, ", responsiveness: ", responsiveness)

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

func handle_mode_action(action_name: String, context: Dictionary = {}):
	match action_name:
		"sprint_start":
			set_running(true)
		"sprint_end":
			set_running(false)
		"slow_walk_start":
			set_slow_walking(true)
		"slow_walk_end":
			set_slow_walking(false)

# === MOVEMENT STATE MANAGEMENT ===

func set_movement_active(active: bool, direction: Vector2 = Vector2.ZERO, magnitude: float = 0.0):
	is_movement_active = active
	current_input_direction = direction
	input_magnitude = magnitude
	
	var current_speed = get_current_speed()
	movement_changed.emit(is_movement_active, current_input_direction, current_speed)

func set_movement_direction(direction: Vector2, magnitude: float):
	current_input_direction = direction
	input_magnitude = magnitude
	
	var current_speed = get_current_speed()
	movement_changed.emit(is_movement_active, current_input_direction, current_speed)

func set_running(running: bool):
	is_running = running
	emit_mode_changes()

func set_slow_walking(slow: bool):
	is_slow_walking = slow
	emit_mode_changes()

# === GETTERS ===

func get_current_speed() -> float:
	if not is_movement_active:
		return 0.0
	
	if is_slow_walking:
		return slow_walk_speed
	elif is_running:
		return run_speed
	else:
		return walk_speed

func get_movement_vector() -> Vector3:
	if not is_movement_active or not camera:
		return Vector3.ZERO
	
	var camera_basis = camera.global_transform.basis
	var forward = -camera_basis.z
	var right = camera_basis.x
	
	forward.y = 0
	right.y = 0
	forward = forward.normalized()
	right = right.normalized()
	
	return (forward * current_input_direction.y + right * current_input_direction.x).normalized()

func get_target_velocity(current_velocity: Vector3, delta: float) -> Vector3:
	var movement_vector = get_movement_vector()
	var target_speed = get_current_speed()
	var target_velocity = movement_vector * target_speed
	
	var acceleration = ground_acceleration if character.is_on_floor() else air_acceleration
	
	if movement_vector.length() > 0:
		return current_velocity.move_toward(target_velocity, acceleration * delta)
	else:
		return current_velocity.move_toward(Vector3.ZERO, deceleration * delta)

func get_rotation_target() -> float:
	var movement_vector = get_movement_vector()
	if movement_vector.length() > 0.1:
		return atan2(-movement_vector.x, -movement_vector.z)
	return character.rotation.y

# === SIGNAL EMISSION ===

func emit_speed_changes():
	var current_speed = get_current_speed()
	if abs(current_speed - last_emitted_speed) > 0.1:
		last_emitted_speed = current_speed
		movement_changed.emit(is_movement_active, current_input_direction, current_speed)

func emit_mode_changes():
	if is_running != last_emitted_running or is_slow_walking != last_emitted_slow:
		last_emitted_running = is_running
		last_emitted_slow = is_slow_walking
		mode_changed.emit(is_running, is_slow_walking)

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	return {
		"movement_active": is_movement_active,
		"input_direction": current_input_direction,
		"input_magnitude": input_magnitude,
		"is_running": is_running,
		"is_slow_walking": is_slow_walking,
		"current_speed": get_current_speed(),
		"movement_vector": get_movement_vector(),
		"walk_speed": walk_speed,
		"run_speed": run_speed,
		"ground_acceleration": ground_acceleration
	}
