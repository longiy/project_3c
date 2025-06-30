# Debug3CUI.gd - 3C Framework Testing and Debug Interface
extends Control
class_name Debug3CUI

# === REFERENCES ===
@export var character_controller: Character3CManager

# === UI COMPONENTS ===
var preset_container: VBoxContainer
var parameter_container: VBoxContainer
var info_container: VBoxContainer

var current_config_label: Label
var character_info_label: Label
var camera_info_label: Label
var control_info_label: Label

var parameter_sliders: Dictionary = {}

func _ready():
	if not character_controller:
		character_controller = get_node("../../CHARACTER") as Character3CManager
		if not character_controller:
			push_error("No Character3CManager found for Debug3CUI")
			return
	
	setup_ui()
	create_preset_buttons()
	create_parameter_sliders()
	create_info_displays()

func setup_ui():
	"""Setup the main UI layout"""
	# Create main container
	var main_container = VBoxContainer.new()
	add_child(main_container)
	
	# Title
	var title = Label.new()
	title.text = "3C Framework Debug Interface"
	title.add_theme_font_size_override("font_size", 18)
	main_container.add_child(title)
	
	# Create sections
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 500)
	main_container.add_child(scroll)
	
	var content = VBoxContainer.new()
	scroll.add_child(content)
	
	# Preset section
	var preset_title = Label.new()
	preset_title.text = "3C Presets"
	preset_title.add_theme_font_size_override("font_size", 14)
	content.add_child(preset_title)
	
	preset_container = VBoxContainer.new()
	content.add_child(preset_container)
	
	content.add_child(HSeparator.new())
	
	# Parameter section
	var param_title = Label.new()
	param_title.text = "Real-time Parameters"
	param_title.add_theme_font_size_override("font_size", 14)
	content.add_child(param_title)
	
	parameter_container = VBoxContainer.new()
	content.add_child(parameter_container)
	
	content.add_child(HSeparator.new())
	
	# Info section
	var info_title = Label.new()
	info_title.text = "System Information"
	info_title.add_theme_font_size_override("font_size", 14)
	content.add_child(info_title)
	
	info_container = VBoxContainer.new()
	content.add_child(info_container)

func create_preset_buttons():
	"""Create buttons for all available presets"""
	var presets = TC3Presets.get_all_presets()
	
	for preset in presets:
		var button = Button.new()
		button.text = preset.config_name
		button.pressed.connect(func(): switch_to_preset(preset))
		preset_container.add_child(button)
	
	# Add custom config button
	var custom_button = Button.new()
	custom_button.text = "Create Custom Config"
	custom_button.pressed.connect(create_custom_config)
	preset_container.add_child(custom_button)

func create_parameter_sliders():
	"""Create real-time parameter adjustment sliders"""
	# Character parameters
	add_parameter_slider("Walk Speed", "walk_speed", 0.5, 8.0, character_controller.active_3c_config.walk_speed)
	add_parameter_slider("Run Speed", "run_speed", 2.0, 15.0, character_controller.active_3c_config.run_speed)
	add_parameter_slider("Jump Height", "jump_height", 1.0, 10.0, character_controller.active_3c_config.jump_height)
	add_parameter_slider("Acceleration", "acceleration", 1.0, 30.0, character_controller.active_3c_config.acceleration)
	
	# Camera parameters
	add_parameter_slider("Camera Distance", "camera_distance", 1.0, 15.0, character_controller.active_3c_config.camera_distance)
	add_parameter_slider("Camera Height", "camera_height", 0.5, 8.0, character_controller.active_3c_config.camera_height)
	add_parameter_slider("Camera Smoothing", "camera_smoothing", 0.1, 20.0, character_controller.active_3c_config.camera_smoothing)
	add_parameter_slider("FOV", "camera_fov", 30.0, 120.0, character_controller.active_3c_config.camera_fov)
	
	# Control parameters
	add_parameter_slider("Mouse Sensitivity", "mouse_sensitivity", 0.1, 5.0, character_controller.active_3c_config.mouse_sensitivity)
	add_parameter_slider("Input Deadzone", "input_deadzone", 0.0, 0.3, character_controller.active_3c_config.input_deadzone)
	add_parameter_slider("Control Precision", "control_precision", 0.0, 1.0, character_controller.active_3c_config.control_precision)

