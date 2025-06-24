# CharacterStates.gd - Single-responsibility focused states

# === BASE STATE CLASS ===
class_name CharacterStateBase
extends State

var character: CharacterBody3D

func enter():
	super.enter()
	character = owner as CharacterBody3D
	if not character:
		push_error("CharacterState requires CharacterBody3D owner")

func update(delta: float):
	super.update(delta)
	character.handle_jump_input()

func handle_common_input():
	"""Handle input that works in all states"""
	if Input.is_action_just_pressed("reset"):
		character.reset_character()
