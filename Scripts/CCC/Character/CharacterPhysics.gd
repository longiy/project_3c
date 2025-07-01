# CharacterPhysics.gd - Extracted physics processing module
extends Node
class_name CharacterPhysics

# === SIGNALS ===
signal ground_state_changed(is_grounded: bool)
signal velocity_changed(new_velocity: Vector3)
signal physics_collision(collision_info: Dictionary)

# === PHYSICS SETTINGS ===
@export_group("Physics Parameters")
@export var gravity_multiplier = 1.0
@export var terminal_velocity = 50.0
@export var ground_detection_margin = 0.1

# === COMPONENT REFERENCES ===
var character: CharacterBody3D
var base_gravity: float

# === STATE TRACKING ===
var last_emitted_grounded: bool = true
var last_velocity: Vector3 = Vector3.ZERO
var collision_count: int = 0

func _ready():
	character = get_parent() as CharacterBody3D
	if not character:
		push_error("CharacterPhysics must be child of CharacterBody3D")
		return
	
	setup_physics()
	connect_character_signals()

func setup_physics():
	"""Initialize physics parameters"""
	base_gravity = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	if base_gravity <= 0:
		base_gravity = 9.8
	
	last_emitted_grounded = character.is_on_floor()

func connect_character_signals():
	"""Connect to character signals if they exist"""
	# Connect to movement manager if it exists
	var movement_manager = character.get_node_or_null("MovementManager")
	if movement_manager and movement_manager.has_signal("movement_changed"):
		movement_manager.movement_changed.connect(_on_movement_changed)

func _physics_process(delta):
	apply_gravity(delta)
	track_physics_changes()

# === CORE PHYSICS FUNCTIONS ===

func apply_gravity(delta: float):
	"""Apply gravity to character if not grounded - PUBLIC METHOD"""
	if not character.is_on_floor():
		var gravity_force = (base_gravity * gravity_multiplier) * delta
		character.velocity.y = max(character.velocity.y - gravity_force, -terminal_velocity)

func execute_movement():
	"""Execute character movement and handle collisions - PUBLIC METHOD"""
	var old_velocity = character.velocity
	var collision_occurred = false
	
	# Store collision count before movement
	var pre_move_collisions = character.get_slide_collision_count()
	
	# Execute movement
	character.move_and_slide()
	
	# Check for new collisions
	var post_move_collisions = character.get_slide_collision_count()
	if post_move_collisions > pre_move_collisions:
		collision_occurred = true
		handle_collision_events()
	
	# Track velocity changes
	if old_velocity != character.velocity:
		velocity_changed.emit(character.velocity)

func handle_collision_events():
	"""Process collision information and emit signals"""
	for i in character.get_slide_collision_count():
		var collision = character.get_slide_collision(i)
		var collision_info = {
			"collider": collision.get_collider(),
			"position": collision.get_position(),
			"normal": collision.get_normal(),
			"travel": collision.get_travel(),
			"remainder": collision.get_remainder()
		}
		physics_collision.emit(collision_info)

func track_physics_changes():
	"""Track and emit physics state changes"""
	emit_ground_state_changes()
	track_velocity_changes()

func emit_ground_state_changes():
	"""Emit ground state change signals"""
	var current_grounded = is_grounded()
	if current_grounded != last_emitted_grounded:
		last_emitted_grounded = current_grounded
		ground_state_changed.emit(current_grounded)

func track_velocity_changes():
	"""Track significant velocity changes"""
	if last_velocity.distance_to(character.velocity) > 0.1:
		last_velocity = character.velocity

# === GROUND DETECTION ===

func is_grounded() -> bool:
	"""Enhanced ground detection with margin"""
	return character.is_on_floor()

func get_ground_normal() -> Vector3:
	"""Get the normal of the ground surface"""
	if character.is_on_floor():
		return character.get_floor_normal()
	return Vector3.UP

func get_ground_angle() -> float:
	"""Get the angle of the ground in degrees"""
	if character.is_on_floor():
		return rad_to_deg(character.get_floor_normal().angle_to(Vector3.UP))
	return 0.0

