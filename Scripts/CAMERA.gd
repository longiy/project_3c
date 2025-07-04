# CAMERA.gd
# CAMERA system container for CCC Framework
# Refactored: Export references, removed debug prints

extends Node3D
class_name CameraSystem

# Export references instead of onready paths
@export_group("Core References")
@export var spring_arm: SpringArm3D
@export var camera_core: Camera3D

@export_group("Component References")
@export var orbit_component: OrbitComponent
@export var distance_component: DistanceComponent
@export var follow_component: FollowComponent
#@export var effects_component: EffectsComponent

@export_group("Camera Settings")
@export var default_distance: float = 4.0
@export var min_distance: float = 1.0
@export var max_distance: float = 10.0
@export var default_fov: float = 75.0

@export_group("Follow Settings")
@export var target_node: Node3D
@export var follow_height_offset: float = 1.6
@export var follow_smoothing: float = 8.0

var manager: CCC_Manager

# Camera state
var camera_rotation_x: float = 0.0
var camera_rotation_y: float = 0.0
var target_position: Vector3
var current_distance: float
var target_distance: float
var current_fov: float
var target_fov: float

func _ready():
	if not verify_camera_components():
		return
	
	initialize_camera_properties()
	setup_target_following()
	setup_spring_arm_collision()
	
func verify_camera_components() -> bool:
	var missing = []
	
	if not spring_arm: missing.append("spring_arm")
	if not camera_core: missing.append("camera_core")
	if not orbit_component: missing.append("orbit_component")
	if not distance_component: missing.append("distance_component")  # MISSING
	if not follow_component: missing.append("follow_component")      # MISSING
	if not target_node: missing.append("target_node")               # MISSING
	
	return true
	
func _process(delta):
	if not target_node:  # MISSING check before use
		return
	update_camera_following(delta)
	update_camera_properties(delta)

func verify_references() -> bool:
	var missing = []
	
	if not spring_arm: missing.append("spring_arm")
	if not camera_core: missing.append("camera_core")
	
	if missing.size() > 0:
		push_error("CAMERA: Missing references: " + str(missing))
		return false
	
	return true

func initialize_camera_properties():
	camera_rotation_x = deg_to_rad(-20.0)
	camera_rotation_y = 0.0
	
	current_distance = default_distance
	target_distance = default_distance
	spring_arm.spring_length = current_distance
	
	current_fov = default_fov
	target_fov = default_fov
	camera_core.fov = current_fov

func setup_target_following():
	if target_node:
		target_position = target_node.global_position + Vector3(0, follow_height_offset, 0)
		global_position = target_position

func setup_spring_arm_collision():
	if not spring_arm or not target_node:
		return
	
	spring_arm.add_excluded_object(target_node)
	spring_arm.collision_mask = 1

func update_camera_following(delta: float):
	if not target_node:
		return
	
	var desired_position = target_node.global_position + Vector3(0, follow_height_offset, 0)
	target_position = target_position.lerp(desired_position, follow_smoothing * delta)
	global_position = target_position

func update_camera_properties(delta: float):
	# Smooth distance changes
	if abs(current_distance - target_distance) > 0.01:
		current_distance = lerp(current_distance, target_distance, 8.0 * delta)
		spring_arm.spring_length = current_distance
	
	# Smooth FOV changes
	if abs(current_fov - target_fov) > 0.1:
		current_fov = lerp(current_fov, target_fov, 5.0 * delta)
		camera_core.fov = current_fov

# === CCC MANAGER INTERFACE ===
func set_manager(ccc_manager: CCC_Manager):
	manager = ccc_manager

# === COMPONENT API ===
func apply_rotation(yaw: float, pitch: float):
	if not spring_arm:
		call_deferred("apply_rotation", yaw, pitch)
		return
	
	camera_rotation_y = yaw
	camera_rotation_x = pitch
	
	rotation.y = camera_rotation_y
	spring_arm.rotation.x = camera_rotation_x

func set_distance(distance: float, smooth: bool = true):
	var clamped_distance = clamp(distance, min_distance, max_distance)
	
	if smooth:
		target_distance = clamped_distance
	else:
		current_distance = clamped_distance
		target_distance = clamped_distance
		spring_arm.spring_length = current_distance

func set_fov(fov: float, smooth: bool = true):
	if smooth:
		target_fov = fov
	else:
		current_fov = fov
		target_fov = fov
		camera_core.fov = current_fov

func set_target(target: Node3D):
	target_node = target
	if target:
		target_position = target.global_position + Vector3(0, follow_height_offset, 0)

# === PUBLIC GETTERS ===
func get_spring_arm() -> SpringArm3D:
	return spring_arm

func get_camera_core() -> Camera3D:
	return camera_core

func get_camera_rotation() -> Vector2:
	return Vector2(camera_rotation_x, camera_rotation_y)

func get_current_distance() -> float:
	return current_distance

func get_target_distance() -> float:
	return target_distance

func get_current_fov() -> float:
	return current_fov

# === CAMERA UTILITY API ===
func get_camera_forward() -> Vector3:
	return -camera_core.global_transform.basis.z

func get_camera_right() -> Vector3:
	return camera_core.global_transform.basis.x

func get_camera_up() -> Vector3:
	return camera_core.global_transform.basis.y

func screen_to_world_ray(screen_pos: Vector2) -> Dictionary:
	var from = camera_core.project_ray_origin(screen_pos)
	var to = from + camera_core.project_ray_normal(screen_pos) * 1000
	return {"from": from, "to": to}
