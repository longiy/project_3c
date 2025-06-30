# 3CCharacterController.gd - NEW main character controller
extends CharacterBody3D
class_name ThreeCCharacterController

# === 3C CORE REFERENCES ===
@onready var config_component: Node = $3CConfigComponent
@onready var character_core: Node = $CharacterCore
@onready var camera_core: Node = $CameraCore
@onready var control_core: Node = $ControlCore
@onready var debug_ui: Control = $DebugUI

# === PHYSICS ===
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

func _ready():
	setup_3c_system()

func _physics_process(delta):
	handle_gravity(delta)
	move_and_slide()

func setup_3c_system():
	"""Initialize 3C framework"""
	if config_component:
		config_component.character_controller = self
		config_component.initialize_3c_system()

func handle_gravity(delta):
	"""Apply gravity when not on floor"""
	if not is_on_floor():
		velocity.y -= gravity * delta

# === 3C FRAMEWORK API ===
func apply_movement_velocity(movement_vel: Vector3):
	"""Apply movement velocity from control systems"""
	velocity.x = movement_vel.x
	velocity.z = movement_vel.z

func get_character_position() -> Vector3:
	"""Get character position for camera systems"""
	return global_position

func get_character_velocity() -> Vector3:
	"""Get character velocity for animation systems"""
	return velocity

func is_character_grounded() -> bool:
	"""Check if character is on ground"""
	return is_on_floor()
