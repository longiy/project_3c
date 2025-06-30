# 3CPresets.gd - Predefined 3C Configurations
extends Resource
class_name TC3Presets

# === PRESET CONFIGURATIONS ===

static func get_botw_config() -> CharacterConfig:
	"""Breath of the Wild style configuration"""
	var config = CharacterConfig.new()
	config.config_name = "BOTW Explorer"
	
	# Character Axis - Avatar type
	config.character_type = CharacterConfig.CharacterType.AVATAR
	config.character_responsiveness = 1.0
	config.character_embodiment_quality = 0.9
	config.walk_speed = 3.5
	config.run_speed = 7.0
	config.sprint_speed = 10.0
	config.acceleration = 12.0
	config.deceleration = 18.0
	config.jump_height = 5.0
	config.air_control = 0.4
	
	# Camera Axis - Orbital
	config.camera_type = CharacterConfig.CameraType.ORBITAL
	config.camera_distance = 4.5
	config.camera_height = 2.5
	config.camera_smoothing = 6.0
	config.camera_fov = 75.0
	config.mouse_sensitivity = 1.2
	config.orbit_speed = 2.5
	config.zoom_speed = 1.0
	
	# Control Axis - Direct
	config.control_type = CharacterConfig.ControlType.DIRECT
	config.control_precision = 0.9
	config.control_complexity = 0.7
	config.input_deadzone = 0.1
	config.input_smoothing = 0.05
	config.gamepad_enabled = true
	
	# Temporal Context
	config.temporal_scope_description = "Exploration and discovery sessions"
	config.experience_duration_target = 1800.0  # 30 minutes
	
	return config

static func get_diablo_config() -> CharacterConfig:
	"""Diablo-style ARPG configuration"""
	var config = CharacterConfig.new()
	config.config_name = "Diablo ARPG"
	
	# Character Axis - Controller type
	config.character_type = CharacterConfig.CharacterType.CONTROLLER
	config.character_responsiveness = 0.8
	config.character_embodiment_quality = 0.6
	config.walk_speed = 2.5
	config.run_speed = 5.0
	config.sprint_speed = 7.5
	config.acceleration = 15.0
	config.deceleration = 20.0
	config.jump_height = 3.0
	config.air_control = 0.2
	
	# Camera Axis - Following
	config.camera_type = CharacterConfig.CameraType.FOLLOWING
	config.camera_distance = 6.0
	config.camera_height = 4.0
	config.camera_smoothing = 4.0
	config.camera_fov = 65.0
	config.mouse_sensitivity = 0.8
	config.orbit_speed = 1.5
	config.zoom_speed = 1.2
	
	# Control Axis - Target Based
	config.control_type = CharacterConfig.ControlType.TARGET_BASED
	config.control_precision = 0.7
	config.control_complexity = 0.8
	config.input_deadzone = 0.05
	config.input_smoothing = 0.15
	config.gamepad_enabled = false
	
	# Temporal Context
	config.temporal_scope_description = "Combat encounters and loot collection"
	config.experience_duration_target = 900.0  # 15 minutes
	
	return config

static func get_dark_souls_config() -> CharacterConfig:
	"""Dark Souls deliberate combat configuration"""
	var config = CharacterConfig.new()
	config.config_name = "Dark Souls Tactical"
	
	# Character Axis - Avatar type (high embodiment)
	config.character_type = CharacterConfig.CharacterType.AVATAR
	config.character_responsiveness = 0.7
	config.character_embodiment_quality = 1.0
	config.walk_speed = 2.0
	config.run_speed = 4.0
	config.sprint_speed = 6.0
	config.acceleration = 8.0
	config.deceleration = 12.0
	config.jump_height = 3.5
	config.air_control = 0.1
	
	# Camera Axis - Orbital (tight)
	config.camera_type = CharacterConfig.CameraType.ORBITAL
	config.camera_distance = 3.0
	config.camera_height = 1.8
	config.camera_smoothing = 10.0
	config.camera_fov = 70.0
	config.mouse_sensitivity = 0.9
	config.orbit_speed = 1.8
	config.zoom_speed = 0.8
	
	# Control Axis - Direct (precise)
	config.control_type = CharacterConfig.ControlType.DIRECT
	config.control_precision = 1.0
	config.control_complexity = 0.5
	config.input_deadzone = 0.15
	config.input_smoothing = 0.02
	config.gamepad_enabled = true
	
	# Temporal Context
	config.temporal_scope_description = "Deliberate combat encounters"
	config.experience_duration_target = 600.0  # 10 minutes
	
	return config