func is_on_steep_slope(max_angle: float = 45.0) -> bool:
	"""Check if character is on a slope steeper than max_angle"""
	return get_ground_angle() > max_angle

# === VELOCITY MANIPULATION ===

func set_velocity(new_velocity: Vector3):
	"""Set character velocity directly"""
	character.velocity = new_velocity
	velocity_changed.emit(new_velocity)

func add_impulse(impulse: Vector3):
	"""Add an impulse to current velocity"""
	character.velocity += impulse
	velocity_changed.emit(character.velocity)

func set_horizontal_velocity(horizontal_velocity: Vector2):
	"""Set only horizontal velocity, preserve vertical"""
	character.velocity.x = horizontal_velocity.x
	character.velocity.z = horizontal_velocity.y
	velocity_changed.emit(character.velocity)

func set_vertical_velocity(vertical_velocity: float):
	"""Set only vertical velocity, preserve horizontal"""
	character.velocity.y = vertical_velocity
	velocity_changed.emit(character.velocity)

func dampen_velocity(damping_factor: float, delta: float):
	"""Apply velocity dampening"""
	character.velocity = character.velocity.lerp(Vector3.ZERO, damping_factor * delta)

# === SIGNAL HANDLERS ===

func _on_movement_changed(is_moving: bool, direction: Vector2, speed: float):
	"""Handle movement changes from movement system"""
	# This will be used when movement system is refactored
	pass

# === PUBLIC API ===

func get_velocity() -> Vector3:
	"""Get current character velocity"""
	return character.velocity

func get_horizontal_speed() -> float:
	"""Get horizontal movement speed"""
	return Vector2(character.velocity.x, character.velocity.z).length()

func get_vertical_speed() -> float:
	"""Get vertical movement speed"""
	return abs(character.velocity.y)

func is_moving() -> bool:
	"""Check if character is moving horizontally"""
	return get_horizontal_speed() > 0.1

func is_falling() -> bool:
	"""Check if character is falling"""
	return character.velocity.y < -0.1 and not character.is_on_floor()

func is_rising() -> bool:
	"""Check if character is rising"""
	return character.velocity.y > 0.1

# === PHYSICS QUERIES ===

func raycast_down(distance: float = 1.0) -> Dictionary:
	"""Raycast downward from character"""
	var space_state = character.get_world_3d().direct_space_state
	var from = character.global_position
	var to = from + Vector3.DOWN * distance
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	query.exclude = [character]
	
	return space_state.intersect_ray(query)

func check_collision_at_position(test_position: Vector3) -> bool:
	"""Check if there would be a collision at test position"""
	var space_state = character.get_world_3d().direct_space_state
	var shape = character.get_node("CollisionShape3D").shape
	var transform = Transform3D(Basis.IDENTITY, test_position)
	
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = transform
	query.collision_mask = 1
	query.exclude = [character]
	
	var result = space_state.intersect_shape(query, 1)
	return result.size() > 0

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get physics debug information"""
	return {
		"velocity": character.velocity,
		"horizontal_speed": get_horizontal_speed(),
		"vertical_speed": get_vertical_speed(),
		"is_grounded": is_grounded(),
		"is_moving": is_moving(),
		"is_falling": is_falling(),
		"is_rising": is_rising(),
		"ground_angle": get_ground_angle(),
		"ground_normal": get_ground_normal(),
		"on_floor": character.is_on_floor(),
		"on_wall": character.is_on_wall(),
		"on_ceiling": character.is_on_ceiling(),
		"collision_count": character.get_slide_collision_count(),
		"gravity_multiplier": gravity_multiplier,
		"terminal_velocity": terminal_velocity
	}

# === RESET FUNCTIONALITY ===

func reset_physics():
	"""Reset physics state"""
	character.velocity = Vector3.ZERO
	last_emitted_grounded = character.is_on_floor()
	last_velocity = Vector3.ZERO
	collision_count = 0
