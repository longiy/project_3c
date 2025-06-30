# 3CPresets.gd - Predefined 3C Configuration Presets
extends Resource
class_name TCPresets

# === GAME STYLE PRESETS ===

static func get_botw_config() -> CharacterConfig:
	var config = CharacterConfig.new()
	config.config_name = "BOTW Style (Avatar/Orbital/Direct)"
	
	# Character: Avatar - high embodiment, responsive
	config.character_type = CharacterConfig.CharacterType.AVATAR
	config.character_responsiveness = 1.0
	config.character_embodiment_quality = 1.0
	config.walk_speed = 3.0
	config.run_speed = 6.0
	config.ground_acceleration = 15.0
	config.rotation_speed = 12.0
	
	# Camera: Orbital - dynamic, following
	config.camera_type = CharacterConfig.CameraType.ORBITAL
	config.camera_distance = 4.0
	config.camera_smoothing = 8.0
	config.camera_fov = 75.0
	config.mouse_sensitivity = 0.002
	
	# Control: Direct - WASD immediate response
	config.control_type = CharacterConfig.ControlType.DIRECT
	config.control_precision = 1.0
	config.input_deadzone = 0.1
	
	return config

static func get_diablo_config() -> CharacterConfig:
	var config = CharacterConfig.new()
	config.config_name = "Diablo Style (Controller/Following/Target)"
	
	# Character: Controller - less embodied, more strategic
	config.character_type = CharacterConfig.CharacterType.CONTROLLER
	config.character_responsiveness = 0.8
	config.character_embodiment_quality = 0.6
	config.walk_speed = 2.5
	config.run_speed = 5.0
	config.ground_acceleration = 12.0
	config.rotation_speed = 8.0
	
	# Camera: Following - isometric-like, stable
	config.camera_type = CharacterConfig.CameraType.FOLLOWING
	config.camera_distance = 6.0
	config.camera_smoothing = 10.0
	config.camera_fov = 60.0
	config.mouse_sensitivity = 0.001
	
	# Control: Target-based - click to move
	config.control_type = CharacterConfig.ControlType.TARGET_BASED
	config.control_precision = 0.7
	config.click_arrival_threshold = 0.3
	config.input_deadzone = 0.05
	
	return config

static func get_dark_souls_config() -> CharacterConfig:
	var config = CharacterConfig.new()
	config.config_name = "Dark Souls Style (Avatar/Orbital/Direct)"
	
	# Character: Avatar - high embodiment, deliberate
	config.character_type = CharacterConfig.CharacterType.AVATAR
	config.character_responsiveness = 0.7  # More deliberate
	config.character_embodiment_quality = 1.0
	config.walk_speed = 2.0  # Slower, more careful
	config.run_speed = 4.5
	config.ground_acceleration = 10.0  # Less snappy
	config.rotation_speed = 8.0  # More deliberate turns
	
	# Camera: Orbital - tight, responsive
	config.camera_type = CharacterConfig.CameraType.ORBITAL
	config.camera_distance = 3.0  # Closer
	config.camera_smoothing = 6.0  # More responsive
	config.camera_fov = 70.0
	config.mouse_sensitivity = 0.0025
	
	# Control: Direct - precise, committed
	config.control_type = CharacterConfig.ControlType.DIRECT
	config.control_precision = 1.0
	config.input_deadzone = 0.15  # Larger deadzone for deliberate input
	
	return config

static func get_fps_config() -> CharacterConfig:
	var config = CharacterConfig.new()
	config.config_name = "FPS Style (Avatar/FirstPerson/Direct)"
	
	# Character: Avatar - maximum embodiment
	config.character_type = CharacterConfig.CharacterType.AVATAR
	config.character_responsiveness = 1.0
	config.character_embodiment_quality = 1.0
	config.walk_speed = 4.0
	config.run_speed = 8.0
	config.ground_acceleration = 20.0  # Snappy
	config.rotation_speed = 15.0
	
	# Camera: First Person - direct view
	config.camera_type = CharacterConfig.CameraType.FIRST_PERSON
	config.camera_distance = 0.0  # No distance in FP
	config.camera_smoothing = 2.0  # Minimal smoothing
	config.camera_fov = 90.0  # Wide FOV
	config.mouse_sensitivity = 0.003
	
	# Control: Direct - immediate response
	config.control_type = CharacterConfig.ControlType.DIRECT
	config.control_precision = 1.0
	config.input_deadzone = 0.05  # Very responsive
	
	return config

static func get_rts_config() -> CharacterConfig:
	var config = CharacterConfig.new()
	config.config_name = "RTS Style (Observer/Fixed/Constructive)"
	
	# Character: Observer - minimal embodiment
	config.character_type = CharacterConfig.CharacterType.OBSERVER
	config.character_responsiveness = 0.5
	config.character_embodiment_quality = 0.3
	config.walk_speed = 2.0
	config.run_speed = 4.0
	config.ground_acceleration = 8.0
	config.rotation_speed = 6.0
	
	# Camera: Fixed - strategic overview
	config.camera_type = CharacterConfig.CameraType.FIXED
	config.camera_distance = 8.0
	config.camera_smoothing = 12.0
	config.camera_fov = 50.0  # Narrower for overview
	config.mouse_sensitivity = 0.001
	
	# Control: Constructive - build/command oriented
	config.control_type = CharacterConfig.ControlType.CONSTRUCTIVE
	config.control_precision = 0.8
	config.click_arrival_threshold = 0.8
	config.input_deadzone = 0.2
	
	return config

static func get_puzzle_config() -> CharacterConfig:
	var config = CharacterConfig.new()
	config.config_name = "Puzzle Style (Observer/Fixed/Guided)"
	
	# Character: Observer - focus on problem solving
	config.character_type = CharacterConfig.CharacterType.OBSERVER
	config.character_responsiveness = 0.6
	config.character_embodiment_quality = 0.4
	config.walk_speed = 1.5
	config.run_speed = 3.0
	config.ground_acceleration = 8.0
	config.rotation_speed = 5.0
	
	# Camera: Fixed - stable for analysis
	config.camera_type = CharacterConfig.CameraType.FIXED
	config.camera_distance = 5.0
	config.camera_smoothing = 15.0
	config.camera_fov = 65.0
	config.mouse_sensitivity = 0.0015
	
	# Control: Guided - assisted interaction
	config.control_type = CharacterConfig.ControlType.GUIDED
	config.control_precision = 0.6
	config.click_arrival_threshold = 0.2
	config.input_deadzone = 0.15
	
	return config

# === UTILITY FUNCTIONS ===

static func get_all_presets() -> Array[CharacterConfig]:
	return [
		get_botw_config(),
		get_diablo_config(),
		get_dark_souls_config(),
		get_fps_config(),
		get_rts_config(),
		get_puzzle_config()
	]

static func get_preset_names() -> Array[String]:
	var names: Array[String] = []
	for preset in get_all_presets():
		names.append(preset.config_name)
	return names

static func get_preset_by_name(name: String) -> CharacterConfig:
	for preset in get_all_presets():
		if preset.config_name == name:
			return preset
	return get_botw_config()  # Default fallback
