# InputPriorityManager.gd
# Complete Day 10 implementation with smooth transitions and visual feedback
# Manages input priority and routes to appropriate control components

extends Node
class_name InputPriorityManager

# Input types
enum InputType {
	DIRECT,     # WASD + Mouse look
	TARGET,     # Click navigation
	GAMEPAD     # Controller input
}

# Transition states for smooth switching
enum TransitionState {
	STABLE,      # Normal operation
	SWITCHING,   # Transitioning between inputs
	BLENDING     # Blending multiple inputs
}

var input_core: InputCore
var active_input_type: InputType = InputType.DIRECT
var previous_input_type: InputType = InputType.DIRECT
var transition_state: TransitionState = TransitionState.STABLE

# Priority system state
var last_input_time: float = 0.0
var input_timeout: float = 1.5  # Increased timeout for smoother experience
var navigation_timeout: float = 3.0  # Longer timeout for click navigation
var switch_grace_period: float = 0.15  # Prevent rapid switching

# Component references
var input_components: Dictionary = {}
var component_last_activity: Dictionary = {}

# Smooth transition system
var transition_duration: float = 0.2
var transition_start_time: float = 0.0
var transition_blend_factor: float = 0.0

# Input smoothing and buffering
var input_smoothing_enabled: bool = true
var input_buffer_size: int = 5
var input_history: Array = []

# Visual feedback system
signal input_method_changed(new_type: InputType, old_type: InputType)
signal input_activity_detected(input_type: InputType, activity_level: float)
signal transition_started(from_type: InputType, to_type: InputType)
signal transition_completed(final_type: InputType)

# Debug and monitoring
var debug_enabled: bool = false
var activity_thresholds: Dictionary = {
	InputType.DIRECT: 0.1,
	InputType.TARGET: 0.5,
	InputType.GAMEPAD: 0.2
}

func _ready():
	# Initialize activity tracking
	component_last_activity[InputType.DIRECT] = 0.0
	component_last_activity[InputType.TARGET] = 0.0
	component_last_activity[InputType.GAMEPAD] = 0.0
	
	# Initialize input history buffer
	input_history.resize(input_buffer_size)
	for i in range(input_buffer_size):
		input_history[i] = {"type": InputType.DIRECT, "time": 0.0, "intensity": 0.0}

func _process(delta):
	# Update transition system
	update_transition_system(delta)
	
	# Check for input timeouts
	check_input_timeouts()
	
	# Update input smoothing
	update_input_smoothing(delta)
	
	# Monitor input activity
	monitor_input_activity()

func set_input_core(core: InputCore):
	input_core = core
	call_deferred("find_input_components")

func find_input_components():
	if not input_core:
		return
	
	var control_components = input_core.get_control_components()
	if not control_components:
		push_warning("InputPriorityManager: No control components found")
		return
	
	# Register components
	register_component_if_exists(control_components, "DirectControlComponent", InputType.DIRECT)
	register_component_if_exists(control_components, "TargetControlComponent", InputType.TARGET)
	register_component_if_exists(control_components, "GamepadControlComponent", InputType.GAMEPAD)

func register_component_if_exists(parent: Node, component_name: String, input_type: InputType):
	var component = parent.get_node_or_null(component_name)
	if component:
		register_component(input_type, component)

func route_input(event: InputEvent, input_type_string: String):
	var input_type = get_input_type_from_string(input_type_string)
	
	# Record input activity
	record_input_activity(input_type, event)
	
	# Update activity tracking
	update_input_activity(input_type)
	
	# Route to components with transition handling
	route_with_transitions(input_type, event)

func record_input_activity(input_type: InputType, event: InputEvent):
	# Calculate input intensity
	var intensity = calculate_input_intensity(event)
	
	# Add to history buffer
	input_history.push_front({
		"type": input_type,
		"time": Time.get_ticks_msec() / 1000.0,
		"intensity": intensity
	})
	
	if input_history.size() > input_buffer_size:
		input_history.pop_back()
	
	# Emit activity signal
	input_activity_detected.emit(input_type, intensity)

