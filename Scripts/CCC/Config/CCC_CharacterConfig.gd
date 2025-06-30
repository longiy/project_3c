# CharacterConfig.gd - 3C Framework configuration data class
extends Resource
class_name CCC_CharacterConfig

# === CONFIGURATION METADATA ===
@export var config_name: String = "Default Configuration"
@export var config_description: String = ""

# === CHARACTER AXIS ===
@export_group("Character Properties")
@export var walk_speed: float = 3.0
@export var run_speed: float = 6.0
@export var sprint_speed: float = 9.0
@export var acceleration: float = 15.0
@export var deceleration: float = 20.0
@export var jump_height: float = 3.0
@export var gravity_multiplier: float = 1.0
@export var air_control: float = 0.3

# === CAMERA AXIS ===
@export_group("Camera Properties")
@export var camera_distance: float = 4.0
@export var camera_height_offset: float = 1.6
@export var camera_fov: float = 75.0
@export var camera_smoothing: float = 8.0
@export var min_camera_distance: float = 1.0
@export var max_camera_distance: float = 10.0

# === CONTROL AXIS ===
@export_group("Control Properties")
@export var mouse_sensitivity: float = 0.002
@export var orbit_speed: float = 3.0
@export var zoom_speed: float = 0.5
@export var input_deadzone: float = 0.1
@export var input_smoothing: float = 0.0

# === CAMERA CONSTRAINTS ===
@export_group("Camera Constraints")
@export var pitch_limit_min: float = -80.0
@export var pitch_limit_max: float = 50.0
@export var invert_y_axis: bool = false

# === 3C TYPE DEFINITIONS ===
enum CharacterType {
	AVATAR,     # Direct character control
	COMMANDER,  # Multi-unit control
	ARCHITECT,  # Building/creation
	OBSERVER    # Passive observation
}

enum CameraType {
	ORBITAL,        # Mouse orbits around character
	FOLLOWING,      # Camera follows with lag
	FIXED,          # Static camera position
	FIRST_PERSON,   # Eye-level camera
	STRATEGIC       # RTS-style overhead
}

enum ControlType {
	DIRECT,         # Immediate input response
	TARGET_BASED,   # Click-to-target
	MODE_BASED,     # Context switching
	CONSTRUCTIVE    # Building/creation tools
}

@export_group("3C Framework Types")
@export var character_type: CharacterType = CharacterType.AVATAR
@export var camera_type: CameraType = CameraType.ORBITAL
@export var control_type: ControlType = ControlType.DIRECT

# === GAMEPLAY CONTEXT ===
@export_group("Gameplay Context")
@export var supports_click_navigation: bool = true
@export var supports_gamepad: bool = true
@export var target_framerate: int = 60

# === STATE-SPECIFIC CAMERA VALUES ===
@export_group("State Camera Response")
@export var idle_fov: float = 50.0
@export var idle_distance: float = 4.0
@export var walking_fov: float = 60.0
@export var walking_distance: float = 4.0
@export var running_fov: float = 70.0
@export var running_distance: float = 4.5
@export var jumping_fov: float = 85.0
@export var jumping_distance: float = 4.8
@export var airborne_fov: float = 90.0
@export var airborne_distance: float = 5.0

func _init():
	"""Initialize with sensible defaults"""
	resource_name = config_name

# === VALIDATION ===

func validate_config() -> bool:
	"""Validate configuration values"""
	var valid = true
	
	# Speed validation
	if walk_speed <= 0 or run_speed <= walk_speed or sprint_speed <= run_speed:
		push_error("CharacterConfig: Invalid speed progression")
		valid = false
	
	# Camera validation
	if min_camera_distance >= max_camera_distance:
		push_error("CharacterConfig: Invalid camera distance range")
		valid = false
	
	if camera_fov <= 0 or camera_fov > 180:
		push_error("CharacterConfig: Invalid camera FOV")
		valid = false
	
	# Pitch validation
	if pitch_limit_min >= pitch_limit_max:
		push_error("CharacterConfig: Invalid pitch limits")
		valid = false
	
	return valid

# === UTILITY METHODS ===

func get_speed_for_input_magnitude(magnitude: float) -> float:
	"""Get speed based on input magnitude"""
	if magnitude <= 0:
		return 0.0
	elif magnitude <= 0.5:
		return walk_speed
	elif magnitude <= 0.8:
		return run_speed
	else:
		return sprint_speed

func get_camera_values_for_state(state_name: String) -> Dictionary:
	"""Get camera FOV and distance for specific state"""
	match state_name.to_lower():
		"idle":
			return {"fov": idle_fov, "distance": idle_distance}
		"walking", "walk":
			return {"fov": walking_fov, "distance": walking_distance}
		"running", "run":
			return {"fov": running_fov, "distance": running_distance}
		"jumping", "jump":
			return {"fov": jumping_fov, "distance": jumping_distance}
		"airborne", "falling":
			return {"fov": airborne_fov, "distance": airborne_distance}
		_:
			return {"fov": camera_fov, "distance": camera_distance}

func get_type_descriptions() -> Dictionary:
	"""Get human-readable descriptions of 3C types"""
	return {
		"character_types": {
			CharacterType.AVATAR: "Direct character control",
			CharacterType.COMMANDER: "Multi-unit control",
			CharacterType.ARCHITECT: "Building/creation",
			CharacterType.OBSERVER: "Passive observation"
		},
		"camera_types": {
			CameraType.ORBITAL: "Mouse orbits around character",
			CameraType.FOLLOWING: "Camera follows with lag",
			CameraType.FIXED: "Static camera position",
			CameraType.FIRST_PERSON: "Eye-level camera",
			CameraType.STRATEGIC: "RTS-style overhead"
		},
		"control_types": {
			ControlType.DIRECT: "Immediate input response",
			ControlType.TARGET_BASED: "Click-to-target",
			ControlType.MODE_BASED: "Context switching",
			ControlType.CONSTRUCTIVE: "Building/creation tools"
		}
	}
