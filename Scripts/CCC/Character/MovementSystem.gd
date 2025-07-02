# MovementSystem.gd - Child of CCC_CharacterManager
extends Node
class_name MovementSystem

# === CORE MOVEMENT PROPERTIES ===
var walk_speed = 3.0
var run_speed = 6.0
var slow_walk_speed = 1.5
var air_speed_multiplier = 0.6

var ground_acceleration = 15.0
var air_acceleration = 8.0
var deceleration = 18.0
var rotation_speed = 12.0

# === STATE ===
var character: CharacterBody3D
var camera: Camera3D

# Movement state
var is_movement_active: bool = false
var current_input_direction: Vector2 = Vector2.ZERO
var input_magnitude: float = 0.0
var current_speed: float = 0.0

# Movement modes
var is_running: bool = false
var is_slow_walking: bool = false

# Signal emission tracking
var last_emitted_speed: float = 0.0
var last_emitted_running: bool = false
var last_emitted_slow: bool = false

# === SIGNALS ===
signal movement_changed(is_moving: bool, direction: Vector2, speed: float)
signal mode_changed(is_running: bool, is_slow_walking: bool)

func _ready():
	# Character will be set by setup_character()
	pass

func setup_character(character_ref: CharacterBody3D):
	"""Setup character reference"""
	character = character_ref
	print("🎮 MovementSystem: Connected to character")

func copy_settings_from_manager(manager: CCC_CharacterManager):
	"""Copy settings from character manager"""
	walk_speed = manager.walk_speed
	run_speed = manager.run_speed
	slow_walk_speed = manager.slow_walk_speed
	air_speed_multiplier = manager.air_speed_multiplier
	ground_acceleration = manager.ground_acceleration
	air_acceleration = manager.air_acceleration
	deceleration = manager.deceleration
	rotation_speed = manager.rotation_speed
	
	print("📋 MovementSystem: Settings copied from CCC_CharacterManager")

func copy_properties_from(old_movement_manager: MovementManager):
	"""Copy properties from old MovementManager"""
	if not old_movement_manager:
		return
	
	# Copy current state
	is_movement_active = old_movement_manager.is_movement_active
	current_input_direction = old_movement_manager.current_input_direction
	input_magnitude = old_movement_manager.input_magnitude
	is_running = old_movement_manager.is_running
	is_slow_walking = old_movement_manager.is_slow_walking
	
	# Copy settings
	walk_speed = old_movement_manager.walk_speed
	run_speed = old_movement_manager.run_speed
	slow_walk_speed = old_movement_manager.slow_walk_speed
	air_speed_multiplier = old_movement_manager.air_speed_multiplier
	ground_acceleration = old_movement_manager.ground_acceleration
	air_acceleration = old_movement_manager.air_acceleration
	deceleration = old_movement_manager.deceleration
	rotation_speed = old_movement_manager.rotation_speed
	
	print("🔄 MovementSystem: Properties copied from old MovementManager")

func _physics_process(delta):
	"""Physics processing for movement"""
	apply_movement_physics(delta)
	emit_speed_changes()

# === MOVEMENT INPUT PROCESSING ===

func process_movement_input(direction: Vector2, magnitude: float):
	"""Called by CCC_CharacterManager"""
	current_input_direction = direction
	input_magnitude = magnitude
	
	var was_active = is_movement_active
	is_movement_active = magnitude > 0.01
	
	# Calculate current speed
	var target_speed = get_target_speed()
	current_speed = target_speed * magnitude
	
	# Emit movement changes
	if is_movement_active != was_active:
		movement_changed.emit(is_movement_active, direction, current_speed)

func get_target_speed() -> float:
	"""Calculate target speed based on current mode"""
	if is_running:
		return run_speed
	elif is_slow_walking:
		return slow_walk_speed
	else:
		return walk_speed

# === MOVEMENT MODE CONTROL ===

func set_running(enabled: bool):
	"""Set running mode"""
	var was_running = is_running
	is_running = enabled
	
	if enabled:
		is_slow_walking = false
	
	if is_running != was_running:
		mode_changed.emit(is_running, is_slow_walking)

func set_slow_walking(enabled: bool):
	"""Set slow walking mode"""
	var was_slow = is_slow_walking
	is_slow_walking = enabled
	
	if enabled:
		is_running = false
	
	if is_slow_walking != was_slow:
		mode_changed.emit(is_running, is_slow_walking)