func calculate_input_intensity(event: InputEvent) -> float:
	# Calculate how "intense" this input is for priority decisions
	if event is InputEventMouseMotion:
		return event.relative.length() / 10.0  # Normalize mouse movement
	elif event is InputEventKey:
		return 1.0 if event.pressed else 0.0
	elif event is InputEventMouseButton:
		return 2.0 if event.pressed else 0.0  # Clicks are high priority
	elif event is InputEventJoypadMotion:
		return abs(event.axis_value)
	elif event is InputEventJoypadButton:
		return 1.5 if event.pressed else 0.0
	else:
		return 0.1

func route_with_transitions(input_type: InputType, event: InputEvent):
	# Handle input routing with smooth transitions
	if transition_state == TransitionState.SWITCHING:
		# During transition, blend inputs
		route_to_blended_components(input_type, event)
	else:
		# Normal routing
		route_to_component(input_type, event)
		apply_wasd_fallback(input_type, event)

func route_to_blended_components(input_type: InputType, event: InputEvent):
	# Route to both old and new components during transition
	var blend_factor = transition_blend_factor
	
	# Route to previous component with decreasing influence
	if previous_input_type != input_type:
		var prev_component = input_components.get(previous_input_type)
		if prev_component and prev_component.has_method("process_transition_input"):
			prev_component.process_transition_input(event, 1.0 - blend_factor)
	
	# Route to new component with increasing influence
	var new_component = input_components.get(input_type)
	if new_component and new_component.has_method("process_transition_input"):
		new_component.process_transition_input(event, blend_factor)
	elif new_component and new_component.has_method("process_input"):
		# Fallback if component doesn't support transitions
		new_component.process_input(event)

func update_transition_system(delta: float):
	if transition_state != TransitionState.SWITCHING:
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	var elapsed = current_time - transition_start_time
	
	# Update blend factor (smooth curve)
	transition_blend_factor = ease_in_out(elapsed / transition_duration)
	
	# Complete transition
	if elapsed >= transition_duration:
		complete_transition()

