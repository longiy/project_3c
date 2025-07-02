# InputCore.gd
# Central input processing hub for CONTROL system
# Routes input events to appropriate processors

extends Node
class_name InputCore

# References
@onready var raw_input_processor = $RawInputProcessor
@onready var input_priority_manager = $InputPriorityManager

var control_system: ControlSystem

func _ready():
	# Get parent CONTROL system
	control_system = get_parent() as ControlSystem
	if not control_system:
		push_error("InputCore: Must be child of CONTROL system")
		return
	
	# Verify child processors exist
	if not raw_input_processor:
		push_error("InputCore: RawInputProcessor not found")
		return
		
	if not input_priority_manager:
		push_error("InputCore: InputPriorityManager not found")
		return
	
	# Initialize processors
	setup_input_processors()

func setup_input_processors():
	# Connect processors to InputCore
	if raw_input_processor and raw_input_processor.has_method("set_input_core"):
		raw_input_processor.set_input_core(self)
	
	if input_priority_manager and input_priority_manager.has_method("set_input_core"):
		input_priority_manager.set_input_core(self)

func process_input(event: InputEvent):
	# Route input to RawInputProcessor first
	if raw_input_processor and raw_input_processor.has_method("process_raw_input"):
		raw_input_processor.process_raw_input(event)

func process_unhandled_input(event: InputEvent):
	# Handle any unprocessed input
	if raw_input_processor and raw_input_processor.has_method("process_unhandled_input"):
		raw_input_processor.process_unhandled_input(event)

# API for processors to route input through priority system
func route_to_priority_manager(event: InputEvent, input_type: String):
	if input_priority_manager and input_priority_manager.has_method("route_input"):
		input_priority_manager.route_input(event, input_type)

# API for getting control components
func get_control_components():
	if control_system:
		return control_system.get_components()
	return null

# Debug info
func get_input_debug_info() -> Dictionary:
	return {
		"raw_processor_active": raw_input_processor != null,
		"priority_manager_active": input_priority_manager != null,
		"control_system_connected": control_system != null
	}