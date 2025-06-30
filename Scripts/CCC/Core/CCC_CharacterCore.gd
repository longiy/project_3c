# CharacterCore.gd - Basic physics foundation for 3C framework
extends CharacterBody3D
class_name CCC_CharacterCore

# === SIGNALS ===
signal ground_state_changed(is_grounded: bool)
signal velocity_changed(new_velocity: Vector3)
signal position_changed(new_position: Vector3)

# === EXPORTS ===
@export_group("Physics Properties")
@export var gravity_multiplier: float = 1.0
@export var max_velocity: float = 20.0

@export_group("Debug")
@export var enable_debug_output: bool = false

# === INTERNAL STATE ===
var base_gravity: float
var last_grounded_state: bool = true
var last_position: Vector3

func _ready():
	setup_physics()
	last_position = global_position

func setup_physics():
	"""Initialize physics constants"""
	base_gravity = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	if base_gravity <= 0:
		base_gravity = 9.8
	
	if enable_debug_output:
		print("CharacterCore: Physics setup complete - gravity: ", base_gravity)

func _physics_process(delta):
	# Apply gravity
	if not is_on_floor():
		velocity.y -= base_gravity * gravity_multiplier * delta
	
	# Clamp velocity
	if velocity.length() > max_velocity:
		velocity = velocity.normalized() * max_velocity
	
	# Apply movement
	move_and_slide()
	
	# Emit signals for state changes
	emit_state_signals()

func emit_state_signals():
	"""Emit signals when state changes"""
	# Ground state changed
	var current_grounded = is_on_floor()
	if current_grounded != last_grounded_state:
		last_grounded_state = current_grounded
		ground_state_changed.emit(current_grounded)
		if enable_debug_output:
			print("CharacterCore: Ground state changed to ", current_grounded)
	
	# Velocity changed (emit every frame for now - components can filter)
	velocity_changed.emit(velocity)
	
	# Position changed
	if global_position != last_position:
		last_position = global_position
		position_changed.emit(global_position)

# === PUBLIC API ===

func apply_movement_velocity(new_velocity: Vector3):
	"""Apply movement velocity (preserves gravity)"""
	velocity.x = new_velocity.x
	velocity.z = new_velocity.z
	# Keep existing Y velocity for gravity/jumping

func apply_impulse_force(impulse: Vector3):
	"""Apply instant force (for jumping, knockback, etc.)"""
	velocity += impulse

func get_movement_velocity() -> Vector2:
	"""Get horizontal movement velocity"""
	return Vector2(velocity.x, velocity.z)

func get_full_velocity() -> Vector3:
	"""Get complete velocity vector"""
	return velocity

func is_grounded() -> bool:
	"""Check if character is on ground"""
	return is_on_floor()

func get_ground_normal() -> Vector3:
	"""Get ground surface normal"""
	return get_floor_normal()

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get debug information about character core"""
	return {
		"position": global_position,
		"velocity": velocity,
		"speed": velocity.length(),
		"grounded": is_on_floor(),
		"gravity_active": not is_on_floor(),
		"collision_count": get_slide_collision_count()
	}
