# InputPriorityManager.gd
# Manages input priority and routes to appropriate control components
# Implements "last input wins" with WASD fallback system

extends Node
class_name InputPriorityManager

# Input types
enum InputType {
	DIRECT,     # WASD + Mouse look
	TARGET,     # Click navigation
	GAMEPAD     # Controller input
}

var input_core: InputCore
var active_input_type: InputType = InputType.DIRECT

# Priority system state
var last_input_time: float = 0.0
var input_timeout: float = 1.0  # Seconds before timeout
var navigation_timeout: float = 2.0  # Timeout for click navigation

# Component references (populated when components are created)
var input_components: Dictionary = {}
var component_last_activity: Dictionary = {}

func _ready():
	# Initialize last activity tracking
	component_last_activity[InputType.DIRECT] = 0.0
	component_last_activity[InputType.TARGET] = 0.0
	component_last_activity[InputType.GAMEPAD] = 0.0

func _process(delta):
	# Check for input timeouts
	check_input_timeouts()

func set_input_core(core: InputCore):
	input_core = core
	
	# Find and register input components
	call_deferred("find_input_components")

func find_input_components():
	# Find control components in the scene
	if not input_core:
		return
	
	var control_components = input_core.get_control_components()
	if not control_components:
		push_warning("InputPriorityManager: No control components found")
		return
	
	# Register components as they're found
	var direct_control = control_components.get_node_or_null("DirectControlComponent")
	if direct_control:
		input_components[InputType.DIRECT] = direct_control
		print("InputPriorityManager: DirectControlComponent registered")
	
	var target_control = control_components.get_node_or_null("TargetControlComponent")
	if target_control:
		input_components[InputType.TARGET] = target_control
		print("InputPriorityManager: TargetControlComponent registered")
	
	var gamepad_control = control_components.get_node_or_null("GamepadControlComponent")
	if gamepad_control:
		input_components[InputType.GAMEPAD] = gamepad_control
		print("InputPriorityManager: GamepadControlComponent registered")

func route_input(event: InputEvent, input_type_string: String):
	# Convert string to enum
	var input_type = get_input_type_from_string(input_type_string)
	
	# Update activity tracking
	update_input_activity(input_type)
	
	# Route to appropriate component
	route_to_component(input_type, event)
	
	# Apply WASD fallback if needed
	apply_wasd_fallback(input_type, event)

func get_input_type_from_string(type_string: String) -> InputType:
	match type_string.to_upper():
		"DIRECT":
			return InputType.DIRECT
		"TARGET":
			return InputType.TARGET
		"GAMEPAD":
			return InputType.GAMEPAD
		_:
			return InputType.DIRECT  # Default fallback

func update_input_activity(input_type: InputType):
	# Update activity timing
	var current_time = Time.get_ticks_msec() / 1000.0
	component_last_activity[input_type] = current_time
	
	# Switch active input if this is a new input type with recent activity
	if input_type != active_input_type:
		var time_since_last = current_time - component_last_activity[active_input_type]
		
		# Switch if previous input has been inactive for a while
		if time_since_last > 0.1:  # 100ms grace period
			set_active_input(input_type)

func set_active_input(input_type: InputType):
	if active_input_type == input_type:
		return
	
	var old_type = active_input_type
	active_input_type = input_type
	last_input_time = Time.get_ticks_msec() / 1000.0
	
	print("InputPriorityManager: Switched from ", get_input_type_name(old_type), 
		  " to ", get_input_type_name(active_input_type))

func route_to_component(input_type: InputType, event: InputEvent):
	# Route input to the appropriate component
	var component = input_components.get(input_type)
	if component and component.has_method("process_input"):
		component.process_input(event)

func apply_wasd_fallback(primary_input_type: InputType, event: InputEvent):
	# Always process WASD input as fallback, unless it's the primary input
	if primary_input_type != InputType.DIRECT:
		var direct_component = input_components.get(InputType.DIRECT)
		if direct_component and direct_component.has_method("process_fallback_input"):
			direct_component.process_fallback_input(event)

func check_input_timeouts():
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Check if current active input has timed out
	var time_since_active = current_time - component_last_activity.get(active_input_type, 0.0)
	
	# Reset to direct control if active input has timed out
	if active_input_type != InputType.DIRECT and time_since_active > input_timeout:
		print("InputPriorityManager: Input timeout, resetting to DIRECT control")
		set_active_input(InputType.DIRECT)

func reset_to_direct_control():
	# Force reset to direct control (called when navigation completes)
	set_active_input(InputType.DIRECT)

func get_input_type_name(input_type: InputType) -> String:
	match input_type:
		InputType.DIRECT:
			return "DIRECT"
		InputType.TARGET:
			return "TARGET"
		InputType.GAMEPAD:
			return "GAMEPAD"
		_:
			return "UNKNOWN"

# Public API for components
func register_component(input_type: InputType, component: Node):
	# Allow components to register themselves
	input_components[input_type] = component
	component_last_activity[input_type] = 0.0
	print("InputPriorityManager: Component registered for ", get_input_type_name(input_type))

func get_active_input_type() -> InputType:
	return active_input_type

func is_input_active(input_type: InputType) -> bool:
	return active_input_type == input_type

# Debug info
func get_debug_info() -> Dictionary:
	var component_names = {}
	for type in input_components:
		var component = input_components[type]
		component_names[get_input_type_name(type)] = component.name if component else "null"
	
	return {
		"active_input": get_input_type_name(active_input_type),
		"registered_components": component_names,
		"last_input_time": last_input_time,
		"time_since_last_input": Time.get_ticks_msec() / 1000.0 - last_input_time
	}
