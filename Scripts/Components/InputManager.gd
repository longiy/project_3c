# InputManager.gd - Action-based input handling
extends Node
class_name InputManager

@export_group("Input Settings")
@export var input_deadzone = 0.05
@export var input_smoothing = 12.0

# Action system integration
var action_system: ActionSystem
var character: CharacterBody3D

# Movement input (still handled directly for responsiveness)
var smoothed_input = Vector2.ZERO
var raw_input_direction = Vector2.ZERO

# Input tracking for movement
var input_start_time = 0.0
var is_input_active = false

# Component references for non-movement input
var input_components: Array[Node] = []

func _ready():
	character = get_parent() as CharacterBody3D
	if not character:
		push_error("InputManager must be child of CharacterBody3D")
		return
	
	# Find action system
	action_system = character.get_node_or_null("ActionSystem")
	if not action_system:
		push_error("InputManager requires ActionSystem as sibling")
		return
	
	# Find input components automatically
	call_deferred("find_input_components")

func _input(event):
	"""Handle immediate input detection for actions"""
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				action_system.request_action("jump")
			KEY_ENTER when Input.is_action_pressed("reset"):
				action_system.request_action("reset")
	
	# Handle modifier keys for movement modes
	if event.is_action_pressed("sprint"):
		action_system.request_action("sprint_start")
	elif event.is_action_released("sprint"):
		action_system.request_action("sprint_end")
	
	if event.is_action_pressed("walk"):
		action_system.request_action("slow_walk_start")
	elif event.is_action_released("walk"):
		action_system.request_action("slow_walk_end")

func _physics_process(delta):
	"""Handle movement input (needs to be responsive)"""
	update_movement_input(delta)

func find_input_components():
	"""Find input components for click navigation, gamepad, etc."""
	input_components.clear()
	
	for child in character.get_children():
		if child == self:
			continue
		if child.has_method("get_movement_input"):
			input_components.append(child)
			print("📝 InputManager: Found input component: ", child.name)
	
	print("📝 InputManager: Total input components: ", input_components.size())

func update_movement_input(delta):
	"""Handle movement input with smoothing"""
	raw_input_direction = get_current_movement_input()
	var has_input_now = raw_input_direction.length() > input_deadzone
	
	# Track input timing
	if has_input_now and not is_input_active:
		input_start_time = Time.get_ticks_msec() / 1000.0
		is_input_active = true
	elif not has_input_now and is_input_active:
		is_input_active = false
	
	# Apply deadzone
	if raw_input_direction.length() < input_deadzone:
		raw_input_direction = Vector2.ZERO
	
	# Apply smoothing
	smoothed_input = smoothed_input.lerp(raw_input_direction, input_smoothing * delta)
	if smoothed_input.length() < input_deadzone:
		smoothed_input = Vector2.ZERO

func get_current_movement_input() -> Vector2:
	"""Get movement input from WASD or components"""
	# WASD always wins
	var wasd_input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if wasd_input.length() > input_deadzone:
		cancel_all_input_components()
		return wasd_input
	
	# Check input components (click navigation, gamepad, etc.)
	for component in input_components:
		if not is_instance_valid(component):
			continue
		
		var is_active = false
		if component.has_method("is_active"):
			is_active = component.is_active()
		elif component.has_method("get_movement_input"):
			var test_input = component.get_movement_input()
			if test_input != null:  # Add null check
				is_active = test_input.length() > input_deadzone
		
		if is_active and component.has_method("get_movement_input"):
			var component_input = component.get_movement_input()
			return component_input if component_input != null else Vector2.ZERO
	
	return Vector2.ZERO

func cancel_all_input_components():
	"""Cancel input components when WASD takes over"""
	for component in input_components:
		if component.has_method("cancel_input"):
			component.cancel_input()

# === MOVEMENT INPUT API (for character controller) ===

func get_smoothed_input() -> Vector2:
	return smoothed_input

func get_raw_input() -> Vector2:
	return raw_input_direction

func get_input_duration() -> float:
	if is_input_active:
		return (Time.get_ticks_msec() / 1000.0) - input_start_time
	return 0.0

func is_input_sustained(min_duration: float = 0.3) -> bool:
	return get_input_duration() >= min_duration

func should_process_input() -> bool:
	if not character:
		return false
	
	return is_input_active and (
		get_input_duration() >= 0.08 or 
		character.get_movement_speed() > 0.5
	)

func is_input_active_now() -> bool:
	return is_input_active

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	var base_info = {
		"raw_input": raw_input_direction,
		"smoothed_input": smoothed_input,
		"input_duration": get_input_duration(),
		"is_active": is_input_active,
		"sustained": is_input_sustained(),
		"should_process": should_process_input(),
		"component_count": input_components.size(),
		"active_components": get_active_components()
	}
	
	# Add action system debug info
	if action_system:
		base_info["action_system"] = action_system.get_debug_info()
	
	return base_info

func get_active_components() -> Array[String]:
	var active: Array[String] = []
	for component in input_components:
		if component.has_method("is_active") and component.is_active():
			active.append(component.name)
	return active