# === PHYSICS APPLICATION ===

func apply_movement_physics(delta):
	"""Apply movement to character body"""
	if not character:
		return
	
	if is_movement_active and current_input_direction.length() > 0:
		apply_active_movement(delta)
	else:
		apply_deceleration(delta)
	
	# Apply movement
	character.move_and_slide()

func apply_active_movement(delta: float):
	"""Apply active movement"""
	# Convert 2D input to 3D movement
	var movement_3d = Vector3(current_input_direction.x, 0, current_input_direction.y)
	
	# Apply camera-relative movement
	if camera:
		movement_3d = apply_camera_relative_movement(movement_3d)
	
	# Normalize and apply speed
	movement_3d = movement_3d.normalized() * current_speed
	
	# Choose acceleration based on ground state
	var acceleration = ground_acceleration if character.is_on_floor() else air_acceleration
	
	# Apply horizontal movement
	character.velocity.x = move_toward(character.velocity.x, movement_3d.x, acceleration * delta)
	character.velocity.z = move_toward(character.velocity.z, movement_3d.z, acceleration * delta)
	
	# Apply character rotation
	apply_character_rotation(movement_3d, delta)

func apply_deceleration(delta: float):
	"""Apply deceleration when no input"""
	var decel_rate = deceleration * delta
	character.velocity.x = move_toward(character.velocity.x, 0, decel_rate)
	character.velocity.z = move_toward(character.velocity.z, 0, decel_rate)

func apply_camera_relative_movement(movement_3d: Vector3) -> Vector3:
	"""Apply camera-relative movement"""
	if not camera:
		return movement_3d
	
	# Get camera forward and right vectors
	var camera_transform = camera.global_transform
	var camera_forward = -camera_transform.basis.z
	var camera_right = camera_transform.basis.x
	
	# Project to horizontal plane
	camera_forward.y = 0
	camera_right.y = 0
	camera_forward = camera_forward.normalized()
	camera_right = camera_right.normalized()
	
	# Apply camera-relative movement
	return camera_forward * movement_3d.z + camera_right * movement_3d.x

func apply_character_rotation(movement_direction: Vector3, delta: float):
	"""Apply character rotation towards movement direction"""
	if movement_direction.length() < 0.1:
		return
	
	var target_rotation = atan2(movement_direction.x, movement_direction.z)
	var current_rotation = character.rotation.y
	
	# Smooth rotation
	var rotation_difference = angle_difference(current_rotation, target_rotation)
	var rotation_step = rotation_speed * delta
	
	if abs(rotation_difference) > rotation_step:
		current_rotation += sign(rotation_difference) * rotation_step
	else:
		current_rotation = target_rotation
	
	character.rotation.y = current_rotation

# === SIGNAL EMISSION ===

func emit_speed_changes():
	"""Emit speed and mode changes"""
	var current_calculated_speed = get_movement_speed()
	
	# Emit speed changes
	if abs(current_calculated_speed - last_emitted_speed) > 0.1:
		last_emitted_speed = current_calculated_speed
		movement_changed.emit(is_movement_active, current_input_direction, current_calculated_speed)
	
	# Emit mode changes
	if is_running != last_emitted_running or is_slow_walking != last_emitted_slow:
		last_emitted_running = is_running
		last_emitted_slow = is_slow_walking
		mode_changed.emit(is_running, is_slow_walking)

# === UTILITY METHODS ===

func get_movement_speed() -> float:
	"""Get current movement speed"""
	if not character:
		return 0.0
	
	var horizontal_velocity = Vector2(character.velocity.x, character.velocity.z)
	return horizontal_velocity.length()

func setup_camera_reference(camera_ref: Camera3D):
	"""Setup camera reference for movement calculations"""
	camera = camera_ref
	print("📹 MovementSystem: Camera reference set")

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get debug information"""
	return {
		"movement_active": is_movement_active,
		"input_direction": current_input_direction,
		"input_magnitude": input_magnitude,
		"current_speed": current_speed,
		"calculated_speed": get_movement_speed(),
		"is_running": is_running,
		"is_slow_walking": is_slow_walking,
		"target_speed": get_target_speed(),
		"character_connected": character != null,
		"camera_connected": camera != null
	}
