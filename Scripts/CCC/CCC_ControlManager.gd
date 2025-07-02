# CCC_ControlManager.gd - Phase 1A: INPUT GATEWAY
extends Node
class_name CCC_ControlManager

# === INPUT CAPTURE (All input comes here) ===
@export_group("Input Settings")
@export var mouse_sensitivity = 1.0
@export var input_deadzone = 0.05
@export var movement_update_frequency = 60

# === CONTROL CONFIGURATION ===
enum ControlType {
	DIRECT,        # WASD/Gamepad direct control only
	TARGET_BASED,  # Click-to-move only
	HYBRID,        # Both WASD and click (current implementation)
	GESTURAL       # Pattern-based input (future)
}

var current_control_type: ControlType = ControlType.HYBRID

# === COMMAND SIGNALS ===
signal movement_command(direction: Vector2, magnitude: float)
signal jump_command()
signal sprint_command(enabled: bool)
signal camera_command(type: String, data: Dictionary)

# === INPUT STATE ===
var wasd_input: Vector2
var click_input: Vector2
var is_sprint_held: bool = false
var movement_update_timer: float = 0.0
var movement_update_interval: float

# === INPUT COMPONENTS ===
var input_components: Array[Node] = []

# === REFERENCES ===
var camera_rig: Node
var character: CharacterBody3D

func _ready():
	setup_references()
	setup_input_components()
	movement_update_interval = 1.0 / movement_update_frequency
	print("✅ CCC_ControlManager: Input Gateway established")

func setup_references():
	"""Setup character and camera references"""
	character = get_parent() as CharacterBody3D
	camera_rig = get_node_or_null("../../CAMERARIG")
	
	if not character:
		push_error("CCC_ControlManager: No CharacterBody3D parent found!")
	if not camera_rig:
		push_warning("CCC_ControlManager: No camera rig found")

func setup_input_components():
	"""Find and setup input components"""
	call_deferred("find_input_components")

func find_input_components():
	"""Find click navigation and other input components"""
	input_components.clear()
	
	# Look for input components in character
	if character:
		for child in character.get_children():
			if child.has_method("get_movement_input"):
				input_components.append(child)
	
	print("📋 CCC_ControlManager: Found ", input_components.size(), " input components")

# === CENTRAL INPUT PROCESSING ===

func _input(event):
	"""Central input processing - ALL input types"""
	process_all_input(event)

func _physics_process(delta):
	"""Process continuous input"""
	process_continuous_input(delta)

func process_all_input(event):
	"""Process keyboard, mouse, and gamepad events"""
	# Keyboard input
	if event is InputEventKey:
		handle_keyboard_input(event)
	
	# Mouse input  
	elif event is InputEventMouse:
		handle_mouse_input(event)
	
	# Gamepad input
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		handle_gamepad_input(event)

func handle_keyboard_input(event):
	"""Process keyboard events"""
	if event.is_action_pressed("jump"):
		emit_jump_command()
	elif event.is_action_pressed("sprint"):
		is_sprint_held = true
		emit_sprint_command(true)
	elif event.is_action_released("sprint"):
		is_sprint_held = false
		emit_sprint_command(false)

func handle_mouse_input(event):
	"""Process mouse events"""
	if event is InputEventMouseButton:
		handle_mouse_clicks(event)
	elif event is InputEventMouseMotion:
		handle_mouse_movement(event)

func handle_mouse_clicks(event):
	"""Handle mouse click events"""
	if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Process click navigation
		var world_position = get_click_world_position(event.position)
		if world_position != Vector3.ZERO:
			emit_camera_command("click_navigation", {"target": world_position})

func handle_mouse_movement(event):
	"""Handle mouse movement for camera"""
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mouse_delta = event.relative * mouse_sensitivity
		emit_camera_command("mouse_look", {"delta": mouse_delta})

func handle_gamepad_input(event):
	"""Process gamepad events"""
	# Gamepad input handling
	pass