func add_parameter_slider(label_text: String, property: String, min_val: float, max_val: float, current_val: float):
	"""Add a parameter slider to the UI"""
	var container = HBoxContainer.new()
	parameter_container.add_child(container)
	
	# Label
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 120
	container.add_child(label)
	
	# Slider
	var slider = HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.value = current_val
	slider.step = (max_val - min_val) / 100.0
	slider.custom_minimum_size.x = 150
	container.add_child(slider)
	
	# Value label
	var value_label = Label.new()
	value_label.text = str(current_val)
	value_label.custom_minimum_size.x = 50
	container.add_child(value_label)
	
	# Connect slider
	slider.value_changed.connect(func(value): update_parameter(property, value, value_label))
	
	parameter_sliders[property] = {"slider": slider, "label": value_label}

func create_info_displays():
	"""Create information display labels"""
	current_config_label = Label.new()
	current_config_label.text = "Current Config: " + character_controller.active_3c_config.config_name
	info_container.add_child(current_config_label)
	
	character_info_label = Label.new()
	info_container.add_child(character_info_label)
	
	camera_info_label = Label.new()
	info_container.add_child(camera_info_label)
	
	control_info_label = Label.new()
	info_container.add_child(control_info_label)

func _process(_delta):
	"""Update info displays every frame"""
	update_info_displays()

func switch_to_preset(preset: CharacterConfig):
	"""Switch to a preset configuration"""
	character_controller.switch_3c_config(preset)
	update_slider_values()
	current_config_label.text = "Current Config: " + preset.config_name

func update_parameter(property: String, value: float, value_label: Label):
	"""Update a parameter in real-time"""
	if character_controller.active_3c_config:
		character_controller.active_3c_config.set(property, value)
		value_label.text = "%.2f" % value
		
		# Reapply configuration to update systems
		character_controller.configure_3c_system()

func update_slider_values():
	"""Update all slider values to match current config"""
	if not character_controller.active_3c_config:
		return
	
	var config = character_controller.active_3c_config
	
	for property in parameter_sliders:
		var slider_data = parameter_sliders[property]
		var current_value = config.get(property)
		slider_data.slider.value = current_value
		slider_data.label.text = "%.2f" % current_value

func update_info_displays():
	"""Update information displays"""
	if not character_controller:
		return
	
	# Character info
	var char_info = "Character Type: %s\nMovement Mode: %s\nSpeed: %.1f" % [
		CharacterConfig.CharacterType.keys()[character_controller.active_3c_config.character_type],
		character_controller.current_movement_mode,
		character_controller.velocity.length()
	]
	character_info_label.text = char_info
	
	# Camera info
	if character_controller.camera_3c_manager:
		var cam_info = character_controller.camera_3c_manager.get_camera_info()
		camera_info_label.text = "Camera Mode: %s\nDistance: %.1f\nFOV: %.1f" % [
			cam_info.mode,
			cam_info.distance,
			cam_info.fov
		]
	
	# Control info
	if character_controller.control_3c_manager:
		var ctrl_info = character_controller.control_3c_manager.get_debug_info()
		control_info_label.text = "Control Type: %s\nInput Active: %s\nPrecision: %.2f" % [
			ctrl_info.control_type,
			str(ctrl_info.movement_active),
			ctrl_info.control_precision
		]

func create_custom_config():
	"""Create a custom configuration dialog"""
	var dialog = AcceptDialog.new()
	dialog.title = "Create Custom Config"
	dialog.size = Vector2(400, 300)
	add_child(dialog)
	
	var vbox = VBoxContainer.new()
	dialog.add_child(vbox)
	
	# Name input
	var name_label = Label.new()
	name_label.text = "Configuration Name:"
	vbox.add_child(name_label)
	
	var name_input = LineEdit.new()
	name_input.placeholder_text = "Enter config name..."
	vbox.add_child(name_input)
	
	# Base preset selection
	var base_label = Label.new()
	base_label.text = "Base Preset:"
	vbox.add_child(base_label)
	
	var base_option = OptionButton.new()
	var presets = TC3Presets.get_all_presets()
	for preset in presets:
		base_option.add_item(preset.config_name)
	vbox.add_child(base_option)
	
	# Create button
	var create_button = Button.new()
	create_button.text = "Create Custom Config"
	vbox.add_child(create_button)
	
	create_button.pressed.connect(func():
		var config_name = name_input.text
		if config_name.is_empty():
			config_name = "Custom Config"
		
		var base_preset = presets[base_option.selected]
		var custom_config = TC3Presets.create_custom_config(config_name, base_preset)
		character_controller.switch_3c_config(custom_config)
		update_slider_values()
		current_config_label.text = "Current Config: " + custom_config.config_name
		dialog.queue_free()
	)
	
	dialog.popup_centered()

