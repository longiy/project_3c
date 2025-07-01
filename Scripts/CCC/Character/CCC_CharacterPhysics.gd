class_name CCC_CharacterPhysics
extends Node

@export_group("Physics Settings")
@export var gravity: float = 9.8
@export var terminal_velocity: float = 53.0
@export var air_resistance: float = 0.98

@export_group("Ground Detection")
@export var floor_max_angle: float = 45.0
@export var floor_snap_length: float = 0.1

var character: CharacterBody3D
var gravity_vector: Vector3 = Vector3.ZERO

func _ready():
	if not character:
		character = get_parent() as CharacterBody3D

func process_physics(delta: float):
	apply_gravity(delta)
	apply_air_resistance()
	move_character()

func apply_gravity(delta: float):
	if not character.is_on_floor():
		gravity_vector.y -= gravity * delta
		gravity_vector.y = max(gravity_vector.y, -terminal_velocity)
	else:
		gravity_vector = Vector3.ZERO

func apply_air_resistance():
	if not character.is_on_floor():
		character.velocity.x *= air_resistance
		character.velocity.z *= air_resistance

func move_character():
	character.velocity.y = gravity_vector.y
	character.move_and_slide()

func add_impulse(impulse: Vector3):
	character.velocity += impulse

func set_velocity(new_velocity: Vector3):
	character.velocity = new_velocity

func get_floor_normal() -> Vector3:
	return character.get_floor_normal()

func get_wall_normal() -> Vector3:
	return character.get_wall_normal()

func is_on_wall() -> bool:
	return character.is_on_wall()

func is_on_ceiling() -> bool:
	return character.is_on_ceiling()

func get_debug_info() -> Dictionary:
	return {
		"physics_gravity_vector": gravity_vector,
		"physics_on_floor": character.is_on_floor() if character else false,
		"physics_on_wall": is_on_wall(),
		"physics_on_ceiling": is_on_ceiling(),
		"physics_floor_normal": get_floor_normal(),
		"physics_velocity_y": character.velocity.y if character else 0.0
	}
