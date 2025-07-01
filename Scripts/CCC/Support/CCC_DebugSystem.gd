class_name CCC_DebugSystem
extends Node

@export_group("Debug Settings")
@export var enable_debug: bool = true
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
@export var ui_manager: CCC_UIManager

var debug_timer: float = 0.0
var debug_data: Dictionary = {}
var debug_history: Array = []

signal debug_command_executed(command: String, result: String)
signal debug_data_updated(data: Dictionary)

func _ready():
	if enable_debug:
		setup_debug_commands()
		connect_signals()

func connect_signals():
	if ui_manager:
		debug_data_updated.connect(ui_manager._on_debug_data_updated)

func _process(delta):
	if not enable_debug:
		return
	
	debug_timer += delta
	
	if debug_timer >= debug_update_interval:
		update_debug_data()
		debug_data_updated.emit(debug_data)
		debug_timer = 0.0

func _input(event):
	if not enable_debug:
		return
	
	if event.is_action_pressed("debug_toggle"):
		toggle_debug_display()
	elif event.is_action_pressed("debug_reset"):
		reset_debug_data()
	elif event.is_action_pressed("debug_capture"):
		capture_debug_snapshot()

func toggle_debug_display():
	if ui_manager:
		ui_manager.toggle_debug_overlay()

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
	debug_data["memory_usage"] = OS.get_static_memory_usage()

func reset_debug_data():
	debug_data.clear()
	debug_history.clear()

func capture_debug_snapshot():
	var snapshot = debug_data.duplicate(true)
	snapshot["timestamp"] = Time.get_ticks_msec() / 1000.0
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
		"debug_data_count": debug_data.size(),
		"debug_history_count": debug_history.size(),
		"debug_update_interval": debug_update_interval
	}

func get_current_debug_data() -> Dictionary:
	return debug_data.duplicate()