static func get_fps_config() -> CharacterConfig:
	"""First Person Shooter configuration"""
	var config = CharacterConfig.new()
	config.config_name = "FPS Shooter"
	
	# Character Axis - Avatar type (immediate)
	config.character_type = CharacterConfig.CharacterType.AVATAR
	config.character_responsiveness = 1.0
	config.character_embodiment_quality = 1.0
	config.walk_speed = 4.0
	config.run_speed = 8.0
	config.sprint_speed = 12.0
	config.acceleration = 20.0
	config.deceleration = 25.0
	config.jump_height = 4.0
	config.air_control = 0.6
	
	# Camera Axis - First Person
	config.camera_type = CharacterConfig.CameraType.FIRST_PERSON
	config.camera_distance = 0.0
	config.camera_height = 1.7
	config.camera_smoothing = 0.0  # No smoothing in FPS
	config.camera_fov = 90.0
	config.mouse_sensitivity = 2.0
	config.orbit_speed = 3.0
	config.zoom_speed = 0.0
	
	# Control Axis - Direct (immediate)
	config.control_type = CharacterConfig.ControlType.DIRECT
	config.control_precision = 1.0
	config.control_complexity = 0.3
	config.input_deadzone = 0.02
	config.input_smoothing = 0.0
	config.gamepad_enabled = true
	
	# Temporal Context
	config.temporal_scope_description = "Fast-paced combat encounters"
	config.experience_duration_target = 300.0  # 5 minutes
	
	return config

static func get_rts_config() -> CharacterConfig:
	"""Real-Time Strategy configuration"""
	var config = CharacterConfig.new()
	config.config_name = "RTS Commander"
	
	# Character Axis - Observer type
	config.character_type = CharacterConfig.CharacterType.OBSERVER
	config.character_responsiveness = 0.3
	config.character_embodiment_quality = 0.1
	config.walk_speed = 0.0
	config.run_speed = 0.0
	config.sprint_speed = 0.0
	config.acceleration = 0.0
	config.deceleration = 0.0
	config.jump_height = 0.0
	config.air_control = 0.0
	
	# Camera Axis - Fixed (high overview)
	config.camera_type = CharacterConfig.CameraType.FIXED
	config.camera_distance = 15.0
	config.camera_height = 12.0
	config.camera_smoothing = 2.0
	config.camera_fov = 60.0
	config.mouse_sensitivity = 1.5
	config.orbit_speed = 1.0
	config.zoom_speed = 2.0
	
	# Control Axis - Constructive
	config.control_type = CharacterConfig.ControlType.CONSTRUCTIVE
	config.control_precision = 0.9
	config.control_complexity = 1.0
	config.input_deadzone = 0.01
	config.input_smoothing = 0.0
	config.gamepad_enabled = false
	
	# Temporal Context
	config.temporal_scope_description = "Strategic decision-making phases"
	config.experience_duration_target = 2400.0  # 40 minutes
	
	return config

static func get_platformer_config() -> CharacterConfig:
	"""2.5D Platformer configuration"""
	var config = CharacterConfig.new()
	config.config_name = "Platformer Hero"
	
	# Character Axis - Avatar type (responsive)
	config.character_type = CharacterConfig.CharacterType.AVATAR
	config.character_responsiveness = 1.0
	config.character_embodiment_quality = 0.8
	config.walk_speed = 3.0
	config.run_speed = 6.0
	config.sprint_speed = 9.0
	config.acceleration = 25.0
	config.deceleration = 30.0
	config.jump_height = 6.0
	config.air_control = 0.8
	
	# Camera Axis - Following (side view)
	config.camera_type = CharacterConfig.CameraType.FOLLOWING
	config.camera_distance = 8.0
	config.camera_height = 2.0
	config.camera_smoothing = 12.0
	config.camera_fov = 70.0
	config.mouse_sensitivity = 0.5
	config.orbit_speed = 0.0
	config.zoom_speed = 0.5
	
	# Control Axis - Direct (precise)
	config.control_type = CharacterConfig.ControlType.DIRECT
	config.control_precision = 1.0
	config.control_complexity = 0.4
	config.input_deadzone = 0.08
	config.input_smoothing = 0.0
	config.gamepad_enabled = true
	
	# Temporal Context
	config.temporal_scope_description = "Precision platforming challenges"
	config.experience_duration_target = 180.0  # 3 minutes
	
	return config

# === UTILITY FUNCTIONS ===

static func get_all_presets() -> Array[CharacterConfig]:
	"""Get all available preset configurations"""
	return [
		get_botw_config(),
		get_diablo_config(),
		get_dark_souls_config(),
		get_fps_config(),
		get_rts_config(),
		get_platformer_config()
	]

static func get_preset_by_name(preset_name: String) -> CharacterConfig:
	"""Get preset configuration by name"""
	var presets = get_all_presets()
	for preset in presets:
		if preset.config_name == preset_name:
			return preset
	
	push_warning("Preset not found: " + preset_name)
	return get_botw_config()  # Default fallback

static func create_custom_config(name: String, base_preset: CharacterConfig = null) -> CharacterConfig:
	"""Create a custom configuration based on a preset"""
	var config = base_preset.duplicate() if base_preset else get_botw_config().duplicate()
	config.config_name = name
	return config
