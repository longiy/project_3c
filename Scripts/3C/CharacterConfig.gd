# CharacterConfig.gd - 3C Framework Configuration Resource
extends Resource
class_name CharacterConfig

enum CharacterType { AVATAR, OBSERVER, CONTROLLER, COLLABORATOR }
enum CameraType { ORBITAL, FOLLOWING, FIXED, FIRST_PERSON, RESPONSIVE }
enum ControlType { DIRECT, TARGET_BASED, GUIDED, CONSTRUCTIVE }

@export var config_name: String = "Default 3C Config"

@export_group("Character Axis")
@export var character_type: CharacterType = CharacterType.AVATAR
@export var character_responsiveness: float = 1.0
@export var character_embodiment_quality: float = 1.0
@export var walk_speed: float = 3.0
@export var run_speed: float = 6.0
@export var sprint_speed: float = 9.0
@export var acceleration: float = 10.0
@export var deceleration: float = 15.0
@export var jump_height: float = 4.5
@export var air_control: float = 0.3

@export_group("Camera Axis")
@export var camera_type: CameraType = CameraType.ORBITAL
@export var camera_distance: float = 4.0
@export var camera_height: float = 2.0
@export var camera_smoothing: float = 8.0
@export var camera_fov: float = 75.0
@export var mouse_sensitivity: float = 1.0
@export var orbit_speed: float = 2.0
@export var zoom_speed: float = 1.0

@export_group("Control Axis")
@export var control_type: ControlType = ControlType.DIRECT
@export var control_precision: float = 1.0
@export var control_complexity: float = 1.0
@export var input_deadzone: float = 0.05
@export var input_smoothing: float = 0.1
@export var gamepad_enabled: bool = true

@export_group("Temporal Context")
@export var temporal_scope_description: String = "Minute-to-minute gameplay"
@export var experience_duration_target: float = 300.0  # 5 minutes default
