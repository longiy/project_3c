# InputManager.gd - Handles all input sources and arbitration
extends Node
class_name InputManager

@export_group("Input Settings")
@export var input_deadzone = 0.05
@export var input_smoothing = 12.0
@export var min_input_duration = 0.08

# Input tracking
var input_start_time = 0.0
var is_input_active = false
var smoothed_input = Vector2.ZERO
var raw_input_direction = Vector2.ZERO

# Component references
var character: CharacterBody3D
var input_components: Array[Node] = []

func _ready():
	character = get_parent() as CharacterBody3D
	if not character:
		push_error("InputManager must be child of CharacterBody3D")
		return
	
	# Find input components automatically
	call_deferred("find_input_components")

func _physics_process(delta):
	update_input_tracking(delta)

func find_input_components():
	"""Automatically find input components"""
	input_components.clear()
	
	# Look in character's children for input components
	for child in character.get_children():
		if child == self:
			continue
		# Check if it's an input component (has required methods)
		if child.has_method("get_movement_input"):
			input_components.append(child)
			print("📝 InputManager: Found input component: ", child.name)
	
	print("📝 InputManager: Total input components: ", input_components.size())

func update_input_tracking(delta):
	"""Track input duration and apply smoothing"""
	raw_input_direction = get_current_input()
	var has_input_now = raw_input_direction.length() > input_deadzone
	
	# Track input duration
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

# === PUBLIC API (Used by Character) ===

func get_current_input() -> Vector2:
	"""Input arbitration - WASD wins, then components"""
	# Check WASD first
	var wasd_input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if wasd_input.length() > input_deadzone:
		cancel_all_input_components()
		return wasd_input
	
	# Check input components safely
	for component in input_components:
		if component == null or not is_instance_valid(component):
			continue
		
		# Check if component is active
		var is_active = false
		if component.has_method("is_active"):
			is_active = component.is_active()
		elif component.has_method("get_movement_input"):
			# Fallback: if no is_active method, check if it returns non-zero input
			var test_input = component.get_movement_input()
			is_active = test_input.length() > input_deadzone
		
		if is_active and component.has_method("get_movement_input"):
			return component.get_movement_input()
	
	return Vector2.ZERO

func get_smoothed_input() -> Vector2:
	"""Get current smoothed input"""
	return smoothed_input

func get_raw_input() -> Vector2:
	"""Get current raw input direction"""
	return raw_input_direction

func cancel_all_input_components():
	"""Cancel all active input components"""
	for component in input_components:
		if component.has_method("cancel_input"):
			component.cancel_input()

# === INPUT DURATION TRACKING ===

func get_input_duration() -> float:
	"""Get how long current input has been active"""
	if is_input_active:
		return (Time.get_ticks_msec() / 1000.0) - input_start_time
	return 0.0

func is_input_sustained(min_duration: float = 0.3) -> bool:
	"""Check if input has been sustained for minimum duration"""
	return get_input_duration() >= min_duration

func should_process_input() -> bool:
	"""Check if input should be processed (respects minimum duration)"""
	if not character:
		return false
	
	return is_input_active and (
		get_input_duration() >= min_input_duration or 
		character.get_movement_speed() > 0.5
	)

func is_input_active_now() -> bool:
	"""Check if any input is currently active"""
	return is_input_active

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get debug information"""
	return {
		"raw_input": raw_input_direction,
		"smoothed_input": smoothed_input,
		"input_duration": get_input_duration(),
		"is_active": is_input_active,
		"sustained": is_input_sustained(),
		"should_process": should_process_input(),
		"component_count": input_components.size(),
		"active_components": get_active_components()
	}

func get_active_components() -> Array[String]:
	"""Get names of currently active input components"""
	var active: Array[String] = []
	for component in input_components:
		if component.has_method("is_active") and component.is_active():
			active.append(component.name)
	return active
