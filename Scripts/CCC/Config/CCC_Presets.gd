# 3CPresets.gd - Predefined 3C configuration presets
extends RefCounted
class_name CCC_Presets

# === PRESET FACTORY METHODS ===

static func get_action_adventure_config() -> CharacterConfig:
	"""Action-Adventure configuration (Zelda BOTW style)"""
	var config = CharacterConfig.new()
	config.config_name = "Action Adventure"
	config.config_description = "Third-person action with exploration focus"
	
	# Character Axis - Avatar with responsive movement
	config.character_type = CharacterConfig.CharacterType.AVATAR
	config.walk_speed = 3.0
	config.run_speed = 6.0
	config.sprint_speed = 9.0
	config.acceleration = 15.0
	config.deceleration = 20.0
	config.jump_height = 3.0
	config.gravity_multiplier = 1.0
	config.air_control = 0.3
	
	# Camera Axis - Orbital with dynamic response
	config.camera_type = CharacterConfig.CameraType.ORBITAL
	config.camera_distance = 4.0
	config.camera_height_offset = 1.6
	config.camera_fov = 75.0
	config.camera_smoothing = 8.0
	config.min_camera_distance = 1.5
	config.max_camera_distance = 8.0
	
	# Control Axis - Hybrid direct and target-based
	config.control_type = CharacterConfig.ControlType.DIRECT
	config.mouse_sensitivity = 0.002
	config.orbit_speed = 3.0
	config.zoom_speed = 0.5
	config.input_deadzone = 0.1
	config.input_smoothing = 0.0
	
	# Camera constraints
	config.pitch_limit_min = -80.0
	config.pitch_limit_max = 50.0
	config.invert_y_axis = false
	
	# Gameplay features
	config.supports_click_navigation = true
	config.supports_gamepad = true
	
	# State-specific camera values
	config.idle_fov = 70.0
	config.idle_distance = 4.0
	config.walking_fov = 72.0
	config.walking_distance = 4.2
	config.running_fov = 75.0
	config.running_distance = 4.5
	config.jumping_fov = 80.0
	config.jumping_distance = 4.8
	config.airborne_fov = 85.0
	config.airborne_distance = 5.2
	
	return config

static func get_fps_config() -> CharacterConfig:
	"""First-Person Shooter configuration"""
	var config = CharacterConfig.new()
	config.config_name = "First Person Shooter"
	config.config_description = "Immersive first-person combat"
	
	# Character Axis - Avatar with fast movement
	config.character_type = CharacterConfig.CharacterType.AVATAR
	config.walk_speed = 4.0
	config.run_speed = 8.0
	config.sprint_speed = 12.0
	config.acceleration = 20.0
	config.deceleration = 25.0
	config.jump_height = 2.5
	config.gravity_multiplier = 1.2
	config.air_control = 0.6
	
	# Camera Axis - First Person
	config.camera_type = CharacterConfig.CameraType.FIRST_PERSON
	config.camera_distance = 0.0
	config.camera_height_offset = 1.7
	config.camera_fov = 90.0
	config.camera_smoothing = 0.0  # No smoothing in FPS
	config.min_camera_distance = 0.0
	config.max_camera_distance = 0.0
	
	# Control Axis - Direct with high precision
	config.control_type = CharacterConfig.ControlType.DIRECT
	config.mouse_sensitivity = 0.003
	config.orbit_speed = 5.0
	config.zoom_speed = 0.0  # No zoom in FPS
	config.input_deadzone = 0.02
	config.input_smoothing = 0.0
	
	# Camera constraints
	config.pitch_limit_min = -90.0
	config.pitch_limit_max = 90.0
	config.invert_y_axis = false
	
	# Gameplay features
	config.supports_click_navigation = false
	config.supports_gamepad = true
	
	# State-specific camera values (FOV only for FPS)
	config.idle_fov = 90.0
	config.walking_fov = 88.0
	config.running_fov = 85.0
	config.jumping_fov = 95.0
	config.airborne_fov = 100.0
	
	return config

