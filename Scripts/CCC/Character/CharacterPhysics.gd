# CharacterPhysics.gd - Character physics processing module
extends Node
class_name CharacterPhysics

# === SIGNALS ===
signal ground_state_changed(is_grounded: bool)
signal velocity_changed(new_velocity: Vector3)

# === SETTINGS ===
@export var gravity_multiplier = 1.0
@export var ground_detection_margin = 0.1

# === CHARACTER REFERENCE ===
var character: CharacterBody3D

# === STATE ===
var base_gravity: float
var last_emitted_grounded: bool = true
var ground_check_timer = 0.0
var ground_check_interval = 0.016  # ~60fps

func setup_character_reference(char: CharacterBody3D):
	"""Setup character reference"""
	character = char
	base_gravity = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	if base_gravity <= 0:
		base_gravity = 9.8
	
	last_emitted_grounded = character.is_on_floor() if character else false
	print("✅ CharacterPhysics: Ready with gravity: ", base_gravity)

func update_physics(delta: float):
	"""Main physics update - called from CharacterController"""
	if not character:
		return
	
	update_ground_state_detection(delta)
	emit_velocity_changes()

# === GRAVITY SYSTEM ===

func apply_gravity(delta: float):
	"""Apply gravity to character velocity"""
	if not character:
		return
	
	if not character.is_on_floor():
		character.velocity.y -= base_gravity * gravity_multiplier * delta

func get_gravity_force() -> float:
	"""Get current gravity force"""
	return base_gravity * gravity_multiplier

# === GROUND DETECTION ===

func update_ground_state_detection(delta: float):
	"""Update ground state detection with timing optimization"""
	ground_check_timer += delta
	
	if ground_check_timer >= ground_check_interval:
		check_and_emit_ground_state()
		ground_check_timer = 0.0

func check_and_emit_ground_state():
	"""Check ground state and emit signal if changed"""
	if not character:
		return
	
	var current_grounded = character.is_on_floor()
	
	if current_grounded != last_emitted_grounded:
		last_emitted_grounded = current_grounded
		ground_state_changed.emit(current_grounded)
		
		# Debug logging
		var state_text = "grounded" if current_grounded else "airborne"
		print("🏃 CharacterPhysics: Ground state changed to ", state_text)

func update_ground_state():
	"""Force immediate ground state update"""
	check_and_emit_ground_state()

func is_grounded() -> bool:
	"""Get current grounded state"""
	return character.is_on_floor() if character else false

# === MOVEMENT PHYSICS ===

func perform_move_and_slide():
	"""Execute movement physics"""
	if character:
		character.move_and_slide()

func get_velocity() -> Vector3:
	"""Get current character velocity"""
	return character.velocity if character else Vector3.ZERO

func set_velocity(new_velocity: Vector3):
	"""Set character velocity"""
	if character:
		character.velocity = new_velocity

func add_velocity(additional_velocity: Vector3):
	"""Add to current velocity"""
	if character:
		character.velocity += additional_velocity

# === COLLISION DETECTION ===

func get_floor_normal() -> Vector3:
	"""Get floor normal vector"""
	return character.get_floor_normal() if character else Vector3.UP

func get_wall_normal() -> Vector3:
	"""Get wall normal vector"""
	return character.get_wall_normal() if character else Vector3.ZERO

func is_on_wall() -> bool:
	"""Check if character is touching a wall"""
	return character.is_on_wall() if character else false

func is_on_ceiling() -> bool:
	"""Check if character is touching ceiling"""
	return character.is_on_ceiling() if character else false

func get_slide_collision_count() -> int:
	"""Get number of slide collisions"""
	return character.get_slide_collision_count() if character else 0

func get_slide_collision(index: int) -> KinematicCollision3D:
	"""Get specific slide collision"""
	if character and index < character.get_slide_collision_count():
		return character.get_slide_collision(index)
	return null

# === VELOCITY MONITORING ===

func emit_velocity_changes():
	"""Emit velocity change signals for other systems"""
	if character:
		velocity_changed.emit(character.velocity)

# === PHYSICS RESET ===

func reset_physics():
	"""Reset physics state"""
	if character:
		character.velocity = Vector3.ZERO
	
	last_emitted_grounded = true
	ground_check_timer = 0.0
	print("🔄 CharacterPhysics: Physics state reset")

# === CONFIGURATION ===

func set_gravity_multiplier(multiplier: float):
	"""Update gravity multiplier"""
	gravity_multiplier = multiplier

func set_ground_detection_margin(margin: float):
	"""Update ground detection margin"""
	ground_detection_margin = margin

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get physics debug information"""
	return {
		"gravity_multiplier": gravity_multiplier,
		"base_gravity": base_gravity,
		"effective_gravity": get_gravity_force(),
		"is_grounded": is_grounded(),
		"last_emitted_grounded": last_emitted_grounded,
		"velocity": get_velocity(),
		"velocity_magnitude": get_velocity().length(),
		"is_on_wall": is_on_wall(),
		"is_on_ceiling": is_on_ceiling(),
		"floor_normal": get_floor_normal(),
		"slide_collision_count": get_slide_collision_count(),
		"ground_check_interval": ground_check_interval
	}
