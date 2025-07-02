# CONTROL.gd
# CONTROL system container  
# Manages input processing and control components

extends Node3D
class_name ControlSystem

# References
@onready var input_core = $InputCore
@onready var control_components = $ControlComponents

var manager: CCC_Manager

func _ready():
	# Verify structure
	if not input_core:
		push_error("CONTROL: InputCore not found")
		return
		
	if not control_components:
		push_error("CONTROL: ControlComponents not found")
		return

func set_manager(control_manager: CCC_Manager):
	manager = control_manager

func process_input(event: InputEvent):
	# Route input to InputCore for processing
	if input_core and input_core.has_method("process_input"):
		input_core.process_input(event)

func process_unhandled_input(event: InputEvent):
	# Route unhandled input to InputCore
	if input_core and input_core.has_method("process_unhandled_input"):
		input_core.process_unhandled_input(event)

func get_input_core():
	return input_core

func get_components() -> Node3D:
	return control_components
