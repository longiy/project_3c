# CAMERA.gd  
# CAMERA system container for CCC Framework
# Manages SpringArm3D camera and camera components

extends Node3D
class_name CameraSystem

# References - SpringArm3D architecture
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera_core: Camera3D = $SpringArm3D/Camera3D
@onready var camera_components = $CameraComponents

# Component references (will be populated as we build them)
@onready var orbit_component = $CameraComponents/OrbitComponent
@onready var distance_component = $CameraComponents/DistanceComponent
@onready var follow_component = $CameraComponents/FollowComponent
@onready var effects_component = $CameraComponents/EffectsComponent

var manager: CCC_Manager

# Camera state for SpringArm3D control
var camera_rotation_x: float = 0.0  # Pitch (up/down)
var camera_rotation_y: float = 0.0  # Yaw (left/right)

# Camera properties
@export_group("Camera Settings")
@export var default_distance: float = 4.0
@export var min_distance: float = 1.0
@export var max_distance: float = 10.0
@export var default_fov: float = 75.0

# Following settings
@export_group("Follow Settings")
@export var target_node: Node3D
@export var follow_height_offset: float = 1.6
@export var follow_smoothing: float = 8.0

# Internal state
var target_position: Vector3
var current_distance: float
var target_distance: float
var current_fov: float
var target_fov: float

func _ready():
	print("CAMERA: Initializing...")
	print("CAMERA: SpringArm3D path: ", $SpringArm3D)
	print("CAMERA: SpringArm3D exists: ", $SpringArm3D != null)
	
	if not verify_camera_structure():
		return
	
	initialize_camera_properties()
	setup_target_following()
	setup_spring_arm_collision()
	
func _process(delta):
	update_camera_following(delta)
	update_camera_properties(delta)

func verify_camera_structure():
	# Verify SpringArm3D structure
	if not spring_arm:
		push_error("CAMERA: SpringArm3D not found at $SpringArm3D")
		return false
		
	if not camera_core:
		push_error("CAMERA: Camera3D not found at $SpringArm3D/Camera3D")
		return false
		
	if not camera_components:
		push_error("CAMERA: CameraComponents not found")
		return false
	
	print("CAMERA: Scene structure verified")
	return true

func initialize_camera_properties():
	# Initialize camera rotation
	camera_rotation_x = deg_to_rad(-20.0)  # Slight downward angle
	camera_rotation_y = 0.0
	
	# Initialize distance
	current_distance = default_distance
	target_distance = default_distance
	spring_arm.spring_length = current_distance
	
	# Initialize FOV
	current_fov = default_fov
	target_fov = default_fov
	camera_core.fov = current_fov

func setup_target_following():
	if target_node:
		target_position = target_node.global_position + Vector3(0, follow_height_offset, 0)
		global_position = target_position

func setup_spring_arm_collision():
	if not spring_arm:
		push_error("CAMERA: SpringArm3D not found for collision setup")
		return
		
	if target_node:
		# Exclude the character from camera collision
		spring_arm.add_excluded_object(target_node)
		
		# Set collision mask (avoid character layer)
		spring_arm.collision_mask = 1  # Only collide with environment (layer 1)
		
		print("CAMERA: SpringArm3D collision configured")
	else:
		print("CAMERA: No target_node set for collision exclusion")

func update_camera_following(delta: float):
	# Follow target if assigned
	if not target_node:
		return
	
	var desired_position = target_node.global_position + Vector3(0, follow_height_offset, 0)
	target_position = target_position.lerp(desired_position, follow_smoothing * delta)
	global_position = target_position

func update_camera_properties(delta: float):
	# Smooth distance changes
	if current_distance != target_distance:
		current_distance = lerp(current_distance, target_distance, 8.0 * delta)
		spring_arm.spring_length = current_distance
	
	# Smooth FOV changes
	if current_fov != target_fov:
		current_fov = lerp(current_fov, target_fov, 5.0 * delta)
		camera_core.fov = current_fov

# === CCC MANAGER INTERFACE ===

func set_manager(ccc_manager: CCC_Manager):
	manager = ccc_manager

# === COMPONENT API ===

func apply_rotation(yaw: float, pitch: float):
	"""Apply rotation to SpringArm3D - called by OrbitComponent"""
	if not spring_arm:
		# If called before SpringArm3D is ready, defer the call
		call_deferred("apply_rotation", yaw, pitch)
		return
	
	camera_rotation_y = yaw
	camera_rotation_x = pitch
	
	# Apply to SpringArm3D hierarchy
	rotation.y = camera_rotation_y
	spring_arm.rotation.x = camera_rotation_x

func set_distance(distance: float, smooth: bool = true):
	"""Set camera distance - called by DistanceComponent"""
	var clamped_distance = clamp(distance, min_distance, max_distance)
	
	if smooth:
		target_distance = clamped_distance
	else:
		current_distance = clamped_distance
		target_distance = clamped_distance
		spring_arm.spring_length = current_distance

func set_fov(fov: float, smooth: bool = true):
	"""Set camera FOV - called by EffectsComponent"""
	if smooth:
		target_fov = fov
	else:
		current_fov = fov
		target_fov = fov
		camera_core.fov = current_fov

func set_target(target: Node3D):
	"""Set follow target - called by FollowComponent"""
	target_node = target
	if target:
		target_position = target.global_position + Vector3(0, follow_height_offset, 0)

# === PUBLIC GETTERS ===

func get_spring_arm() -> SpringArm3D:
	return spring_arm

func get_camera_core() -> Camera3D:
	return camera_core

func get_components() -> Node3D:
	return camera_components

func get_camera_rotation() -> Vector2:
	"""Get current camera rotation (pitch, yaw)"""
	return Vector2(camera_rotation_x, camera_rotation_y)

func get_current_distance() -> float:
	return current_distance

func get_target_distance() -> float:
	return target_distance

func get_current_fov() -> float:
	return current_fov

# === CAMERA UTILITY API ===

func get_camera_forward() -> Vector3:
	"""Get camera forward direction"""
	return -camera_core.global_transform.basis.z

func get_camera_right() -> Vector3:
	"""Get camera right direction"""
	return camera_core.global_transform.basis.x

func get_camera_up() -> Vector3:
	"""Get camera up direction"""
	return camera_core.global_transform.basis.y

func screen_to_world_ray(screen_pos: Vector2) -> Dictionary:
	"""Convert screen position to world ray - for click navigation"""
	var from = camera_core.project_ray_origin(screen_pos)
	var to = from + camera_core.project_ray_normal(screen_pos) * 1000
	return {"from": from, "to": to}

# === DEBUG INFO ===

func get_camera_debug_info() -> Dictionary:
	return {
		"target_assigned": target_node != null,
		"current_distance": current_distance,
		"target_distance": target_distance,
		"rotation_deg": Vector2(rad_to_deg(camera_rotation_x), rad_to_deg(camera_rotation_y)),
		"fov": current_fov,
		"position": global_position,
		"spring_arm_length": spring_arm.spring_length if spring_arm else 0.0
	}
