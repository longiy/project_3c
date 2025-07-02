# CHARACTER.gd
# CHARACTER system container
# Manages character-related components and CharacterCore

extends Node3D
class_name CharacterSystem

# References
@onready var character_core: CharacterBody3D = $CharacterCore
@onready var character_components = $CharacterComponents

var manager: CCC_Manager

func _ready():
	# Verify structure
	if not character_core:
		push_error("CHARACTER: CharacterCore not found")
		return
		
	if not character_components:
		push_error("CHARACTER: CharacterComponents not found")
		return

func set_manager(control_manager: CCC_Manager):
	manager = control_manager

func get_character_core() -> CharacterBody3D:
	return character_core

func get_components() -> Node3D:
	return character_components
