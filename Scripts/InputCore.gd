# InputCore.gd
# Central input processing hub for CONTROL system
# Refactored: Export references, removed redundant code

extends Node
class_name InputCore

# Export references instead of onready absolute paths
@export_group("References")
@export var raw_input_processor: RawInputProcessor
@export var input_priority_manager: InputPriorityManager
@export var control_system: ControlSystem

func _ready():
	if not verify_references():
		return
	
	setup_input_processors()

func verify_references() -> bool:
	var missing = []
	
	if not raw_input_processor: missing.append("raw_input_processor")
	if not input_priority_manager: missing.append("input_priority_manager")
	if not control_system: missing.append("control_system")
	
	if missing.size() > 0:
		push_error("InputCore: Missing references: " + str(missing))
		return false
	
	return true

func setup_input_processors():
	if raw_input_processor and raw_input_processor.has_method("set_input_core"):
		raw_input_processor.set_input_core(self)
	
	if input_priority_manager and input_priority_manager.has_method("set_input_core"):
		input_priority_manager.set_input_core(self)

func process_input(event: InputEvent):
	if raw_input_processor:
		raw_input_processor.process_raw_input(event)

func process_unhandled_input(event: InputEvent):
	if raw_input_processor:
		raw_input_processor.process_unhandled_input(event)

func route_to_priority_manager(event: InputEvent, input_type: String):
	if input_priority_manager:
		input_priority_manager.route_input(event, input_type)

func get_control_components():
	return control_system.get_components() if control_system else null
