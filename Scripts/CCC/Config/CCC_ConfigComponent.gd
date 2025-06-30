# 3CConfigComponent.gd - 3C Framework configuration manager
extends Node
class_name CCC_ConfigComponent

# === SIGNALS ===
signal config_changed(new_config: CCC_CharacterConfig)
signal config_applied()

# === EXPORTS ===
@export_group("Configuration")
@export var active_config: CCC_CharacterConfig
@export var auto_apply_on_ready: bool = true
@export var enable_debug_output: bool = false

# === INTERNAL STATE ===
var config_history: Array[CCC_CharacterConfig] = []
var current_config_name: String = ""

func _ready():
	setup_configuration()
	
	if auto_apply_on_ready and active_config:
		apply_configuration()

func setup_configuration():
	"""Setup initial configuration"""
	if not active_config:
		# Create default configuration
		active_config = CCC_CharacterConfig.new()
		
		if enable_debug_output:
			print("3CConfigComponent: Created default configuration")
	
	current_config_name = active_config.config_name

# === CONFIGURATION MANAGEMENT ===

func set_configuration(new_config: CCC_CharacterConfig):
	"""Set new active configuration"""
	if not new_config:
		push_error("3CConfigComponent: Cannot set null configuration")
		return
	
	# Validate configuration
	if not new_config.validate_config():
		push_error("3CConfigComponent: Configuration validation failed")
		return
	
	# Store previous config in history
	if active_config:
		config_history.append(active_config)
	
	active_config = new_config
	current_config_name = new_config.config_name
	
	config_changed.emit(new_config)
	
	if enable_debug_output:
		print("3CConfigComponent: Configuration changed to ", new_config.config_name)

func apply_configuration():
	"""Apply current configuration to all connected components"""
	if not active_config:
		push_error("3CConfigComponent: No active configuration to apply")
		return
	
	# Send configuration to all sibling components
	var parent_node = get_parent()
	if parent_node:
		notify_components_of_config_change(parent_node)
	
	config_applied.emit()
	
	if enable_debug_output:
		print("3CConfigComponent: Configuration applied - ", active_config.config_name)

func notify_components_of_config_change(node: Node):
	"""Recursively notify all components of configuration change"""
	# Check if this node can receive config updates
	if node.has_method("configure_from_3c"):
		node.configure_from_3c(active_config)
		if enable_debug_output:
			print("3CConfigComponent: Configured ", node.name)
	
	# Recursively check children
	for child in node.get_children():
		notify_components_of_config_change(child)

# === CONFIGURATION PRESETS ===

func load_preset(preset_name: String):
	"""Load a predefined configuration preset"""
	var preset_config: CCC_CharacterConfig
	
	match preset_name.to_lower():
		"action_adventure":
			preset_config = create_action_adventure_preset()
		"fps":
			preset_config = create_fps_preset()
		"rts":
			preset_config = create_rts_preset()
		"platformer":
			preset_config = create_platformer_preset()
		_:
			push_error("3CConfigComponent: Unknown preset: " + preset_name)
			return
	
	set_configuration(preset_config)
	apply_configuration()

func create_action_adventure_preset() -> CCC_CharacterConfig:
	"""Create action-adventure style configuration (Zelda BOTW)"""
	var config = CCC_CharacterConfig.new()
	config.config_name = "Action Adventure"
	
	# Character settings
	config.walk_speed = 3.0
	config.run_speed = 6.0
	config.sprint_speed = 9.0
	config.jump_height = 3.0
	
	# Camera settings
	config.camera_distance = 4.0
	config.camera_fov = 75.0
	config.mouse_sensitivity = 0.002
	
	# 3C types
	config.character_type = CCC_CharacterConfig.CharacterType.AVATAR
	config.camera_type = CCC_CharacterConfig.CameraType.ORBITAL
	config.control_type = CCC_CharacterConfig.ControlType.DIRECT
	
	return config