static func get_rts_config() -> CharacterConfig:
	"""Real-Time Strategy configuration"""
	var config = CharacterConfig.new()
	config.config_name = "Real Time Strategy"
	config.config_description = "Strategic overhead view for unit command"
	
	# Character Axis - Commander (no direct character)
	config.character_type = CharacterConfig.CharacterType.COMMANDER
	config.walk_speed = 0.0
	config.run_speed = 0.0
	config.sprint_speed = 0.0
	config.acceleration = 0.0
	config.deceleration = 0.0
	config.jump_height = 0.0
	config.gravity_multiplier = 0.0
	config.air_control = 0.0
	
	# Camera Axis - Strategic overhead
	config.camera_type = CharacterConfig.CameraType.STRATEGIC
	config.camera_distance = 15.0
	config.camera_height_offset = 12.0
	config.camera_fov = 60.0
	config.camera_smoothing = 2.0
	config.min_camera_distance = 8.0
	config.max_camera_distance = 25.0
	
	# Control Axis - Target-based with precision
	config.control_type = CharacterConfig.ControlType.TARGET_BASED
	config.mouse_sensitivity = 0.001
	config.orbit_speed = 1.5
	config.zoom_speed = 2.0
	config.input_deadzone = 0.01
	config.input_smoothing = 0.0
	
	# Camera constraints
	config.pitch_limit_min = -45.0
	config.pitch_limit_max = -10.0  # Always looking down
	config.invert_y_axis = false
	
	# Gameplay features
	config.supports_click_navigation = true
	config.supports_gamepad = false
	
	return config

static func get_platformer_config() -> CharacterConfig:
	"""2.5D Platformer configuration"""
	var config = CharacterConfig.new()
	config.config_name = "Platformer"
	config.config_description = "Side-view platforming with precise controls"
	
	# Character Axis - Avatar with platforming focus
	config.character_type = CharacterConfig.CharacterType.AVATAR
	config.walk_speed = 2.5
	config.run_speed = 5.0
	config.sprint_speed = 7.0
	config.acceleration = 25.0
	config.deceleration = 30.0
	config.jump_height = 4.0
	config.gravity_multiplier = 1.5
	config.air_control = 0.8
	
	# Camera Axis - Following with constraints
	config.camera_type = CharacterConfig.CameraType.FOLLOWING
	config.camera_distance = 6.0
	config.camera_height_offset = 1.0
	config.camera_fov = 65.0
	config.camera_smoothing = 5.0
	config.min_camera_distance = 5.0
	config.max_camera_distance = 8.0
	
	# Control Axis - Direct with tight response
	config.control_type = CharacterConfig.ControlType.DIRECT
	config.mouse_sensitivity = 0.001
	config.orbit_speed = 1.0
	config.zoom_speed = 0.3
	config.input_deadzone = 0.05
	config.input_smoothing = 0.0
	
	# Camera constraints (limited camera movement)
	config.pitch_limit_min = -20.0
	config.pitch_limit_max = 20.0
	config.invert_y_axis = false
	
	# Gameplay features
	config.supports_click_navigation = false
	config.supports_gamepad = true
	
	# State-specific camera values
	config.idle_fov = 65.0
	config.idle_distance = 6.0
	config.walking_fov = 67.0
	config.walking_distance = 6.2
	config.running_fov = 70.0
	config.running_distance = 6.5
	config.jumping_fov = 75.0
	config.jumping_distance = 7.0
	config.airborne_fov = 78.0
	config.airborne_distance = 7.2
	
	return config

static func get_creative_builder_config() -> CharacterConfig:
	"""Creative/Building game configuration (Minecraft style)"""
	var config = CharacterConfig.new()
	config.config_name = "Creative Builder"
	config.config_description = "First-person building and creation"
	
	# Character Axis - Architect with free movement
	config.character_type = CharacterConfig.CharacterType.ARCHITECT
	config.walk_speed = 3.5
	config.run_speed = 7.0
	config.sprint_speed = 10.0
	config.acceleration = 12.0
	config.deceleration = 15.0
	config.jump_height = 2.0
	config.gravity_multiplier = 0.8  # Slightly floaty
	config.air_control = 1.0  # Full air control for building
	
	# Camera Axis - First Person with orbital option
	config.camera_type = CharacterConfig.CameraType.FIRST_PERSON
	config.camera_distance = 0.0
	config.camera_height_offset = 1.6
	config.camera_fov = 80.0
	config.camera_smoothing = 0.0
	config.min_camera_distance = 0.0
	config.max_camera_distance = 10.0  # Can switch to third person
	
	# Control Axis - Mode-based (build vs move)
	config.control_type = CharacterConfig.ControlType.MODE_BASED
	config.mouse_sensitivity = 0.002
	config.orbit_speed = 3.0
	config.zoom_speed = 1.0
	config.input_deadzone = 0.1
	config.input_smoothing = 0.0
	
	# Camera constraints
	config.pitch_limit_min = -90.0
	config.pitch_limit_max = 90.0
	config.invert_y_axis = false
	
	# Gameplay features
	config.supports_click_navigation = true
	config.supports_gamepad = true
	
	return config

