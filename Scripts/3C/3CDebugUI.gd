# 3CDebugUI.gd - Simple 3C Testing Interface
extends Control

@export var character_controller: CharacterBody3D
@export var show_advanced_controls: bool = false

# UI Components
var info_label: Label
var preset_buttons_container: VBoxContainer

func _ready():
	if not character_controller:
		character_controller = get_node("../CHARACTER")
		if not character_controller:
			push_error("3CDebugUI: No character controller found!")
			return
	
	setup_ui()
	update_info_display()

func setup_ui():
	"""Create the debug UI interface"""
	# Main container
	var main_vbox = VBoxContainer.new()
	add_child(main_vbox)
	
	# Title
	var title = Label.new()
	title.text = "3C Framework Debug Interface"
	title.add_theme_font_size_override("font_size", 20)
	main_vbox.add_child(title)
	
	# Current config info
	info_label = Label.new()
	info_label.text = "Loading..."
	main_vbox.add_child(info_label)
	
	# Preset selection
	create_preset_section(main_vbox)
	
	# Update display
	call_deferred("update_info_display")

func create_preset_section(parent: Control):
	"""Create preset selection buttons"""
	var section = VBoxContainer.new()
	parent.add_child(section)
	
	var header = Label.new()
	header.text = "3C Presets:"
	header.add_theme_font_size_override("font_size", 16)
	section.add_child(header)
	
	# Preset buttons container
	preset_buttons_container = VBoxContainer.new()
	section.add_child(preset_buttons_container)
	
	# Create buttons for each preset
	create_preset_buttons()

func create_preset_buttons():
	"""Create buttons for all available presets"""
	# Clear existing buttons
	for child in preset_buttons_container.get_children():
		child.queue_free()
	
	# Get available presets using TCPresets
	var presets = TCPresets.get_all_presets()
	
	# Create button for each preset
	for preset in presets:
		var button = Button.new()
		button.text = preset.config_name
		button.pressed.connect(func(): switch_to_preset(preset))
		
		# Highlight current preset
		if character_controller.active_3c_config and preset.config_name == character_controller.active_3c_config.config_name:
			button.modulate = Color.LIGHT_GREEN
		
		preset_buttons_container.add_child(button)

func switch_to_preset(preset: CharacterConfig):
	"""Switch to the selected preset"""
	if character_controller.has_method("switch_3c_config"):
		character_controller.switch_3c_config(preset)
		update_info_display()
		
		# Update button highlights
		for button in preset_buttons_container.get_children():
			if button.text == preset.config_name:
				button.modulate = Color.LIGHT_GREEN
			else:
				button.modulate = Color.WHITE

func update_info_display():
	"""Update the info label with current 3C status"""
	if not character_controller or not info_label:
		return
	
	var info_text = "Current 3C Configuration:\n"
	
	if character_controller.has_method("get_current_3c_info"):
		var info = character_controller.get_current_3c_info()
		for key in info:
			info_text += key + ": " + str(info[key]) + "\n"
	else:
		info_text += "3C system not fully integrated yet\n"
	
	info_label.text = info_text

func _input(event):
	"""Handle keyboard shortcuts for quick testing"""
	if not character_controller:
		return
	
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				switch_to_preset(TCPresets.get_botw_config())
			KEY_2:
				switch_to_preset(TCPresets.get_diablo_config())
			KEY_3:
				switch_to_preset(TCPresets.get_dark_souls_config())
			KEY_4:
				switch_to_preset(TCPresets.get_fps_config())
			KEY_5:
				switch_to_preset(TCPresets.get_rts_config())
			KEY_6:
				switch_to_preset(TCPresets.get_puzzle_config())
			KEY_P:
				update_info_display()
				print("🎮 3C Status updated")
			KEY_T:
				test_all_presets()

func test_all_presets():
	"""Test cycling through presets"""
	if not character_controller.has_method("switch_3c_config"):
		print("❌ Character controller doesn't have 3C methods yet")
		return
	
	print("🧪 Testing 3C presets...")
	var presets = [
		TCPresets.get_botw_config(),
		TCPresets.get_diablo_config(),
		TCPresets.get_dark_souls_config()
	]
	
	for preset in presets:
		print("🧪 Switching to: ", preset.config_name)
		switch_to_preset(preset)
		await get_tree().create_timer(2.0).timeout
	
	print("🧪 Test complete")
