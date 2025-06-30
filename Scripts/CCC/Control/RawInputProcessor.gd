# RawInputProcessor.gd - Converts raw input events to structured data
extends Node
class_name RawInputProcessor

# === SIGNALS ===
signal discrete_action(action_name: String)
signal click_navigation_event(event_type: String, data: Dictionary)
signal keyboard_movement_changed(direction: Vector2, magnitude: float)

# === SETTINGS ===
@export var input_deadzone = 0.05
@export var enable_keyboard_input = true
@export var enable_mouse_input = true
@export var enable_gamepad_input = true

# === STATE ===
var last_keyboard_input = Vector2.ZERO
var is_click_dragging = false

# Input timing
var last_keyboard_change_time = 0.0
var keyboard_update_threshold = 0.016  # ~60fps

func _ready():
	print("✅ RawInputProcessor: Ready to process input events")

func _input(event):
	"""Process all raw input events and convert to structured signals"""
	process_discrete_actions(event)
	process_mouse_events(event)
	# Note: Keyboard input processed in _physics_process for smoother movement

func _physics_process(_delta):
	"""Process continuous input that needs smooth updates"""
	if enable_keyboard_input:
		process_keyboard_movement()

# === DISCRETE ACTION PROCESSING ===

func process_discrete_actions(event):
	"""Process discrete button press actions"""
	if not event is InputEventKey and not event is InputEventJoypadButton:
		return
	
	# Jump
	if event.is_action_pressed("jump"):
		discrete_action.emit("jump")
	
	# Reset
	elif event.is_action_pressed("reset"):
		discrete_action.emit("reset")
	
	# Sprint
	elif event.is_action_pressed("sprint"):
		discrete_action.emit("sprint_start")
	elif event.is_action_released("sprint"):
		discrete_action.emit("sprint_end")
	
	# Slow walk
	elif event.is_action_pressed("walk"):
		discrete_action.emit("slow_walk_start")
	elif event.is_action_released("walk"):
		discrete_action.emit("slow_walk_end")

# === MOUSE INPUT PROCESSING ===

func process_mouse_events(event):
	"""Process mouse events for click navigation"""
	if not enable_mouse_input:
		return
	
	if event is InputEventMouseButton:
		process_mouse_button(event)
	elif event is InputEventMouseMotion:
		process_mouse_motion(event)

func process_mouse_button(event: InputEventMouseButton):
	"""Process mouse button events"""
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Start click/drag
			is_click_dragging = true
			click_navigation_event.emit("click_start", {
				"screen_position": event.position,
				"timestamp": Time.get_ticks_msec()
			})
		else:
			# End click/drag
			is_click_dragging = false
			click_navigation_event.emit("click_end", {
				"screen_position": event.position,
				"timestamp": Time.get_ticks_msec()
			})

func process_mouse_motion(event: InputEventMouseMotion):
	"""Process mouse motion for drag navigation"""
	if is_click_dragging:
		click_navigation_event.emit("drag_update", {
			"screen_position": event.position,
			"relative_motion": event.relative,
			"timestamp": Time.get_ticks_msec()
		})

# === KEYBOARD MOVEMENT PROCESSING ===

func process_keyboard_movement():
	"""Process WASD keyboard movement with smooth updates"""
	if not enable_keyboard_input:
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Get raw keyboard input
	var raw_input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var magnitude = raw_input.length()
	
	# Apply deadzone
	var processed_input = raw_input if magnitude > input_deadzone else Vector2.ZERO
	
	# Check if input changed significantly
	var input_changed = processed_input.distance_to(last_keyboard_input) > 0.01
	var time_threshold_passed = current_time - last_keyboard_change_time > keyboard_update_threshold
	
	if input_changed or time_threshold_passed:
		last_keyboard_input = processed_input
		last_keyboard_change_time = current_time
		
		keyboard_movement_changed.emit(processed_input, processed_input.length())

# === GAMEPAD PROCESSING (Future Extension) ===

func process_gamepad_movement() -> Vector2:
	"""Process gamepad movement input"""
	if not enable_gamepad_input:
		return Vector2.ZERO
	
	# Get gamepad input
	var gamepad_input = Input.get_vector("gamepad_left", "gamepad_right", "gamepad_up", "gamepad_down")
	var magnitude = gamepad_input.length()
	
	# Apply deadzone
	return gamepad_input if magnitude > input_deadzone else Vector2.ZERO

# === CONFIGURATION ===

func set_input_deadzone(deadzone: float):
	"""Update input deadzone"""
	input_deadzone = deadzone

func enable_input_type(input_type: String, enabled: bool):
	"""Enable/disable specific input types"""
	match input_type:
		"keyboard":
			enable_keyboard_input = enabled
		"mouse":
			enable_mouse_input = enabled
		"gamepad":
			enable_gamepad_input = enabled

# === PUBLIC API ===

func get_current_keyboard_input() -> Vector2:
	"""Get current processed keyboard input"""
	return last_keyboard_input

func is_dragging() -> bool:
	"""Check if currently dragging with mouse"""
	return is_click_dragging

func cancel_input():
	"""Cancel all current input states"""
	last_keyboard_input = Vector2.ZERO
	is_click_dragging = false

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get debug information about input processing"""
	return {
		"enable_keyboard": enable_keyboard_input,
		"enable_mouse": enable_mouse_input,
		"enable_gamepad": enable_gamepad_input,
		"input_deadzone": input_deadzone,
		"current_keyboard_input": last_keyboard_input,
		"keyboard_magnitude": last_keyboard_input.length(),
		"is_click_dragging": is_click_dragging,
		"last_keyboard_change": last_keyboard_change_time,
		"raw_keyboard_input": Input.get_vector("move_left", "move_right", "move_forward", "move_backward") if enable_keyboard_input else Vector2.ZERO
	}
