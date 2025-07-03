# InputVisualFeedback.gd
# Provides visual feedback for input system state
# Refactored: Uses InputCore instead of InputPriorityManager

extends Node
class_name InputVisualFeedback

# Export reference for inspector assignment
@export_group("References")
@export var input_core: InputCore

@export_group("Visual Settings")
@export var debug_label: Label
@export var update_rate: float = 0.1
@export var show_detailed_info: bool = false

var update_timer: float = 0.0

func _ready():
	if not input_core:
		push_error("InputVisualFeedback: Please assign InputCore in the Inspector")
		return
	
	if not debug_label:
		push_error("InputVisualFeedback: Please assign debug_label in the Inspector")
		return
	
	# Set up update timer
	set_process(true)

func _process(delta):
	update_timer += delta
	
	if update_timer >= update_rate:
		update_visual_feedback()
		update_timer = 0.0

func update_visual_feedback():
	if not input_core or not debug_label:
		return
	
	var feedback_text = ""
	
	# Basic input type info
	var active_type = input_core.get_active_input_type()
	feedback_text += "Active Input: " + input_core.get_input_type_name(active_type) + "\n"
	
	# Mouse mode info
	var mouse_mode_text = ""
	match Input.mouse_mode:
		Input.MOUSE_MODE_VISIBLE:
			mouse_mode_text = "Mouse: Visible"
		Input.MOUSE_MODE_CAPTURED:
			mouse_mode_text = "Mouse: Captured"
		Input.MOUSE_MODE_CONFINED:
			mouse_mode_text = "Mouse: Confined"
		_:
			mouse_mode_text = "Mouse: Unknown"
	
	feedback_text += mouse_mode_text + "\n"
	
	# Show detailed debug info if enabled
	if show_detailed_info:
		var debug_info = input_core.get_debug_info()
		feedback_text += "---\n"
		feedback_text += "Components: " + str(debug_info.registered_components.size()) + "\n"
		
		for component_name in debug_info.registered_components:
			var component = debug_info.registered_components[component_name]
			feedback_text += "  " + component_name + ": " + str(component) + "\n"
	
	debug_label.text = feedback_text

func set_detailed_info(enabled: bool):
	show_detailed_info = enabled

func set_update_rate(rate: float):
	update_rate = clamp(rate, 0.05, 1.0)

# Public API for manual updates
func force_update():
	update_visual_feedback()

func get_current_input_type() -> String:
	if input_core:
		return input_core.get_input_type_name(input_core.get_active_input_type())
	return "Unknown"
