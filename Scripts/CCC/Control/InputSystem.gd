# InputSystem.gd - Child of CCC_ControlManager
extends Node
class_name InputSystem

# === SIGNALS ===
signal wasd_input(direction: Vector2)
signal jump_pressed()
signal sprint_toggled(is_running: bool)
signal slow_walk_toggled(is_slow: bool)

# === SETTINGS ===
@export var deadzone = 0.05

# === STATE ===
var current_input: Vector2
var is_sprint_held: bool = false
var is_slow_walk_held: bool = false

func _ready():
	print("✅ InputSystem: Ready as child of CCC_ControlManager")

func process_input(event):
	"""Process keyboard/gamepad input events"""
	if event.is_action_pressed("jump"):
		jump_pressed.emit()
	elif event.is_action_pressed("sprint"):
		is_sprint_held = true
		sprint_toggled.emit(true)
	elif event.is_action_released("sprint"):
		is_sprint_held = false
		sprint_toggled.emit(false)
	elif event.is_action_pressed("walk"):
		is_slow_walk_held = true
		slow_walk_toggled.emit(true)
	elif event.is_action_released("walk"):
		is_slow_walk_held = false
		slow_walk_toggled.emit(false)

func _physics_process(delta):
	"""Continuous input processing"""
	# Get WASD input
	current_input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	# Apply deadzone
	if current_input.length() < deadzone:
		current_input = Vector2.ZERO
	
	# Emit input signal
	wasd_input.emit(current_input)

func get_current_input() -> Vector2:
	"""Get current input direction"""
	return current_input

func get_input_magnitude() -> float:
	"""Get input magnitude"""
	return current_input.length()

func is_providing_input() -> bool:
	"""Check if providing meaningful input"""
	return current_input.length() > deadzone

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get debug information"""
	return {
		"current_input": current_input,
		"magnitude": current_input.length(),
		"is_sprint_held": is_sprint_held,
		"is_slow_walk_held": is_slow_walk_held,
		"providing_input": is_providing_input()
	}
