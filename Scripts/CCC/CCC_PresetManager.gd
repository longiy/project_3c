# CCC_PresetManager.gd - Centralized preset configuration
extends Resource
class_name CCC_PresetManager

@export_group("Quick Presets")
enum CCC_Preset {
	CUSTOM,
	BOTW_STYLE,
	DIABLO_STYLE,
	STRATEGY_GAME,
	FPS_SHOOTER,
	PLATFORMER_2D,
	RACING_GAME
}

@export var current_preset: CCC_Preset = CCC_Preset.BOTW_STYLE : set = set_current_preset

@export_subgroup("Individual Configuration")
@export var control_type: CCC_ControlManager.ControlType = CCC_ControlManager.ControlType.HYBRID
@export var character_type: CCC_CharacterManager.CharacterType = CCC_CharacterManager.CharacterType.AVATAR
@export var camera_type: CCC_CameraManager.CameraType = CCC_CameraManager.CameraType.ORBITAL

@export_subgroup("Fine-Tuning")
@export_range(0.1, 2.0, 0.1) var movement_responsiveness: float = 1.0
@export_range(0.1, 3.0, 0.1) var camera_sensitivity: float = 1.0
@export_range(0.0, 1.0, 0.1) var embodiment_quality: float = 1.0
@export var enable_ai_assistance: bool = false

# Preset configurations moved here from CCC_CharacterController
# === PRESET DEFINITIONS ===
var preset_configs = {
	CCC_Preset.BOTW_STYLE: {
		"name": "Breath of the Wild Style",
		"control": CCC_ControlManager.ControlType.HYBRID,
		"character": CCC_CharacterManager.CharacterType.AVATAR,
		"camera": CCC_CameraManager.CameraType.ORBITAL,
		"responsiveness": 1.0,
		"sensitivity": 1.0,
		"embodiment": 1.0,
		"ai_assistance": false
	},
	CCC_Preset.DIABLO_STYLE: {
		"name": "Diablo Style",
		"control": CCC_ControlManager.ControlType.TARGET_BASED,
		"character": CCC_CharacterManager.CharacterType.AVATAR,
		"camera": CCC_CameraManager.CameraType.FOLLOWING,
		"responsiveness": 0.8,
		"sensitivity": 0.7,
		"embodiment": 0.9,
		"ai_assistance": false
	},
	CCC_Preset.STRATEGY_GAME: {
		"name": "Strategy/RTS Style",
		"control": CCC_ControlManager.ControlType.TARGET_BASED,
		"character": CCC_CharacterManager.CharacterType.COMMANDER,
		"camera": CCC_CameraManager.CameraType.FIXED,
		"responsiveness": 0.6,
		"sensitivity": 0.5,
		"embodiment": 0.4,
		"ai_assistance": true
	},
	CCC_Preset.FPS_SHOOTER: {
		"name": "FPS Shooter Style",
		"control": CCC_ControlManager.ControlType.DIRECT,
		"character": CCC_CharacterManager.CharacterType.AVATAR,
		"camera": CCC_CameraManager.CameraType.FIRST_PERSON,
		"responsiveness": 1.0,
		"sensitivity": 1.2,
		"embodiment": 1.0,
		"ai_assistance": false
	},
	CCC_Preset.PLATFORMER_2D: {
		"name": "2D Platformer Style",
		"control": CCC_ControlManager.ControlType.DIRECT,
		"character": CCC_CharacterManager.CharacterType.AVATAR,
		"camera": CCC_CameraManager.CameraType.FOLLOWING,
		"responsiveness": 1.0,
		"sensitivity": 0.0,
		"embodiment": 0.8,
		"ai_assistance": false
	},
	CCC_Preset.RACING_GAME: {
		"name": "Racing Game Style",
		"control": CCC_ControlManager.ControlType.DIRECT,
		"character": CCC_CharacterManager.CharacterType.AVATAR,
		"camera": CCC_CameraManager.CameraType.FOLLOWING,
		"responsiveness": 1.0,
		"sensitivity": 0.8,
		"embodiment": 0.7,
		"ai_assistance": true
	}
}

signal configuration_changed(config: Dictionary)

func set_current_preset(preset: CCC_Preset):
	current_preset = preset
	if preset != CCC_Preset.CUSTOM:
		apply_preset_configuration(preset)

func apply_preset_configuration(preset: CCC_Preset):
	if not preset_configs.has(preset):
		return
	
	var config = preset_configs[preset]
	control_type = config.control
	character_type = config.character
	camera_type = config.camera
	movement_responsiveness = config.responsiveness
	camera_sensitivity = config.sensitivity
	embodiment_quality = config.embodiment
	enable_ai_assistance = config.ai_assistance
	
	emit_configuration_changed()

func get_current_configuration() -> Dictionary:
	return {
		"control": control_type,
		"character": character_type,
		"camera": camera_type,
		"responsiveness": movement_responsiveness,
		"sensitivity": camera_sensitivity,
		"embodiment": embodiment_quality,
		"ai_assistance": enable_ai_assistance
	}

func emit_configuration_changed():
	configuration_changed.emit(get_current_configuration())
