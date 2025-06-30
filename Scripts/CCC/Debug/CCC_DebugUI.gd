# 3CDebugUI.gd - Debug UI for 3C Framework
extends Control
class_name CCC_ThreeCDebugUI

# === EXPORTS ===
@export_group("Required References")
@export var character_controller: Node3D  # Root CharacterController node
@export var config_component: Node  # 3CConfigComponent

@export_group("UI Properties")
@export var update_frequency: float = 10.0  # Updates per second
@export var show_performance_info: bool = true
@export var enable_preset_buttons: bool = true

# === UI NODES ===
@onready var debug_label: Label = $DebugLabel
@onready var preset_container: VBoxContainer = $PresetContainer
@onready var parameter_container: VBoxContainer = $ParameterContainer

# === DEBUG STATE ===
var update_timer: float = 0.0
var component_cache: Dictionary = {}
var last_fps: float = 0.0

func _ready():
	setup_debug_ui()
	cache_components()
	
	if enable_preset_buttons:
		create_preset_buttons()

func setup_debug_ui():
	"""Setup debug UI layout"""
	# Create main containers if they don't exist
	if not debug_label:
		debug_label = Label.new()
		debug_label.name = "DebugLabel"
		debug_label.anchor_left = 0.0
		debug_label.anchor_top = 0.0
		debug_label.anchor_right = 1.0
		debug_label.anchor_bottom = 0.5
		debug_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		add_child(debug_label)
	
	if not preset_container:
		preset_container = VBoxContainer.new()
		preset_container.name = "PresetContainer"
		preset_container.anchor_left = 0.0
		preset_container.anchor_top = 0.5
		preset_container.anchor_right = 0.3
		preset_container.anchor_bottom = 1.0
		add_child(preset_container)
	
	if not parameter_container:
		parameter_container = VBoxContainer.new()
		parameter_container.name = "ParameterContainer"
		parameter_container.anchor_left = 0.3
		parameter_container.anchor_top = 0.5
		parameter_container.anchor_right = 1.0
		parameter_container.anchor_bottom = 1.0
		add_child(parameter_container)
	
	# Style debug label
	if debug_label:
		debug_label.add_theme_color_override("font_color", Color.WHITE)
		debug_label.add_theme_color_override("font_shadow_color", Color.BLACK)

func cache_components():
	"""Cache component references for faster access"""
	component_cache.clear()
	
	# Only use manually assigned references
	if character_controller:
		# Cache specific components you know exist
		# Let the debug display handle missing components gracefully
		pass

func _process(delta):
	"""Update debug display"""
	update_timer += delta
	
	if update_timer >= (1.0 / update_frequency):
		update_debug_display()
		update_timer = 0.0



# === DEBUG DISPLAY ===

func update_debug_display():
	"""Update the debug information display"""
	if not debug_label:
		return
	
	var debug_text = build_debug_text()
	debug_label.text = debug_text

func build_debug_text() -> String:
	"""Build complete debug text"""
	var text = "=== 3C FRAMEWORK DEBUG ===\n\n"
	
	# Performance info
	if show_performance_info:
		text += build_performance_section()
	
	# Configuration info
	text += build_configuration_section()
	
	# Component info
	text += build_component_sections()
	
	return text

func build_performance_section() -> String:
	"""Build performance information section"""
	var text = "=== PERFORMANCE ===\n"
	
	var fps = Engine.get_frames_per_second()
	last_fps = fps
	
	text += "FPS: " + str(fps) + "\n"
	text += "Frame Time: " + str(1000.0 / fps).pad_decimals(2) + "ms\n"
	text += "Memory: " + str(OS.get_static_memory_usage() / 1024 / 1024) + "MB\n"
	text += "\n"
	
	return text

func build_configuration_section() -> String:
	"""Build configuration information section"""
	var text = "=== CONFIGURATION ===\n"
	
	if config_component and config_component.has_method("get_debug_info"):
		var config_info = config_component.get_debug_info()
		text += "Active Config: " + str(config_info.get("active_config_name", "None")) + "\n"
		text += "Config Valid: " + str(config_info.get("config_valid", false)) + "\n"
		
		if config_component.has_method("get_active_config"):
			var config = config_component.get_active_config()
			if config:
				text += "Character Type: " + str(config.character_type) + "\n"
				text += "Camera Type: " + str(config.camera_type) + "\n"
				text += "Control Type: " + str(config.control_type) + "\n"
	
	text += "\n"
	return text

func build_component_sections() -> String:
	"""Build all component debug sections"""
	var text = ""
	
	# Character components
	text += build_character_section()
	
	# Camera components
	text += build_camera_section()
	
	# Control components
	text += build_control_section()
	
	# Animation components
	text += build_animation_section()
	
	return text

func build_character_section() -> String:
	"""Build character components debug section"""
	var text = "=== CHARACTER ===\n"
	
	# CharacterCore
	if "CharacterCore" in component_cache:
		var core = component_cache["CharacterCore"]
		if core.has_method("get_debug_info"):
			var info = core.get_debug_info()
			text += "Position: " + str(info.get("position", Vector3.ZERO)) + "\n"
			text += "Velocity: " + str(info.get("velocity", Vector3.ZERO)) + "\n"
			text += "Speed: " + str(info.get("speed", 0.0)).pad_decimals(2) + "\n"
			text += "Grounded: " + str(info.get("grounded", false)) + "\n"
	
	# AvatarComponent
	if "AvatarComponent" in component_cache:
		var avatar = component_cache["AvatarComponent"]
		if avatar.has_method("get_debug_info"):
			var info = avatar.get_debug_info()
			text += "State: " + str(info.get("current_state", "unknown")) + "\n"
			text += "Movement Mode: " + str(info.get("movement_mode", "unknown")) + "\n"
	
	text += "\n"
	return text

