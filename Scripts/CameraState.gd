# MovementState.gd - Resource for defining camera state properties
extends Resource
class_name CameraState

@export_group("State Identity")
@export var animation_state_name: String = ""  # Must match AnimationTree state names
@export var blend_position_min: float = -999.0
@export var blend_position_max: float = 999.0
@export var blend_parameter_path: String = "parameters/Move/blend_position"

@export_group("Camera Properties")
@export var camera_fov: float = 75.0
@export var camera_distance: float = 4.0
@export var camera_height_offset: float = 0.0
@export var camera_smoothing: float = 8.0

@export_group("Camera Offset")
@export var camera_offset: Vector3 = Vector3.ZERO

@export_group("Transition Settings")
@export var transition_speed: float = 2.0
