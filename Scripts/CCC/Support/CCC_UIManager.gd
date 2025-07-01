class_name CCC_UIManager
extends Node

@export_group("UI Components")
@export var main_canvas: CanvasLayer
@export var hud_container: Control
@export var menu_container: Control
@export var settings_container: Control

@export_group("3C Integration")
@export var character_controller: CCC_CharacterController
@export var camera_controller: CCC_CameraController
@export var input_manager: CCC_InputManager
@export var animation_manager: CCC_AnimationManager
@export var debug_system: CCC_DebugSystem

@export_group("UI Settings")
@export var auto_hide_cursor: bool = true
@export var ui_scale: float = 1.0
@export var show_fps: bool = false
@export var show_debug_overlay: bool = false

var ui_elements: Dictionary = {}
var active_menu: String = ""
var ui_visible: bool = true
var crosshair: Control
var health_bar: ProgressBar
var status_labels: Dictionary = {}
var debug_overlay: Control
var debug_label: RichTextLabel

signal ui_element_created(element_name: String)
signal menu_opened(menu_name: String)
signal menu_closed(menu_name: String)
signal ui_interaction(element_name: String, action: String)

func _ready():
	setup_ui_system()
	create_core_ui_elements()
	connect_signals()

func _input(event):
	handle_ui_input(event)

func setup_ui_system():
	# Create main canvas if not assigned
	if not main_canvas:
		main_canvas = CanvasLayer.new()
		main_canvas.layer = 100
		add_child(main_canvas)
	
	# Create UI containers
	if not hud_container:
		hud_container = Control.new()
		hud_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hud_container.name = "HUD"
		main_canvas.add_child(hud_container)
	
	if not menu_container:
		menu_container = Control.new()
		menu_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		menu_container.name = "Menus"
		menu_container.visible = false
		main_canvas.add_child(menu_container)

func create_core_ui_elements():
	create_crosshair()
	create_health_bar()
	create_status_display()
	create_debug_overlay()
	
	if show_fps:
		create_fps_counter()

func create_debug_overlay():
	# Create debug overlay
	debug_overlay = Control.new()
	debug_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	debug_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debug_overlay.visible = show_debug_overlay
	debug_overlay.name = "DebugOverlay"
	
	# Create debug label
	debug_label = RichTextLabel.new()
	debug_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	debug_label.size = Vector2(400, 600)
	debug_label.bbcode_enabled = true
	debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debug_label.add_theme_color_override("default_color", Color.WHITE)
	debug_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	debug_label.name = "DebugLabel"
	
	debug_overlay.add_child(debug_label)
	hud_container.add_child(debug_overlay)
	
	ui_elements["debug_overlay"] = debug_overlay
	ui_elements["debug_label"] = debug_label
	ui_element_created.emit("debug_overlay")

func create_crosshair():
	crosshair = Control.new()
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.size = Vector2(20, 20)
	crosshair.position -= crosshair.size / 2
	
	var crosshair_texture = TextureRect.new()
	crosshair_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crosshair_texture.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	
	crosshair.add_child(crosshair_texture)
	hud_container.add_child(crosshair)
	
	ui_elements["crosshair"] = crosshair
	ui_element_created.emit("crosshair")

func create_health_bar():
	health_bar = ProgressBar.new()
	health_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	health_bar.position = Vector2(20, 20)
	health_bar.size = Vector2(200, 20)
	health_bar.value = 100
	health_bar.max_value = 100
	
	hud_container.add_child(health_bar)
	ui_elements["health_bar"] = health_bar
	ui_element_created.emit("health_bar")

func create_status_display():
	var status_panel = VBoxContainer.new()
	status_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	status_panel.position = Vector2(-220, 20)
	status_panel.size = Vector2(200, 100)
	
	# Character state label
	var state_label = Label.new()
	state_label.text = "State: IDLE"
	state_label.add_theme_color_override("font_color", Color.WHITE)
	status_panel.add_child(state_label)
	status_labels["state"] = state_label
	
	# Speed label
	var speed_label = Label.new()
	speed_label.text = "Speed: 0.0"
	speed_label.add_theme_color_override("font_color", Color.WHITE)
	status_panel.add_child(speed_label)
	status_labels["speed"] = speed_label
	
	# Camera mode label
	var camera_label = Label.new()
	camera_label.text = "Camera: Follow"
	camera_label.add_theme_color_override("font_color", Color.WHITE)
	status_panel.add_child(camera_label)
	status_labels["camera"] = camera_label
	
	hud_container.add_child(status_panel)
	ui_elements["status_panel"] = status_panel

func create_fps_counter():
	var fps_label = Label.new()
	fps_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	fps_label.position = Vector2(-100, -30)
	fps_label.text = "FPS: 60"
	fps_label.add_theme_color_override("font_color", Color.YELLOW)
	
	hud_container.add_child(fps_label)
	ui_elements["fps_counter"] = fps_label

func connect_signals():
	if character_controller:
		character_controller.state_changed.connect(_on_character_state_changed)
		character_controller.movement_changed.connect(_on_movement_changed)
	
	if camera_controller:
		if camera_controller.has_signal("camera_mode_changed"):
			camera_controller.camera_mode_changed.connect(_on_camera_mode_changed)
	
	if input_manager:
		input_manager.input_source_changed.connect(_on_input_source_changed)
	
	if debug_system:
		debug_system.debug_data_updated.connect(_on_debug_data_updated)

func _process(delta):
	update_ui_elements()

