# InputController.gd - Main Coordinator for all input systems
extends Node
class_name InputController

# === SIGNALS ===
signal movement_started(direction: Vector2, magnitude: float)
signal movement_updated(direction: Vector2, magnitude: float)
signal movement_stopped()
signal jump_pressed()
signal sprint_started()
signal sprint_stopped()
signal slow_walk_started()
signal slow_walk_stopped()
signal reset_pressed()

# === SETTINGS ===
@export_group("Input Configuration")
@export var movement_update_frequency = 60
@export var input_deadzone = 0.05

# === COMPONENT REFERENCES ===
var character: CharacterBody3D
var camera_rig: CameraController

# Core modules
var raw_input_processor: RawInputProcessor
var priority_manager: InputPriorityManager

# State tracking
var movement_active = false
var last_movement_input = Vector2.ZERO
var movement_start_time = 0.0

func _ready():
	setup_character_reference()
	setup_core_modules()
	setup_camera_reference()
	connect_module_signals()

func setup_character_reference():
	"""Get character reference"""
	character = get_parent() as CharacterBody3D
	if not character:
		push_error("InputController must be child of CharacterBody3D")
		return

func setup_core_modules():
	"""Create and setup core input modules"""
	# Create raw input processor
	raw_input_processor = RawInputProcessor.new()
	raw_input_processor.name = "RawInputProcessor"
	raw_input_processor.input_deadzone = input_deadzone
	add_child(raw_input_processor)
	
	# Create priority manager
	priority_manager = InputPriorityManager.new()
	priority_manager.name = "InputPriorityManager"
	priority_manager.movement_update_frequency = movement_update_frequency
	add_child(priority_manager)
	
	# Setup module references
	priority_manager.setup_character_reference(character)

func setup_camera_reference():
	"""Find and setup camera reference"""
	camera_rig = get_node_or_null("../../CAMERARIG") as CameraController
	if not camera_rig:
		push_warning("No CameraController found - some input features may not work")
	else:
		priority_manager.setup_camera_reference(camera_rig)

func connect_module_signals():
	"""Connect signals between modules and to external systems"""
	# Connect raw input to priority manager
	raw_input_processor.discrete_action.connect(_on_discrete_action)
	raw_input_processor.click_navigation_event.connect(priority_manager._on_click_navigation_event)
	
	# Connect priority manager to our signals
	priority_manager.movement_started.connect(_on_movement_started)
	priority_manager.movement_updated.connect(_on_movement_updated)
	priority_manager.movement_stopped.connect(_on_movement_stopped)

# === SIGNAL HANDLERS ===

func _on_discrete_action(action_name: String):
	"""Handle discrete actions from raw input processor"""
	match action_name:
		"jump":
			jump_pressed.emit()
		"reset":
			reset_pressed.emit()
		"sprint_start":
			sprint_started.emit()
		"sprint_end":
			sprint_stopped.emit()
		"slow_walk_start":
			slow_walk_started.emit()
		"slow_walk_end":
			slow_walk_stopped.emit()

func _on_movement_started(direction: Vector2, magnitude: float):
	"""Handle movement start from priority manager"""
	movement_active = true
	movement_start_time = Time.get_ticks_msec() / 1000.0
	last_movement_input = direction
	movement_started.emit(direction, magnitude)

func _on_movement_updated(direction: Vector2, magnitude: float):
	"""Handle movement update from priority manager"""
	last_movement_input = direction
	movement_updated.emit(direction, magnitude)

func _on_movement_stopped():
	"""Handle movement stop from priority manager"""
	movement_active = false
	last_movement_input = Vector2.ZERO
	movement_stopped.emit()

# === PUBLIC API ===

func register_input_component(component: Node):
	"""Register an input component with the priority system"""
	if priority_manager:
		priority_manager.register_component(component)
		print("✅ InputController: Registered component: ", component.name)

func unregister_input_component(component: Node):
	"""Unregister an input component"""
	if priority_manager:
		priority_manager.unregister_component(component)

func set_input_mode(mode: String):
	"""Set global input mode (for camera integration)"""
	if priority_manager:
		priority_manager.set_input_mode(mode)

func cancel_all_input():
	"""Cancel all active input"""
	if priority_manager:
		priority_manager.cancel_all_input()

func get_current_input() -> Vector2:
	"""Get current movement input"""
	return last_movement_input

func is_movement_active() -> bool:
	"""Check if movement is currently active"""
	return movement_active

# === CONFIGURATION ===

func set_movement_deadzone(deadzone: float):
	"""Update movement deadzone"""
	input_deadzone = deadzone
	if raw_input_processor:
		raw_input_processor.input_deadzone = deadzone
	if priority_manager:
		priority_manager.input_deadzone = deadzone

func set_update_frequency(frequency: int):
	"""Update movement processing frequency"""
	movement_update_frequency = frequency
	if priority_manager:
		priority_manager.movement_update_frequency = frequency

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get comprehensive debug information"""
	var info = {
		"movement_active": movement_active,
		"current_input": last_movement_input,
		"movement_duration": (Time.get_ticks_msec() / 1000.0) - movement_start_time if movement_active else 0.0,
		"input_deadzone": input_deadzone,
		"update_frequency": movement_update_frequency
	}
	
	# Add module debug info
	if raw_input_processor:
		info["raw_input"] = raw_input_processor.get_debug_info()
	
	if priority_manager:
		info["priority_manager"] = priority_manager.get_debug_info()
	
	return info

func get_component_status() -> Dictionary:
	"""Get status of all registered components"""
	if priority_manager:
		return priority_manager.get_component_status()
	return {}
