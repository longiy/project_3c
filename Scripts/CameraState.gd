# CameraState.gd - Add transition type control
extends Resource
class_name CameraState

@export_group("State Identity")
@export var animation_state_name: String = ""
@export var blend_position_min: float = -999.0
@export var blend_position_max: float = 999.0
@export var blend_parameter_path: String = "parameters/Move/blend_position"

@export_group("Camera Properties")
@export var camera_fov: float = 75.0
@export var camera_distance: float = 4.0
@export var camera_height_offset: float = 0.0
@export var camera_smoothing: float = 8.0
@export var camera_offset: Vector3 = Vector3.ZERO

@export_group("Transition Settings")
@export_enum("Smooth", "Instant", "Custom") var transition_type = 0
@export var enter_transition_speed: float = 2.0
@export var exit_transition_speed: float = 1.5
@export var custom_transition_curve: Curve  # For future custom easing
