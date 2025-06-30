# CameraCore.gd - Basic camera mount for 3C framework
extends Camera3D
class_name CameraCore

# === SIGNALS ===
signal fov_changed(new_fov: float)
signal position_changed(new_position: Vector3)
signal rotation_changed(new_rotation: Vector3)

# === EXPORTS ===
@export_group("Camera Properties")
@export var default_fov: float = 75.0
@export var min_fov: float = 30.0
@export var max_fov: float = 120.0

@export_group("Debug")
@export var enable_debug_output: bool = false

# === INTERNAL STATE ===
var last_position: Vector3
var last_rotation: Vector3
var last_fov: float

func _ready():
	setup_camera()
	
	# Initialize tracking variables
	last_position = global_position
	last_rotation = global_rotation
	last_fov = fov

func setup_camera():
	"""Initialize camera properties"""
	fov = clamp(default_fov, min_fov, max_fov)
	
	if enable_debug_output:
		print("CameraCore: Camera setup complete - FOV: ", fov)

func _process(_delta):
	emit_change_signals()

func emit_change_signals():
	"""Emit signals when camera properties change"""
	# Position changed
	if global_position != last_position:
		last_position = global_position
		position_changed.emit(global_position)
	
	# Rotation changed
	if global_rotation != last_rotation:
		last_rotation = global_rotation
		rotation_changed.emit(global_rotation)
	
	# FOV changed
	if fov != last_fov:
		last_fov = fov
		fov_changed.emit(fov)

# === PUBLIC API ===

func set_fov_value(new_fov: float):
	"""Set camera FOV with clamping"""
	var clamped_fov = clamp(new_fov, min_fov, max_fov)
	fov = clamped_fov
	
	if enable_debug_output:
		print("CameraCore: FOV set to ", clamped_fov)

func get_fov_value() -> float:
	"""Get current FOV"""
	return fov

func get_forward_direction() -> Vector3:
	"""Get camera forward direction"""
	return -global_transform.basis.z

func get_right_direction() -> Vector3:
	"""Get camera right direction"""
	return global_transform.basis.x

func get_up_direction() -> Vector3:
	"""Get camera up direction"""
	return global_transform.basis.y

func screen_to_world_point(screen_pos: Vector2, distance: float) -> Vector3:
	"""Convert screen position to world position at given distance"""
	var camera_transform = global_transform
	var viewport = get_viewport()
	
	if not viewport:
		return Vector3.ZERO
	
	var ray_from = project_ray_origin(screen_pos)
	var ray_dir = project_ray_normal(screen_pos)
	
	return ray_from + ray_dir * distance

func world_to_screen_point(world_pos: Vector3) -> Vector2:
	"""Convert world position to screen position"""
	return unproject_position(world_pos)

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get debug information about camera core"""
	return {
		"position": global_position,
		"rotation_deg": Vector3(
			rad_to_deg(global_rotation.x),
			rad_to_deg(global_rotation.y),
			rad_to_deg(global_rotation.z)
		),
		"fov": fov,
		"forward": get_forward_direction(),
		"right": get_right_direction(),
		"up": get_up_direction()
	}