func build_camera_section() -> String:
	"""Build camera components debug section"""
	var text = "=== CAMERA ===\n"
	
	# CameraCore
	if "CameraCore" in component_cache:
		var core = component_cache["CameraCore"]
		if core.has_method("get_debug_info"):
			var info = core.get_debug_info()
			text += "FOV: " + str(info.get("fov", 0.0)).pad_decimals(1) + "\n"
			text += "Position: " + str(info.get("position", Vector3.ZERO)) + "\n"
	
	# OrbitalCameraComponent
	if "OrbitalCameraComponent" in component_cache:
		var orbital = component_cache["OrbitalCameraComponent"]
		if orbital.has_method("get_debug_info"):
			var info = orbital.get_debug_info()
			text += "Pitch: " + str(info.get("pitch_deg", 0.0)).pad_decimals(1) + "°\n"
			text += "Yaw: " + str(info.get("yaw_deg", 0.0)).pad_decimals(1) + "°\n"
			text += "Mouse Captured: " + str(info.get("mouse_captured", false)) + "\n"
	
	# CameraDistanceComponent
	if "CameraDistanceComponent" in component_cache:
		var distance = component_cache["CameraDistanceComponent"]
		if distance.has_method("get_debug_info"):
			var info = distance.get_debug_info()
			text += "Distance: " + str(info.get("current_distance", 0.0)).pad_decimals(2) + "\n"
			text += "Target Distance: " + str(info.get("target_distance", 0.0)).pad_decimals(2) + "\n"
	
	text += "\n"
	return text

func build_control_section() -> String:
	"""Build control components debug section"""
	var text = "=== CONTROL ===\n"
	
	# InputManagerComponent
	if "InputManagerComponent" in component_cache:
		var input_mgr = component_cache["InputManagerComponent"]
		if input_mgr.has_method("get_debug_info"):
			var info = input_mgr.get_debug_info()
			text += "Input Mode: " + str(info.get("current_mode", "unknown")) + "\n"
			text += "Input Enabled: " + str(info.get("input_enabled", false)) + "\n"
	
	# DirectControlComponent
	if "DirectControlComponent" in component_cache:
		var direct = component_cache["DirectControlComponent"]
		if direct.has_method("get_debug_info"):
			var info = direct.get_debug_info()
			text += "Current Input: " + str(info.get("current_input", Vector2.ZERO)) + "\n"
			text += "Sprint Active: " + str(info.get("sprint_active", false)) + "\n"
	
	text += "\n"
	return text

func build_animation_section() -> String:
	"""Build animation components debug section"""
	var text = "=== ANIMATION ===\n"
	
	if "AnimationManagerComponent" in component_cache:
		var anim = component_cache["AnimationManagerComponent"]
		if anim.has_method("get_debug_info"):
			var info = anim.get_debug_info()
			text += "Current State: " + str(info.get("current_state", "unknown")) + "\n"
			text += "Movement Speed: " + str(info.get("movement_speed", 0.0)).pad_decimals(2) + "\n"
			text += "Blend Position: " + str(info.get("blend_position", 0.0)).pad_decimals(2) + "\n"
	
	text += "\n"
	return text

# === PRESET BUTTONS ===

func create_preset_buttons():
	"""Create preset configuration buttons"""
	if not preset_container or not config_component:
		return
	
	# Clear existing buttons
	for child in preset_container.get_children():
		child.queue_free()
	
	# Add title
	var title = Label.new()
	title.text = "3C PRESETS"
	title.add_theme_color_override("font_color", Color.YELLOW)
	preset_container.add_child(title)
	
	# Get available presets
	var presets = []
	if config_component.has_method("get_available_presets"):
		presets = config_component.get_available_presets()
	else:
		presets = ["action_adventure", "fps", "rts", "platformer"]
	
	# Create buttons for each preset
	for preset_name in presets:
		var button = Button.new()
		button.text = preset_name.capitalize()
		button.pressed.connect(_on_preset_button_pressed.bind(preset_name))
		preset_container.add_child(button)

func _on_preset_button_pressed(preset_name: String):
	"""Handle preset button press"""
	if config_component and config_component.has_method("load_preset"):
		config_component.load_preset(preset_name)
		print("3CDebugUI: Loaded preset - ", preset_name)

# === PUBLIC API ===

func refresh_component_cache():
	"""Refresh the component cache"""
	cache_components()

func set_update_frequency(frequency: float):
	"""Set debug update frequency"""
	update_frequency = clamp(frequency, 1.0, 60.0)

func toggle_performance_info():
	"""Toggle performance information display"""
	show_performance_info = not show_performance_info

# === CONFIGURATION ===

func configure_from_3c(config: CharacterConfig):
	"""Configure debug UI from 3C config (if needed)"""
	# Debug UI doesn't need configuration, but method exists for consistency
	pass
