class_name CCC_InputManager
extends Node

@export_group("Input Components")
@export var keyboard_input: CCC_KeyboardInput
@export var click_navigation: CCC_ClickNavigation
@export var gamepad_input: CCC_GamepadInput

@export_group("3C Integration")
@export var character_controller: CCC_CharacterController
@export var camera_controller: CCC_CameraController

@export_group("Input Settings")
@export var input_deadzone: float = 0.1

var input_components: Array[Node] = []
var current_raw_input: Vector2 = Vector2.ZERO
var movement_active: bool = false
var movement_start_time: float = 0.0
var wasd_is_overriding: bool = false

signal movement_input_changed(input_direction: Vector2)
signal action_input_triggered(action: String)
signal input_source_changed(source: String)

func _ready():
	find_input_components()
	connect_component_signals()

func _process(_delta):
	var new_input = get_combined_input()
	
	if new_input != current_raw_input:
		current_raw_input = new_input
		movement_input_changed.emit(current_raw_input)
		
		# Track movement timing
		if current_raw_input.length() > input_deadzone and not movement_active:
			movement_active = true
			movement_start_time = Time.get_ticks_msec() / 1000.0
		elif current_raw_input.length() <= input_deadzone and movement_active:
			movement_active = false

func find_input_components():
	input_components.clear()
	
	if keyboard_input:
		input_components.append(keyboard_input)
	if click_navigation:
		input_components.append(click_navigation)
	if gamepad_input:
		input_components.append(gamepad_input)

func connect_component_signals():
	if keyboard_input:
		keyboard_input.action_triggered.connect(_on_action_triggered)
	if click_navigation:
		click_navigation.navigation_started.connect(_on_navigation_started)
		click_navigation.navigation_cancelled.connect(_on_navigation_cancelled)
	if gamepad_input:
		gamepad_input.action_triggered.connect(_on_action_triggered)

func get_combined_input() -> Vector2:
	# Check camera mode for input priority
	var camera_mode = camera_controller.get_current_mode() if camera_controller else 0
	
	if camera_mode != 1:  # Not in orbit mode
		# Standard priority: WASD can override other inputs
		var wasd_input = keyboard_input.get_movement_input() if keyboard_input else Vector2.ZERO
		
		if wasd_input.length() > input_deadzone:
			wasd_is_overriding = true
			cancel_all_input_components()
			return wasd_input
		else:
			wasd_is_overriding = false
			# Check other input components
			for component in input_components:
				if component != keyboard_input and is_component_active(component):
					var component_input = component.get_movement_input()
					if component_input and component_input.length() > input_deadzone:
						return component_input
	else:
		# In orbit mode - WASD only
		wasd_is_overriding = false
		var wasd_input = keyboard_input.get_movement_input() if keyboard_input else Vector2.ZERO
		if wasd_input.length() > input_deadzone:
			cancel_all_input_components()
			return wasd_input
	
	return Vector2.ZERO

func cancel_all_input_components():
	for component in input_components:
		if component and component.has_method("cancel_input"):
			component.cancel_input()

func is_component_active(component: Node) -> bool:
	return is_instance_valid(component) and component.has_method("is_active") and component.is_active()

func _on_action_triggered(action: String):
	action_input_triggered.emit(action)

func _on_navigation_started():
	input_source_changed.emit("click_navigation")

func _on_navigation_cancelled():
	input_source_changed.emit("none")

func get_movement_duration() -> float:
	if movement_active:
		return (Time.get_ticks_msec() / 1000.0) - movement_start_time
	return 0.0

func is_movement_active() -> bool:
	return movement_active

func get_current_input_direction() -> Vector2:
	return current_raw_input

func get_debug_info() -> Dictionary:
	return {
		"input_movement_active": movement_active,
		"input_current_input": current_raw_input,
		"input_movement_duration": get_movement_duration(),
		"input_component_count": input_components.size(),
		"input_camera_mode": camera_controller.get_mode_name(camera_controller.get_current_mode()) if camera_controller else "unknown",
		"input_wasd_overriding": wasd_is_overriding
	}