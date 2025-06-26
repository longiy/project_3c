# ControllerCharacter.gd - DIAGNOSTIC VERSION with movement debug
extends CharacterBody3D

# [Keep all the same exports...]
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
@export var rotation_speed = 12.0

@export_group("Components")
@export var animation_controller: AnimationController
@export var camera: Camera3D
@export var input_manager: InputManager
@export var jump_system: JumpSystem
@export var debug_helper: CharacterDebugHelper

# === SIGNALS ===
signal movement_mode_changed(is_running: bool, is_slow_walking: bool)
signal speed_changed(new_speed: float)
signal ground_state_changed(is_grounded: bool)
signal movement_state_changed(is_moving: bool, direction: Vector2, magnitude: float)
signal jump_performed(jump_force: float, is_air_jump: bool)

var last_emitted_speed: float = 0.0
var last_emitted_grounded: bool = true
var last_emitted_running: bool = false
var last_emitted_slow_walking: bool = false

var base_gravity: float
var is_slow_walking = false
var is_running = false

var state_machine: CharacterStateMachine
var action_system: ActionSystem

func _ready():
	setup_character()
	setup_state_machine()

func setup_character():
	base_gravity = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	if base_gravity <= 0:
		base_gravity = 9.8
	
	last_emitted_speed = 0.0
	last_emitted_grounded = is_on_floor()
	last_emitted_running = is_running
	last_emitted_slow_walking = is_slow_walking
	
	print("🔧 CHARACTER: Setup complete, camera=", camera != null)

func setup_state_machine():
	state_machine = get_node("CharacterStateMachine") as CharacterStateMachine
	if not state_machine:
		push_error("No CharacterStateMachine child node found!")
		return
	
	action_system = get_node("ActionSystem") as ActionSystem
	if not action_system:
		push_error("No ActionSystem child node found!")
		return

func _physics_process(delta):
	if state_machine:
		state_machine.update(delta)
	
	emit_speed_changes()
	emit_ground_state_changes()

# === MOVEMENT CALCULATION - WITH DEBUG ===

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

func apply_movement(movement_vector: Vector3, target_speed: float, acceleration: float, delta: float):
	
	if movement_vector.length() > 0:
		var old_velocity = velocity
		velocity.x = move_toward(velocity.x, movement_vector.x * target_speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, movement_vector.z * target_speed, acceleration * delta)
		
		rotate_toward_movement(movement_vector, delta)

func rotate_toward_movement(movement_direction: Vector3, delta: float):
	if movement_direction.length() > 0:
		var target_rotation = atan2(movement_direction.x, movement_direction.z)
		var old_rotation = rotation.y
		rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)

# === SIGNAL EMISSION METHODS ===

func emit_speed_changes():
	var current_speed = get_movement_speed()
	if abs(current_speed - last_emitted_speed) > 0.5:
		last_emitted_speed = current_speed
		speed_changed.emit(current_speed)

func emit_ground_state_changes():
	var current_grounded = is_on_floor()
	if current_grounded != last_emitted_grounded:
		last_emitted_grounded = current_grounded
		ground_state_changed.emit(current_grounded)

func emit_movement_mode_changes():
	if is_running != last_emitted_running or is_slow_walking != last_emitted_slow_walking:
		last_emitted_running = is_running
		last_emitted_slow_walking = is_slow_walking
		movement_mode_changed.emit(is_running, is_slow_walking)

# === PROPERTY SETTERS ===

func set_running(value: bool):
	if is_running != value:
		is_running = value
		emit_movement_mode_changes()

func set_slow_walking(value: bool):
	if is_slow_walking != value:
		is_slow_walking = value
		emit_movement_mode_changes()

func start_running():
	set_running(true)

func stop_running():
	set_running(false)

func start_slow_walking():
	set_slow_walking(true)

func stop_slow_walking():
	set_slow_walking(false)

# === UTILITY METHODS ===

func get_target_speed() -> float:
	if is_slow_walking:
		return slow_walk_speed
	elif is_running:
		return run_speed
	else:
		return walk_speed

func get_target_acceleration() -> float:
	return ground_acceleration if is_on_floor() else air_acceleration

func apply_gravity(delta: float):
	if not is_on_floor():
		velocity.y -= (base_gravity * gravity_multiplier) * delta

func apply_deceleration(delta: float):
	velocity.x = move_toward(velocity.x, 0, deceleration * delta)
	velocity.z = move_toward(velocity.z, 0, deceleration * delta)

func perform_jump(jump_force: float):
	if jump_system:
		var was_grounded = is_on_floor()
		jump_system.perform_jump(jump_force)
		jump_performed.emit(jump_force, not was_grounded)

func update_ground_state():
	if jump_system:
		jump_system.update_ground_state()

func can_jump() -> bool:
	return jump_system.can_jump() if jump_system else false

func can_air_jump() -> bool:
	return jump_system.can_air_jump() if jump_system else false

func get_movement_speed() -> float:
	return Vector3(velocity.x, 0, velocity.z).length()

func get_current_state_name() -> String:
	return state_machine.get_current_state_name() if state_machine else "none"

func get_previous_state_name() -> String:
	return state_machine.get_previous_state_name() if state_machine else "none"

func reset_character():
	if debug_helper:
		debug_helper.reset_character()

func get_debug_info() -> Dictionary:
	if debug_helper:
		return debug_helper.get_comprehensive_debug_info()
	else:
		return {
			"current_state": get_current_state_name(),
			"movement_speed": get_movement_speed(),
			"is_grounded": is_on_floor(),
			"debug_helper_missing": true
		}