# === KEYBOARD SHORTCUTS ===

func _input(event):
	"""Handle keyboard shortcuts for quick testing"""
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				switch_to_preset(TC3Presets.get_botw_config())
			KEY_2:
				switch_to_preset(TC3Presets.get_diablo_config())
			KEY_3:
				switch_to_preset(TC3Presets.get_dark_souls_config())
			KEY_4:
				switch_to_preset(TC3Presets.get_fps_config())
			KEY_5:
				switch_to_preset(TC3Presets.get_rts_config())
			KEY_6:
				switch_to_preset(TC3Presets.get_platformer_config())
			KEY_F1:
				toggle_visibility()

func toggle_visibility():
	"""Toggle debug UI visibility"""
	visible = not visible

# === SAVE/LOAD CONFIGS ===

func save_current_config():
	"""Save current configuration to file"""
	if not character_controller.active_3c_config:
		return
	
	var file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	file_dialog.add_filter("*.tres", "Godot Resource Files")
	add_child(file_dialog)
	
	file_dialog.file_selected.connect(func(path):
		ResourceSaver.save(character_controller.active_3c_config, path)
		print("Config saved to: ", path)
		file_dialog.queue_free()
	)
	
	file_dialog.popup_centered(Vector2i(800, 600))

func load_config():
	"""Load configuration from file"""
	var file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	file_dialog.add_filter("*.tres", "Godot Resource Files")
	add_child(file_dialog)
	
	file_dialog.file_selected.connect(func(path):
		var loaded_config = ResourceLoader.load(path) as CharacterConfig
		if loaded_config:
			character_controller.switch_3c_config(loaded_config)
			update_slider_values()
			current_config_label.text = "Current Config: " + loaded_config.config_name
			print("Config loaded from: ", path)
		else:
			push_error("Failed to load config from: " + path)
		file_dialog.queue_free()
	)
	
	file_dialog.popup_centered(Vector2i(800, 600))

# === PERFORMANCE TESTING ===

func start_performance_test():
	"""Start automated performance testing of different configs"""
	var test_configs = TC3Presets.get_all_presets()
	var test_duration = 5.0  # seconds per config
	
	print("Starting 3C Performance Test...")
	
	for i in range(test_configs.size()):
		var config = test_configs[i]
		print("Testing config: ", config.config_name)
		
		character_controller.switch_3c_config(config)
		update_slider_values()
		
		# Simulate movement input
		await simulate_movement_test(test_duration)
		
		# Log performance metrics
		log_performance_metrics(config)
	
	print("Performance test completed!")

func simulate_movement_test(duration: float):
	"""Simulate movement for testing"""
	var start_time = Time.get_time_dict_from_system()
	var elapsed = 0.0
	
	while elapsed < duration:
		# Simulate circular movement
		var angle = elapsed * 2.0
		var direction = Vector2(cos(angle), sin(angle))
		
		if character_controller.control_3c_manager:
			character_controller.control_3c_manager.movement_started.emit(direction, 1.0)
		
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	
	# Stop movement
	if character_controller.control_3c_manager:
		character_controller.control_3c_manager.movement_stopped.emit()

func log_performance_metrics(config: CharacterConfig):
	"""Log performance metrics for a configuration"""
	var fps = Engine.get_frames_per_second()
	var physics_time = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	var process_time = Performance.get_monitor(Performance.TIME_PROCESS)
	
	print("Config: %s | FPS: %d | Physics: %.3f | Process: %.3f" % [
		config.config_name,
		fps,
		physics_time,
		process_time
	])
