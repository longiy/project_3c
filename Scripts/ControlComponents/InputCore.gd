# InputCore.gd
# Simplified input processing hub - merged with priority management
# Removed RawInputProcessor dependency

extends Node
class_name InputCore

# Direct component references
@export_group("Input Components")
@export var direct_component: DirectControlComponent
@export var target_component: TargetControlComponent
@export var gamepad_component: GamepadControlComponent

@export_group("Input Settings")
@export var activity_threshold: float = 0.1
@export var transition_delay: float = 0.2
@export var debug_enabled: bool = false

# Input types
enum InputType {
	DIRECT,
	TARGET,
	GAMEPAD
}

# State tracking
var active_input_type: InputType = InputType.DIRECT
var previous_input_type: InputType = InputType.DIRECT
var last_activity_times: Dictionary = {}
var input_components: Dictionary = {}

# WASD actions for fallback
var wasd_actions = ["move_forward", "move_backward", "move_left", "move_right"]

func _ready():
	setup_input_components()
	initialize_activity_tracking()
	
	if debug_enabled:
		print("InputCore: Initialized with simplified architecture")

func setup_input_components():
	# Register components in dictionary for easy access
	if direct_component:
		input_components[InputType.DIRECT] = direct_component
		register_component_signals(direct_component, InputType.DIRECT)
	
	if target_component:
		input_components[InputType.TARGET] = target_component
		register_component_signals(target_component, InputType.TARGET)
	
	if gamepad_component:
		input_components[InputType.GAMEPAD] = gamepad_component
		register_component_signals(gamepad_component, InputType.GAMEPAD)

func register_component_signals(component: Node, input_type: InputType):
	# Set up bidirectional communication with components
	if component.has_signal("input_activity"):
		component.input_activity.connect(_on_component_activity.bind(input_type))

func initialize_activity_tracking():
	var current_time = Time.get_ticks_msec() / 1000.0
	for input_type in InputType.values():
		last_activity_times[input_type] = current_time

# ===== COMPONENT REGISTRATION =====

func register_component(input_type: InputType, component: Node):
	# Allow components to register themselves at runtime
	input_components[input_type] = component
	last_activity_times[input_type] = Time.get_ticks_msec() / 1000.0
	
	if debug_enabled:
		print("InputCore: Component registered for ", get_input_type_name(input_type))

func unregister_component(input_type: InputType):
	# Remove component registration
	input_components.erase(input_type)
	last_activity_times.erase(input_type)
	
	if debug_enabled:
		print("InputCore: Component unregistered for ", get_input_type_name(input_type))

# ===== MAIN INPUT PROCESSING =====

func process_input(event: InputEvent):
	var input_type = classify_input(event)
	update_activity_tracking(input_type)
	
	# Handle input type switching
	if should_switch_input_type(input_type):
		switch_to_input_type(input_type)
	
	# Route to active component
	route_to_active_component(event)
	
	# Handle WASD fallback for non-direct inputs
	apply_wasd_fallback(event)

func process_unhandled_input(event: InputEvent):
	# Handle special system inputs
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				handle_escape_key()
			KEY_TAB:
				if event.pressed and not event.echo:
					toggle_mouse_mode()

# ===== INPUT CLASSIFICATION =====

func classify_input(event: InputEvent) -> InputType:
	# Mouse clicks for targeting
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			return InputType.TARGET
	
	# Gamepad input
	if event is InputEventJoypadMotion:
		var threshold = 0.2
		if abs(event.axis_value) > threshold:
			return InputType.GAMEPAD
	
	if event is InputEventJoypadButton and event.pressed:
		return InputType.GAMEPAD
	
	# Default to direct control
	return InputType.DIRECT

func get_input_priority(event: InputEvent) -> float:
	# Calculate input strength for priority decisions
	if event is InputEventKey:
		return 1.0 if event.pressed else 0.0
	elif event is InputEventMouseButton:
		return 2.0 if event.pressed else 0.0
	elif event is InputEventJoypadMotion:
		return abs(event.axis_value)
	elif event is InputEventJoypadButton:
		return 1.5 if event.pressed else 0.0
	else:
		return 0.1

