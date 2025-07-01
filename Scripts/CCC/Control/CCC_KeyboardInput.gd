class_name CCC_KeyboardInput
extends Node

@export_group("Input Actions")
@export var move_left: String = "move_left"
@export var move_right: String = "move_right"
@export var move_forward: String = "move_forward"
@export var move_backward: String = "move_backward"
@export var jump_action: String = "jump"
@export var run_action: String = "run"

@export_group("Settings")
@export var input_deadzone: float = 0.1

var current_movement_input: Vector2 = Vector2.ZERO
var is_active_flag: bool = true

signal action_triggered(action: String)
signal movement_changed(direction: Vector2)

func _process(_delta):
	var new_input = get_movement_input()
	
	if new_input != current_movement_input:
		current_movement_input = new_input
		movement_changed.emit(current_movement_input)

func _input(event):
	if not is_active_flag:
		return
	
	# Handle action inputs
	if event.is_action_pressed(jump_action):
		action_triggered.emit("jump")
	elif event.is_action_released(jump_action):
		action_triggered.emit("jump_release")
	elif event.is_action_pressed(run_action):
		action_triggered.emit("run_start")
	elif event.is_action_released(run_action):
		action_triggered.emit("run_end")

func get_movement_input() -> Vector2:
	if not is_active_flag:
		return Vector2.ZERO
	
	var input_vector = Input.get_vector(
		move_left,
		move_right,
		move_forward,
		move_backward,
		input_deadzone
	)
	
	return input_vector

func is_active() -> bool:
	return is_active_flag

func set_active(active: bool):
	is_active_flag = active
	
	if not active:
		current_movement_input = Vector2.ZERO
		movement_changed.emit(current_movement_input)

func cancel_input():
	# Keyboard input doesn't need cancellation - it's immediate
	pass

func get_debug_info() -> Dictionary:
	return {
		"keyboard_active": is_active_flag,
		"keyboard_movement": current_movement_input,
		"keyboard_raw_left": Input.get_action_strength(move_left),
		"keyboard_raw_right": Input.get_action_strength(move_right),
		"keyboard_raw_forward": Input.get_action_strength(move_forward),
		"keyboard_raw_backward": Input.get_action_strength(move_backward)
	}
