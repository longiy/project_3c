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

# Movement parameters
@export var walk_speed: float = 3.0
@export var run_speed: float = 6.0
@export var slow_walk_speed: float = 1.5
@export var ground_acceleration: float = 15.0
@export var air_acceleration: float = 8.0
@export var deceleration: float = 18.0
@export var rotation_speed: float = 12.0

@export_group("Camera Axis")
@export var camera_type: CameraType = CameraType.ORBITAL
@export var camera_distance: float = 4.0
@export var camera_smoothing: float = 8.0
@export var camera_fov: float = 75.0

# Camera responsiveness per state
@export var idle_fov: float = 50.0
@export var idle_distance: float = 4.0
@export var walking_fov: float = 60.0
@export var walking_distance: float = 4.0
@export var running_fov: float = 70.0
@export var running_distance: float = 4.5
@export var jumping_fov: float = 85.0
@export var jumping_distance: float = 4.8

# Mouse and rotation
@export var mouse_sensitivity: float = 0.002
@export var follow_height_offset: float = 1.6

@export_group("Control Axis")
@export var control_type: ControlType = ControlType.DIRECT
@export var control_precision: float = 1.0
@export var control_complexity: float = 1.0

# Input parameters
@export var input_deadzone: float = 0.1
@export var movement_update_interval: float = 0.033
@export var click_arrival_threshold: float = 0.5

@export_group("Temporal Context")
@export var temporal_scope_description: String = "Minute-to-minute gameplay"
@export var experience_duration_target: float = 300.0  # 5 minutes default

# Apply configuration to systems
func apply_to_movement_manager(movement_manager: MovementManager):
	movement_manager.walk_speed = walk_speed
	movement_manager.run_speed = run_speed
	movement_manager.slow_walk_speed = slow_walk_speed
	movement_manager.ground_acceleration = ground_acceleration
	movement_manager.air_acceleration = air_acceleration
	movement_manager.deceleration = deceleration
	movement_manager.rotation_speed = rotation_speed

func apply_to_camera_rig(camera_rig: CameraRig):
	camera_rig.default_distance = camera_distance
	camera_rig.follow_smoothing = camera_smoothing
	camera_rig.default_fov = camera_fov
	camera_rig.mouse_sensitivity = mouse_sensitivity
	camera_rig.follow_height_offset = follow_height_offset
	
	# Apply state-specific values
	camera_rig.idle_fov = idle_fov
	camera_rig.idle_distance = idle_distance
	camera_rig.walking_fov = walking_fov
	camera_rig.walking_distance = walking_distance
	camera_rig.running_fov = running_fov
	camera_rig.running_distance = running_distance
	camera_rig.jumping_fov = jumping_fov
	camera_rig.jumping_distance = jumping_distance

func apply_to_input_manager(input_manager: InputManager):
	input_manager.input_deadzone = input_deadzone
	input_manager.movement_update_interval = movement_update_interval
	
	# Apply to click navigation component if it exists
	var click_nav = input_manager.get_node_or_null("ClickNavigationComponent")
	if click_nav:
		click_nav.arrival_threshold = click_arrival_threshold