static func get_dark_souls_config() -> CharacterConfig:
	"""Dark Souls style configuration (deliberate, tactical combat)"""
	var config = CharacterConfig.new()
	config.config_name = "Dark Souls Combat"
	config.config_description = "Tactical third-person combat with commitment"
	
	# Character Axis - Avatar with deliberate movement
	config.character_type = CharacterConfig.CharacterType.AVATAR
	config.walk_speed = 2.0
	config.run_speed = 4.5
	config.sprint_speed = 6.5
	config.acceleration = 8.0  # Slower acceleration
	config.deceleration = 12.0
	config.jump_height = 2.5
	config.gravity_multiplier = 1.3
	config.air_control = 0.1  # Very limited air control
	
	# Camera Axis - Orbital with strategic positioning
	config.camera_type = CharacterConfig.CameraType.ORBITAL
	config.camera_distance = 3.5
	config.camera_height_offset = 1.4
	config.camera_fov = 65.0  # Narrower FOV for focus
	config.camera_smoothing = 6.0
	config.min_camera_distance = 2.0
	config.max_camera_distance = 6.0
	
	# Control Axis - Direct with precision timing
	config.control_type = CharacterConfig.ControlType.DIRECT
	config.mouse_sensitivity = 0.0015  # Lower sensitivity for precision
	config.orbit_speed = 2.5
	config.zoom_speed = 0.3
	config.input_deadzone = 0.15
	config.input_smoothing = 0.1  # Slight smoothing for weight
	
	# Camera constraints
	config.pitch_limit_min = -60.0
	config.pitch_limit_max = 40.0
	config.invert_y_axis = false
	
	# Gameplay features
	config.supports_click_navigation = false
	config.supports_gamepad = true
	
	# State-specific camera values
	config.idle_fov = 65.0
	config.idle_distance = 3.5
	config.walking_fov = 67.0
	config.walking_distance = 3.7
	config.running_fov = 70.0
	config.running_distance = 4.0
	config.jumping_fov = 72.0
	config.jumping_distance = 4.2
	config.airborne_fov = 75.0
	config.airborne_distance = 4.5
	
	return config

# === PRESET UTILITIES ===

static func get_all_preset_names() -> Array[String]:
	"""Get names of all available presets"""
	return [
		"action_adventure",
		"fps", 
		"rts",
		"platformer",
		"creative_builder",
		"dark_souls"
	]

static func get_preset_by_name(preset_name: String) -> CharacterConfig:
	"""Get preset configuration by name"""
	match preset_name.to_lower():
		"action_adventure":
			return get_action_adventure_config()
		"fps":
			return get_fps_config()
		"rts":
			return get_rts_config()
		"platformer":
			return get_platformer_config()
		"creative_builder":
			return get_creative_builder_config()
		"dark_souls":
			return get_dark_souls_config()
		_:
			push_error("3CPresets: Unknown preset name - " + preset_name)
			return get_action_adventure_config()  # Fallback

static func get_preset_descriptions() -> Dictionary:
	"""Get descriptions of all presets"""
	return {
		"action_adventure": "Third-person exploration and combat (Zelda BOTW)",
		"fps": "First-person shooter with fast movement (DOOM)",
		"rts": "Strategic overhead command view (StarCraft)",
		"platformer": "Side-view precise platforming (Mario)",
		"creative_builder": "First-person building and creation (Minecraft)", 
		"dark_souls": "Tactical third-person combat (Dark Souls)"
	}
