# InputManagerComponent.gd - Central input routing and mode management
extends Node
class_name CCC_InputManagerComponent

# === SIGNALS ===
signal input_mode_changed(new_mode: String)
signal movement_input(direction: Vector2)
signal jump_input()
signal mouse_toggle_input()

# === EXPORTS ===
@export_group("Required References")
@export var direct_control_component: Node  # DirectControlComponent
@export var target_control_component: Node  # TargetControlComponent
@export var config_component: Node  # 3CConfigComponent

@export_group("Input Settings")
@export var enable_mode_switching: bool = true
@export var enable_debug_output: bool = false

# === INPUT MODES ===
enum InputMode {
	DIRECT,      # WASD only
	TARGET,      # Click only
	HYBRID       # Both available
}

var current_mode: InputMode = InputMode.HYBRID
var input_enabled: bool = true

func _ready():
	validate_setup()
	
	if enable_debug_output:
		print("InputManagerComponent: Initialized with mode: ", InputMode.keys()[current_mode])

func validate_setup():
	"""Validate required references"""
	if not direct_control_component:
		push_error("InputManagerComponent: direct_control_component reference required")
	
	if not target_control_component:
		push_error("InputManagerComponent: target_control_component reference required")
	
	if not config_component:
		push_error("InputManagerComponent: config_component reference required")

func _input(event):
	"""Route input events to appropriate control components"""
	if not input_enabled:
		return
	
	# Handle mode switching first
	if enable_mode_switching and event.is_action_pressed("toggle_camera_mode"):
		handle_mode_toggle()
		return
	
	# Route input based on current mode
	match current_mode:
		InputMode.DIRECT:
			route_to_direct_control(event)
		
		InputMode.TARGET:
			route_to_target_control(event)
		
		InputMode.HYBRID:
			route_to_hybrid_control(event)

# === INPUT ROUTING ===

func route_to_direct_control(event: InputEvent):
	"""Route input to direct control component only"""
	if direct_control_component and direct_control_component.has_method("handle_input"):
		direct_control_component.handle_input(event)

func route_to_target_control(event: InputEvent):
	"""Route input to target control component only"""
	if target_control_component and target_control_component.has_method("handle_input"):
		target_control_component.handle_input(event)

func route_to_hybrid_control(event: InputEvent):
	"""Route input to both control components"""
	# Direct control gets priority for movement
	if direct_control_component and direct_control_component.has_method("handle_input"):
		direct_control_component.handle_input(event)
	
	# Target control handles clicks
	if target_control_component and target_control_component.has_method("handle_input"):
		target_control_component.handle_input(event)

# === PROCESSED INPUT HANDLING ===

func _process(_delta):
	"""Process continuous input like WASD"""
	if not input_enabled:
		return
	
	# Get movement input vector
	var movement_vector = get_movement_input_vector()
	
	# Emit movement input if there's any
	if movement_vector.length() > 0:
		movement_input.emit(movement_vector)
	
	# Handle jump input
	if Input.is_action_just_pressed("jump"):
		jump_input.emit()
		if enable_debug_output:
			print("InputManagerComponent: Jump input detected")
	
	# Handle mouse toggle
	if Input.is_action_just_pressed("toggle_camera_mode"):
		mouse_toggle_input.emit()
		if enable_debug_output:
			print("InputManagerComponent: Mouse toggle input detected")

func get_movement_input_vector() -> Vector2:
	"""Get WASD movement input as Vector2"""
	var input_vector = Vector2.ZERO
	
	# Only process WASD in direct or hybrid modes
	if current_mode == InputMode.TARGET:
		return input_vector
	
	if Input.is_action_pressed("move_forward"):
		input_vector.y += 1.0
	if Input.is_action_pressed("move_backward"):
		input_vector.y -= 1.0
	if Input.is_action_pressed("move_left"):
		input_vector.x -= 1.0
	if Input.is_action_pressed("move_right"):
		input_vector.x += 1.0
	
	# Apply deadzone
	var deadzone = get_config_value("input_deadzone", 0.1)
	if input_vector.length() < deadzone:
		input_vector = Vector2.ZERO
	else:
		input_vector = input_vector.normalized()
	
	return input_vector

# === MODE MANAGEMENT ===

func handle_mode_toggle():
	"""Handle input mode toggle"""
	match current_mode:
		InputMode.DIRECT:
			set_input_mode(InputMode.HYBRID)
		InputMode.TARGET:
			set_input_mode(InputMode.HYBRID)
		InputMode.HYBRID:
			set_input_mode(InputMode.DIRECT)  # Or cycle to TARGET

func set_input_mode(new_mode: InputMode):
	"""Set input mode"""
	if new_mode != current_mode:
		current_mode = new_mode
		input_mode_changed.emit(InputMode.keys()[current_mode])
		
		if enable_debug_output:
			print("InputManagerComponent: Input mode changed to ", InputMode.keys()[current_mode])

# === PUBLIC API ===

func get_current_mode() -> InputMode:
	"""Get current input mode"""
	return current_mode

func get_current_mode_name() -> String:
	"""Get current input mode name"""
	return InputMode.keys()[current_mode]

func is_direct_mode_active() -> bool:
	"""Check if direct mode is active"""
	return current_mode == InputMode.DIRECT or current_mode == InputMode.HYBRID

func is_target_mode_active() -> bool:
	"""Check if target mode is active"""
	return current_mode == InputMode.TARGET or current_mode == InputMode.HYBRID

func set_input_enabled(enabled: bool):
	"""Enable/disable input processing"""
	input_enabled = enabled
	
	if enable_debug_output:
		print("InputManagerComponent: Input enabled set to ", enabled)

func force_input_mode(mode: InputMode):
	"""Force specific input mode (for scripted sequences)"""
	set_input_mode(mode)

# === CONFIGURATION ===

func get_config_value(property_name: String, default_value):
	"""Get configuration value safely"""
	if config_component and config_component.has_method("get_config_value"):
		return config_component.get_config_value(property_name, default_value)
	return default_value

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get debug information about input manager"""
	return {
		"current_mode": InputMode.keys()[current_mode],
		"input_enabled": input_enabled,
		"mode_switching_enabled": enable_mode_switching,
		"direct_mode_active": is_direct_mode_active(),
		"target_mode_active": is_target_mode_active(),
		"current_movement_input": get_movement_input_vector()
	}