func update_ui_elements():
	# Update FPS counter
	if ui_elements.has("fps_counter"):
		ui_elements["fps_counter"].text = "FPS: " + str(Engine.get_frames_per_second())
	
	# Update status labels
	if character_controller and status_labels.has("state"):
		status_labels["state"].text = "State: " + character_controller.get_current_state()
	
	if character_controller and status_labels.has("speed"):
		status_labels["speed"].text = "Speed: " + str("%.1f" % character_controller.get_movement_speed())
	
	if camera_controller and status_labels.has("camera"):
		var camera_mode = camera_controller.get_mode_name(camera_controller.get_current_mode())
		status_labels["camera"].text = "Camera: " + camera_mode

func handle_ui_input(event):
	if event.is_action_pressed("ui_menu"):
		toggle_menu("main")
	elif event.is_action_pressed("ui_settings"):
		toggle_menu("settings")
	elif event.is_action_pressed("ui_hide"):
		toggle_ui_visibility()

func _on_character_state_changed(new_state: String):
	# Update UI based on character state
	if new_state == "FALLING":
		# Could show warning UI
		pass
	elif new_state == "LANDING":
		# Could show impact effect
		pass

func _on_movement_changed(velocity: Vector3):
	# Update movement-related UI elements
	pass

func _on_camera_mode_changed(new_mode: int):
	# Update camera-related UI elements
	update_crosshair_visibility(new_mode)

func _on_input_source_changed(source: String):
	# Update UI based on input source
	if source == "click_navigation":
		show_navigation_cursor()
	else:
		hide_navigation_cursor()

func _on_debug_data_updated(data: Dictionary):
	if not debug_label or not show_debug_overlay:
		return
	
	var debug_text = "[font_size=12][color=yellow]3C Framework Debug[/color][/font_size]\n"
	debug_text += "[font_size=10]FPS: " + str(data.get("fps", 0)) + "\n"
	debug_text += "Frame Time: " + str("%.2f" % data.get("frame_time", 0.0)) + "ms\n\n"
	
	# Character System
	debug_text += "[color=cyan]CHARACTER SYSTEM[/color]\n"
	debug_text += "State: " + str(data.get("state_current", "unknown")) + "\n"
	debug_text += "Speed: " + str("%.2f" % data.get("speed", 0.0)) + "\n"
	debug_text += "On Floor: " + str(data.get("on_floor", false)) + "\n"
	debug_text += "Velocity: " + str(data.get("velocity", Vector3.ZERO)) + "\n\n"
	
	# Input System
	debug_text += "[color=green]INPUT SYSTEM[/color]\n"
	debug_text += "Active: " + str(data.get("input_movement_active", false)) + "\n"
	debug_text += "Input: " + str(data.get("input_current_input", Vector2.ZERO)) + "\n"
	debug_text += "WASD Override: " + str(data.get("input_wasd_overriding", false)) + "\n\n"
	
	# Camera System
	debug_text += "[color=magenta]CAMERA SYSTEM[/color]\n"
	debug_text += "Mode: " + str(data.get("camera_modes_current", "unknown")) + "\n"
	debug_text += "Position: " + str(data.get("camera_position", Vector3.ZERO)) + "\n\n"
	
	# Animation System
	if animation_manager:
		debug_text += "[color=orange]ANIMATION SYSTEM[/color]\n"
		debug_text += "State: " + str(data.get("animation_current_state", "unknown")) + "\n"
		debug_text += "Tree Active: " + str(data.get("animation_tree_active", false)) + "\n\n"
	
	debug_label.text = debug_text

func toggle_debug_overlay():
	show_debug_overlay = !show_debug_overlay
	if debug_overlay:
		debug_overlay.visible = show_debug_overlay

func update_crosshair_visibility(camera_mode: int):
	if crosshair:
		# Hide crosshair in certain camera modes
		crosshair.visible = camera_mode != 1  # Hide in orbit mode

func show_navigation_cursor():
	# Show special cursor for click navigation
	if crosshair:
		crosshair.modulate = Color.GREEN

func hide_navigation_cursor():
	# Return to normal cursor
	if crosshair:
		crosshair.modulate = Color.WHITE

func toggle_menu(menu_name: String):
	if active_menu == menu_name:
		close_menu()
	else:
		open_menu(menu_name)

func open_menu(menu_name: String):
	close_menu()  # Close any existing menu
	
	active_menu = menu_name
	menu_container.visible = true
	
	# Pause game or change input mode
	if input_manager:
		# Could disable character input while menu is open
		pass
	
	menu_opened.emit(menu_name)

func close_menu():
	if active_menu.is_empty():
		return
	
	var closed_menu = active_menu
	active_menu = ""
	menu_container.visible = false
	
	# Resume game
	if input_manager:
		# Re-enable character input
		pass
	
	menu_closed.emit(closed_menu)

func toggle_ui_visibility():
	ui_visible = !ui_visible
	hud_container.visible = ui_visible

func set_health(value: float, max_value: float = 100.0):
	if health_bar:
		health_bar.value = value
		health_bar.max_value = max_value

func show_ui_element(element_name: String, visible: bool = true):
	if ui_elements.has(element_name):
		ui_elements[element_name].visible = visible

func get_ui_element(element_name: String) -> Control:
	return ui_elements.get(element_name, null)

func create_custom_ui_element(element_name: String, element: Control, parent: Control = null):
	if not parent:
		parent = hud_container
	
	parent.add_child(element)
	ui_elements[element_name] = element
	ui_element_created.emit(element_name)

func get_debug_info() -> Dictionary:
	return {
		"ui_visible": ui_visible,
		"ui_active_menu": active_menu,
		"ui_elements_count": ui_elements.size(),
		"ui_scale": ui_scale,
		"ui_auto_hide_cursor": auto_hide_cursor,
		"ui_debug_overlay_visible": show_debug_overlay
	}
