class_name CCC_DebugSystem
extends Node

@export_group("Debug Settings")
@export var enable_debug: bool = true
@export var show_debug_overlay: bool = false
@export var debug_update_interval: float = 0.1
@export var max_debug_lines: int = 20

@export_group("Visual Debug")
@export var show_velocity_vectors: bool = false
@export var show_ground_normal: bool = false
@export var show_movement_target: bool = false
@export var debug_line_width: float = 2.0

@export_group("3C System References")
@export var character_controller: CCC_CharacterController
@export var character_state: CCC_CharacterState
@export var character_movement: CCC_CharacterMovement
@export var character_physics: CCC_CharacterPhysics
@export var input_manager: CCC_InputManager
@export var camera_controller: CCC_CameraController
@export var animation_manager: CCC_AnimationManager

var debug_overlay: Control
var debug_label: RichTextLabel
var debug_timer: float = 0.0
var debug_data: Dictionary = {}
var debug_history: Array = []

signal debug_command_executed(command: String, result: String)

func _ready():
	if enable_debug:
		setup_debug_overlay()
		setup_debug_commands()

func _process(delta):
	if not enable_debug:
		return
	
	debug_timer += delta
	
	if debug_timer >= debug_update_interval:
		update_debug_data()
		update_debug_display()
		debug_timer = 0.0

func _input(event):
	if not enable_debug:
		return
	
	if event.is_action_pressed("debug_toggle"):
		toggle_debug_overlay()
	elif event.is_action_pressed("debug_reset"):
		reset_debug_data()
	elif event.is_action_pressed("debug_capture"):
		capture_debug_snapshot()

func setup_debug_overlay():
	# Create debug overlay UI
	debug_overlay = Control.new()
	debug_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	debug_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debug_overlay.visible = show_debug_overlay
	
	# Create debug label
	debug_label = RichTextLabel.new()
	debug_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	debug_label.size = Vector2(400, 600)
	debug_label.bbcode_enabled = true
	debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debug_label.add_theme_color_override("default_color", Color.WHITE)
	debug_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	
	debug_overlay.add_child(debug_label)
	get_tree().root.add_child(debug_overlay)

func setup_debug_commands():
	# Register debug commands
	register_debug_command("reset_character", reset_character_debug)
	register_debug_command("toggle_physics", toggle_physics_debug)
	register_debug_command("set_speed", set_speed_debug)

func update_debug_data():
	debug_data.clear()
	
	# Collect data from all 3C systems
	if character_controller:
		debug_data.merge(character_controller.get_debug_info())
	
	if character_state:
		debug_data.merge(character_state.get_debug_info())
	
	if character_movement:
		debug_data.merge(character_movement.get_debug_info())
	
	if character_physics:
		debug_data.merge(character_physics.get_debug_info())
	
	if input_manager:
		debug_data.merge(input_manager.get_debug_info())
	
	if camera_controller:
		debug_data.merge(camera_controller.get_debug_info())
	
	if animation_manager:
		debug_data.merge(animation_manager.get_debug_info())
	
	# Add system performance data
	debug_data["fps"] = Engine.get_frames_per_second()
	debug_data["frame_time"] = 1.0 / Engine.get_frames_per_second() if Engine.get_frames_per_second() > 0 else 0.0
	debug_data["memory_usage"] = OS.get_static_memory_usage(true)

func update_debug_display():
	if not debug_overlay or not debug_label:
		return
	
	var debug_text = "[font_size=12][color=yellow]3C Framework Debug[/color][/font_size]\n"
	debug_text += "[font_size=10]FPS: " + str(debug_data.get("fps", 0)) + "\n"
	debug_text += "Frame Time: " + str("%.2f" % debug_data.get("frame_time", 0.0)) + "ms\n\n"
	
	# Character System
	debug_text += "[color=cyan]CHARACTER SYSTEM[/color]\n"
	debug_text += "State: " + str(debug_data.get("state_current", "unknown")) + "\n"
	debug_text += "Speed: " + str("%.2f" % debug_data.get("speed", 0.0)) + "\n"
	debug_text += "On Floor: " + str(debug_data.get("on_floor", false)) + "\n"
	debug_text += "Velocity: " + str(debug_data.get("velocity", Vector3.ZERO)) + "\n\n"
	
	# Input System
	debug_text += "[color=green]INPUT SYSTEM[/color]\n"
	debug_text += "Active: " + str(debug_data.get("input_movement_active", false)) + "\n"
	debug_text += "Input: " + str(debug_data.get("input_current_input", Vector2.ZERO)) + "\n"
	debug_text += "WASD Override: " + str(debug_data.get("input_wasd_overriding", false)) + "\n\n"
	
	# Camera System
	debug_text += "[color=magenta]CAMERA SYSTEM[/color]\n"
	debug_text += "Mode: " + str(debug_data.get("camera_modes_current", "unknown")) + "\n"
	debug_text += "Position: " + str(debug_data.get("camera_position", Vector3.ZERO)) + "\n\n"
	
	# Animation System
	if animation_manager:
		debug_text += "[color=orange]ANIMATION SYSTEM[/color]\n"
		debug_text += "State: " + str(debug_data.get("animation_current_state", "unknown")) + "\n"
		debug_text += "Tree Active: " + str(debug_data.get("animation_tree_active", false)) + "\n\n"
	
	debug_label.text = debug_text

func toggle_debug_overlay():
	if debug_overlay:
		show_debug_overlay = !show_debug_overlay
		debug_overlay.visible = show_debug_overlay

func reset_debug_data():
	debug_data.clear()
	debug_history.clear()

func capture_debug_snapshot():
	var snapshot = debug_data.duplicate(true)
	snapshot["timestamp"] = Time.get_time()
	debug_history.append(snapshot)
	
	# Limit history size
	while debug_history.size() > max_debug_lines:
		debug_history.pop_front()

func register_debug_command(command_name: String, callback: Callable):
	# Store debug commands for console system
	pass

func execute_debug_command(command: String, args: Array = []):
	match command:
		"reset_character":
			reset_character_debug()
		"toggle_physics":
			toggle_physics_debug()
		"set_speed":
			if args.size() > 0:
				set_speed_debug(args[0])
		_:
			debug_command_executed.emit(command, "Unknown command")

func reset_character_debug():
	if character_controller:
		character_controller.global_position = Vector3.ZERO
		character_controller.velocity = Vector3.ZERO
	debug_command_executed.emit("reset_character", "Character reset to origin")

func toggle_physics_debug():
	if character_physics:
		# Toggle physics debug visualization
		pass
	debug_command_executed.emit("toggle_physics", "Physics debug toggled")

func set_speed_debug(speed: float):
	if character_movement:
		character_movement.walk_speed = speed
	debug_command_executed.emit("set_speed", "Speed set to " + str(speed))

func draw_debug_vector(from: Vector3, to: Vector3, color: Color = Color.RED):
	# 3D debug line drawing would go here
	# This requires integration with Godot's debug drawing system
	pass

func log_debug_message(message: String, category: String = "DEBUG"):
	var timestamp = Time.get_datetime_string_from_system()
	var log_entry = "[" + timestamp + "] [" + category + "] " + message
	print(log_entry)

func get_debug_info() -> Dictionary:
	return {
		"debug_enabled": enable_debug,
		"debug_overlay_visible": show_debug_overlay,
		"debug_data_count": debug_data.size(),
		"debug_history_count": debug_history.size(),
		"debug_update_interval": debug_update_interval
	}