# ===== INPUT TYPE SWITCHING =====

func should_switch_input_type(new_type: InputType) -> bool:
	if new_type == active_input_type:
		return false
	
	# Check if enough time has passed since last switch
	var current_time = Time.get_ticks_msec() / 1000.0
	var time_since_last = current_time - last_activity_times.get(active_input_type, 0.0)
	
	return time_since_last > transition_delay

func switch_to_input_type(new_type: InputType):
	if new_type == active_input_type:
		return
	
	previous_input_type = active_input_type
	active_input_type = new_type
	
	# Notify components of switch
	notify_components_of_switch()
	
	if debug_enabled:
		print("InputCore: Switched from ", get_input_type_name(previous_input_type), 
			  " to ", get_input_type_name(active_input_type))

func notify_components_of_switch():
	# Deactivate previous component
	var prev_component = input_components.get(previous_input_type)
	if prev_component and prev_component.has_method("set_active"):
		prev_component.set_active(false)
	
	# Activate new component
	var new_component = input_components.get(active_input_type)
	if new_component and new_component.has_method("set_active"):
		new_component.set_active(true)

# ===== INPUT ROUTING =====

func route_to_active_component(event: InputEvent):
	var component = input_components.get(active_input_type)
	if component and component.has_method("process_input"):
		component.process_input(event)

func apply_wasd_fallback(event: InputEvent):
	# Allow WASD override for non-direct input modes
	if active_input_type == InputType.DIRECT:
		return
	
	if event is InputEventKey and event.pressed:
		var action = get_action_for_key(event)
		if action in wasd_actions:
			var direct_comp = input_components.get(InputType.DIRECT)
			if direct_comp and direct_comp.has_method("process_fallback_input"):
				direct_comp.process_fallback_input(event)

func get_action_for_key(event: InputEventKey) -> String:
	# Map key events to action names
	for action in wasd_actions:
		if InputMap.action_has_event(action, event):
			return action
	
	# Check other actions
	var other_actions = ["jump", "sprint", "walk", "reset"]
	for action in other_actions:
		if InputMap.action_has_event(action, event):
			return action
	
	return ""

# ===== ACTIVITY TRACKING =====

func update_activity_tracking(input_type: InputType):
	var current_time = Time.get_ticks_msec() / 1000.0
	last_activity_times[input_type] = current_time

func _on_component_activity(input_type: InputType):
	# Called when components report activity
	update_activity_tracking(input_type)

# ===== SYSTEM CONTROLS =====

func handle_escape_key():
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if debug_enabled:
			print("InputCore: Mouse released (ESC)")

func toggle_mouse_mode():
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if debug_enabled:
			print("InputCore: Mouse released")
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if debug_enabled:
			print("InputCore: Mouse captured")

# ===== PUBLIC API =====

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

func get_active_component() -> Node:
	# Get the currently active input component
	return input_components.get(active_input_type)

func get_component(input_type: InputType) -> Node:
	# Get specific component by type
	return input_components.get(input_type)

func has_component(input_type: InputType) -> bool:
	# Check if component is registered
	return input_components.has(input_type)

func force_input_type(input_type: InputType):
	# Allow manual override of input type
	switch_to_input_type(input_type)

func reset_to_direct_control():
	# Force return to direct control
	force_input_type(InputType.DIRECT)

# ===== DEBUG =====

func get_debug_info() -> Dictionary:
	var component_names = {}
	for type in input_components:
		var component = input_components[type]
		component_names[get_input_type_name(type)] = component.name if component else "null"
	
	return {
		"active_input": get_input_type_name(active_input_type),
		"previous_input": get_input_type_name(previous_input_type),
		"registered_components": component_names,
		"activity_times": last_activity_times,
		"mouse_mode": Input.mouse_mode
	}