func ease_in_out(t: float) -> float:
	# Smooth transition curve
	t = clamp(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

func complete_transition():
	transition_state = TransitionState.STABLE
	transition_blend_factor = 1.0
	transition_completed.emit(active_input_type)
	
	if debug_enabled:
		print("InputPriorityManager: Transition completed to ", get_input_type_name(active_input_type))

func update_input_activity(input_type: InputType):
	var current_time = Time.get_ticks_msec() / 1000.0
	component_last_activity[input_type] = current_time
	
	# Check if we should switch inputs
	if should_switch_input(input_type):
		initiate_input_switch(input_type)

func should_switch_input(input_type: InputType) -> bool:
	if input_type == active_input_type:
		return false
	
	var current_time = Time.get_ticks_msec() / 1000.0
	var time_since_last_switch = current_time - transition_start_time
	
	# Prevent rapid switching
	if time_since_last_switch < switch_grace_period:
		return false
	
	# Check activity threshold
	var recent_activity = get_recent_activity_level(input_type)
	var threshold = activity_thresholds.get(input_type, 0.2)
	
	return recent_activity > threshold

func get_recent_activity_level(input_type: InputType) -> float:
	var current_time = Time.get_ticks_msec() / 1000.0
	var total_intensity = 0.0
	var count = 0
	
	# Analyze recent input history
	for entry in input_history:
		if entry.type == input_type and (current_time - entry.time) < 0.5:
			total_intensity += entry.intensity
			count += 1
	
	return total_intensity / max(count, 1)

func initiate_input_switch(new_input_type: InputType):
	if transition_state == TransitionState.SWITCHING:
		return  # Already switching
	
	previous_input_type = active_input_type
	active_input_type = new_input_type
	transition_state = TransitionState.SWITCHING
	transition_start_time = Time.get_ticks_msec() / 1000.0
	transition_blend_factor = 0.0
	
	# Emit signals
	input_method_changed.emit(new_input_type, previous_input_type)
	transition_started.emit(previous_input_type, new_input_type)
	
	if debug_enabled:
		print("InputPriorityManager: Switching from ", get_input_type_name(previous_input_type), 
			  " to ", get_input_type_name(new_input_type))

func update_input_smoothing(delta: float):
	if not input_smoothing_enabled:
		return
	
	# Smooth input activity levels for more stable switching
	for input_type in component_last_activity:
		var activity = component_last_activity[input_type]
		var current_time = Time.get_ticks_msec() / 1000.0
		
		# Apply exponential decay to activity levels
		var decay_rate = 2.0  # How quickly activity decays
		var time_diff = current_time - activity
		var decayed_activity = activity * exp(-decay_rate * time_diff)
		
		component_last_activity[input_type] = decayed_activity

func monitor_input_activity():
	# Monitor overall system health and performance
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Check for stuck transitions
	if transition_state == TransitionState.SWITCHING:
		var transition_time = current_time - transition_start_time
		if transition_time > transition_duration * 2.0:
			# Force complete stuck transition
			push_warning("InputPriorityManager: Stuck transition detected, force completing")
			complete_transition()

func check_input_timeouts():
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Get appropriate timeout for current input type
	var timeout = input_timeout
	if active_input_type == InputType.TARGET:
		timeout = navigation_timeout
	
	# Check if current input has timed out
	var time_since_active = current_time - component_last_activity.get(active_input_type, 0.0)
	
	if active_input_type != InputType.DIRECT and time_since_active > timeout:
		if debug_enabled:
			print("InputPriorityManager: Input timeout, resetting to DIRECT control")
		reset_to_direct_control()

func reset_to_direct_control():
	if active_input_type == InputType.DIRECT:
		return
	
	initiate_input_switch(InputType.DIRECT)

func get_input_type_from_string(type_string: String) -> InputType:
	match type_string.to_upper():
		"DIRECT":
			return InputType.DIRECT
		"TARGET":
			return InputType.TARGET
		"GAMEPAD":
			return InputType.GAMEPAD
		_:
			return InputType.DIRECT

func set_active_input(input_type: InputType):
	# Direct API for forced input switching
	if active_input_type == input_type:
		return
	
	initiate_input_switch(input_type)

func route_to_component(input_type: InputType, event: InputEvent):
	var component = input_components.get(input_type)
	if component and component.has_method("process_input"):
		component.process_input(event)

func apply_wasd_fallback(primary_input_type: InputType, event: InputEvent):
	if primary_input_type != InputType.DIRECT:
		var direct_component = input_components.get(InputType.DIRECT)
		if direct_component and direct_component.has_method("process_fallback_input"):
			direct_component.process_fallback_input(event)

# Public API
func register_component(input_type: InputType, component: Node):
	input_components[input_type] = component
	component_last_activity[input_type] = 0.0
	print("InputPriorityManager: Component registered for ", get_input_type_name(input_type))

func get_active_input_type() -> InputType:
	return active_input_type

func is_input_active(input_type: InputType) -> bool:
	return active_input_type == input_type

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

# Configuration API
func set_transition_duration(duration: float):
	transition_duration = clamp(duration, 0.05, 1.0)

func set_activity_threshold(input_type: InputType, threshold: float):
	activity_thresholds[input_type] = clamp(threshold, 0.0, 2.0)

func enable_debug(enabled: bool):
	debug_enabled = enabled

func enable_input_smoothing(enabled: bool):
	input_smoothing_enabled = enabled

# Debug info
func get_debug_info() -> Dictionary:
	var component_names = {}
	for type in input_components:
		var component = input_components[type]
		component_names[get_input_type_name(type)] = component.name if component else "null"
	
	return {
		"active_input": get_input_type_name(active_input_type),
		"previous_input": get_input_type_name(previous_input_type),
		"transition_state": transition_state,
		"transition_progress": transition_blend_factor,
		"registered_components": component_names,
		"last_input_time": last_input_time,
		"activity_levels": get_all_activity_levels(),
		"input_history_size": input_history.size()
	}

func get_all_activity_levels() -> Dictionary:
	var levels = {}
	for input_type in component_last_activity:
		levels[get_input_type_name(input_type)] = get_recent_activity_level(input_type)
	return levels
