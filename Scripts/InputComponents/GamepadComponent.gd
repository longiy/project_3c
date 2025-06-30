# GamepadInputComponent.gd - Example of how to add more input types
extends Node
class_name GamepadInputComponent

@export_group("Gamepad Settings")
@export var gamepad_device = 0
@export var deadzone = 0.2
@export var enable_gamepad = true

var character: CharacterBody3D

func _ready():
	character = get_parent() as CharacterBody3D
	if not character:
		push_error("GamepadInputComponent must be child of CharacterBody3D")

# === PUBLIC INTERFACE FOR CHARACTER CONTROLLER ===

func is_active() -> bool:
	"""Check if gamepad is providing input"""
	if not enable_gamepad:
		return false
	
	var gamepad_input = Input.get_vector(
		"ui_left", "ui_right", "ui_up", "ui_down", 
		deadzone
	)
	
	return gamepad_input.length() > deadzone

func get_movement_input() -> Vector2:
	"""Get movement input from gamepad"""
	if not enable_gamepad:
		return Vector2.ZERO
	
	return Input.get_vector(
		"ui_left", "ui_right", "ui_up", "ui_down", 
		deadzone
	)

func cancel_input():
	"""Cancel any gamepad-specific state (none needed for this simple component)"""
	pass