func process_continuous_input(delta):
	"""Process continuous input (WASD, analog sticks)"""
	movement_update_timer += delta
	
	if movement_update_timer >= movement_update_interval:
		movement_update_timer = 0.0
		
		# Get input from all sources
		wasd_input = get_wasd_input()
		click_input = get_click_navigation_input()
		
		# INPUT PRIORITY RESOLUTION
		var final_input = resolve_input_priority(wasd_input, click_input)
		
		if final_input.length() > input_deadzone:
			emit_movement_command(final_input, final_input.length())

# === INPUT COLLECTION ===

func get_wasd_input() -> Vector2:
	"""Get raw WASD input"""
	return Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

func get_click_navigation_input() -> Vector2:
	"""Get input from click navigation components"""
	for component in input_components:
		if is_component_active(component):
			var component_input = component.get_movement_input()
			if component_input and component_input.length() > input_deadzone:
				return component_input
	
	return Vector2.ZERO

func get_click_world_position(screen_pos: Vector2) -> Vector3:
	"""Convert screen position to world position"""
	if not camera_rig:
		return Vector3.ZERO
	
	var camera = camera_rig.get_node_or_null("SpringArm3D/Camera3D") as Camera3D
	if not camera:
		return Vector3.ZERO
	
	var from = camera.project_ray_origin(screen_pos)
	var to = from + camera.project_ray_normal(screen_pos) * 1000
	
	var space_state = character.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)
	
	if result:
		return result.position
	
	return Vector3.ZERO

# === INPUT PRIORITY RESOLUTION ===

func resolve_input_priority(wasd: Vector2, click: Vector2) -> Vector2:
	"""Resolve input priority between WASD and click navigation"""
	match current_control_type:
		ControlType.DIRECT:
			return wasd
		ControlType.TARGET_BASED:
			return click
		ControlType.HYBRID:
			# WASD overrides click navigation
			if wasd.length() > input_deadzone:
				cancel_click_navigation()
				return wasd
			else:
				return click
		_:
			return wasd

func cancel_click_navigation():
	"""Cancel all click navigation"""
	for component in input_components:
		if component and component.has_method("cancel_input"):
			component.cancel_input()

# === COMMAND EMISSION ===

func emit_movement_command(direction: Vector2, magnitude: float):
	"""Emit movement command"""
	movement_command.emit(direction, magnitude)

func emit_jump_command():
	"""Emit jump command"""
	jump_command.emit()

func emit_sprint_command(enabled: bool):
	"""Emit sprint command"""
	sprint_command.emit(enabled)

func emit_camera_command(type: String, data: Dictionary):
	"""Emit camera command"""
	camera_command.emit(type, data)

# === UTILITY METHODS ===

func is_component_active(component: Node) -> bool:
	"""Check if input component is active"""
	return is_instance_valid(component) and component.has_method("is_active") and component.is_active()

func configure_control_type(control_type: ControlType):
	"""Configure the control scheme"""
	var old_type = current_control_type
	current_control_type = control_type
	
	print("🎮 CCC_ControlManager: Control type changed from ", ControlType.keys()[old_type], " to ", ControlType.keys()[control_type])
	
	# Apply immediate changes based on control type
	match control_type:
		ControlType.DIRECT:
			cancel_click_navigation()
			print("   → Direct control: WASD/gamepad only")
		ControlType.TARGET_BASED:
			print("   → Target-based control: Click navigation only")
		ControlType.HYBRID:
			print("   → Hybrid control: WASD overrides click navigation")

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get comprehensive debug information"""
	return {
		"control_type": ControlType.keys()[current_control_type],
		"wasd_input": wasd_input,
		"click_input": click_input,
		"resolved_input": resolve_input_priority(wasd_input, click_input),
		"input_deadzone": input_deadzone,
		"sprint_held": is_sprint_held,
		"input_components": input_components.size()
	}