func create_fps_preset() -> CCC_CharacterConfig:
	"""Create first-person shooter configuration"""
	var config = CCC_CharacterConfig.new()
	config.config_name = "First Person Shooter"
	
	# Character settings
	config.walk_speed = 4.0
	config.run_speed = 8.0
	config.sprint_speed = 12.0
	config.jump_height = 2.5
	
	# Camera settings
	config.camera_distance = 0.0  # First person
	config.camera_fov = 90.0
	config.mouse_sensitivity = 0.003
	
	# 3C types
	config.character_type = CCC_CharacterConfig.CharacterType.AVATAR
	config.camera_type = CCC_CharacterConfig.CameraType.FIRST_PERSON
	config.control_type = CCC_CharacterConfig.ControlType.DIRECT
	
	return config

func create_rts_preset() -> CCC_CharacterConfig:
	"""Create real-time strategy configuration"""
	var config = CCC_CharacterConfig.new()
	config.config_name = "Real Time Strategy"
	
	# Character settings (minimal - camera focus)
	config.walk_speed = 0.0
	config.run_speed = 0.0
	config.sprint_speed = 0.0
	config.jump_height = 0.0
	
	# Camera settings
	config.camera_distance = 15.0
	config.camera_height_offset = 10.0
	config.camera_fov = 60.0
	config.mouse_sensitivity = 0.001
	
	# 3C types
	config.character_type = CCC_CharacterConfig.CharacterType.COMMANDER
	config.camera_type = CCC_CharacterConfig.CameraType.STRATEGIC
	config.control_type = CCC_CharacterConfig.ControlType.TARGET_BASED
	
	return config

func create_platformer_preset() -> CCC_CharacterConfig:
	"""Create 2D-style platformer configuration"""
	var config = CCC_CharacterConfig.new()
	config.config_name = "Platformer"
	
	# Character settings
	config.walk_speed = 2.5
	config.run_speed = 5.0
	config.sprint_speed = 7.0
	config.jump_height = 4.0
	
	# Camera settings
	config.camera_distance = 6.0
	config.camera_fov = 65.0
	config.mouse_sensitivity = 0.001  # Minimal camera control
	
	# 3C types
	config.character_type = CCC_CharacterConfig.CharacterType.AVATAR
	config.camera_type = CCC_CharacterConfig.CameraType.FOLLOWING
	config.control_type = CCC_CharacterConfig.ControlType.DIRECT
	
	return config

# === CONFIGURATION ACCESS ===

func get_config_value(property_name: String, default_value = null):
	"""Get configuration value by property name"""
	if not active_config:
		return default_value
	
	if property_name in active_config:
		return active_config.get(property_name)
	
	return default_value

func set_config_value(property_name: String, value):
	"""Set configuration value by property name"""
	if not active_config:
		return
	
	if property_name in active_config:
		active_config.set(property_name, value)
		config_changed.emit(active_config)

func get_camera_values_for_state(state_name: String) -> Dictionary:
	"""Get camera values for specific character state"""
	if active_config and active_config.has_method("get_camera_values_for_state"):
		return active_config.get_camera_values_for_state(state_name)
	
	return {"fov": 75.0, "distance": 4.0}

func get_speed_for_input_magnitude(magnitude: float) -> float:
	"""Get speed for input magnitude"""
	if active_config and active_config.has_method("get_speed_for_input_magnitude"):
		return active_config.get_speed_for_input_magnitude(magnitude)
	
	return 3.0  # Fallback

# === CONFIGURATION HISTORY ===

func get_previous_config() -> CCC_CharacterConfig:
	"""Get previous configuration from history"""
	if config_history.size() > 0:
		return config_history[-1]
	return null

func revert_to_previous_config():
	"""Revert to previous configuration"""
	var previous = get_previous_config()
	if previous:
		set_configuration(previous)
		apply_configuration()

func clear_config_history():
	"""Clear configuration history"""
	config_history.clear()

# === PUBLIC API ===

func get_active_config() -> CCC_CharacterConfig:
	"""Get current active configuration"""
	return active_config

func get_config_name() -> String:
	"""Get name of current configuration"""
	return current_config_name

func is_config_valid() -> bool:
	"""Check if current configuration is valid"""
	return active_config != null and active_config.validate_config()

func get_available_presets() -> Array[String]:
	"""Get list of available preset names"""
	return ["action_adventure", "fps", "rts", "platformer"]

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get debug information about configuration component"""
	return {
		"active_config_name": current_config_name,
		"config_valid": is_config_valid(),
		"config_history_size": config_history.size(),
		"auto_apply": auto_apply_on_ready,
		"available_presets": get_available_presets()
	}
