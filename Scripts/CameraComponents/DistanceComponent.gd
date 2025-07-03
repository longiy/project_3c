# DistanceComponent.gd
# Handles camera distance adjustments based on input type
# Refactored: Uses InputCore instead of InputPriorityManager

extends Node
class_name DistanceComponent

# Export references for inspector assignment
@export_group("System References")
@export var input_core: InputCore
@export var spring_arm: SpringArm3D
@export var camera_system: CameraSystem

@export_group("Distance Settings")
@export var default_distance: float = 4.0
@export var direct_input_distance: float = 4.0
@export var target_input_distance: float = 6.0
@export var gamepad_distance: float = 5.0
@export var distance_smoothing: float = 8.0

@export_group("Zoom Settings")
@export var enable_scroll_zoom: bool = true
@export var zoom_speed: float = 0.5
@export var min_distance: float = 1.0
@export var max_distance: float = 10.0

@export_group("Debug")
@export var debug_enabled: bool = false

# Internal state
var current_distance: float
var target_distance: float
var last_input_type: InputCore.InputType

func _ready():
	if not verify_references():
		return
	
	setup_component()
	
	if debug_enabled:
		print("DistanceComponent: Initialized")

func verify_references() -> bool:
	var missing = []
	
	if not input_core:
		missing.append("input_core")
	if not spring_arm:
		missing.append("spring_arm")
	
	if missing.size() > 0:
		push_error("DistanceComponent: Missing references: " + str(missing))
		push_error("Please assign missing references in the Inspector")
		return false
	
	return true

func setup_component():
	# Initialize distances
	current_distance = default_distance
	target_distance = default_distance
	
	if spring_arm:
		spring_arm.spring_length = current_distance
	
	# Set up processing
	set_process(true)
	
	# Get initial input type
	if input_core:
		last_input_type = input_core.get_active_input_type()
		update_distance_for_input_type(last_input_type)

func _process(delta):
	if not input_core:
		return
	
	# Check for input type changes
	var current_input_type = input_core.get_active_input_type()
	if current_input_type != last_input_type:
		on_input_type_changed(current_input_type)
		last_input_type = current_input_type
	
	# Smooth distance transitions
	update_distance_smoothing(delta)

func _input(event):
	if not enable_scroll_zoom:
		return
	
	# Handle mouse wheel zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_in()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_out()

# ===== INPUT TYPE HANDLING =====

func on_input_type_changed(new_input_type: InputCore.InputType):
	update_distance_for_input_type(new_input_type)
	
	if debug_enabled:
		var type_name = input_core.get_input_type_name(new_input_type)
		print("DistanceComponent: Input type changed to ", type_name)

func update_distance_for_input_type(input_type: InputCore.InputType):
	# Set target distance based on input type
	match input_type:
		InputCore.InputType.DIRECT:
			target_distance = direct_input_distance
		InputCore.InputType.TARGET:
			target_distance = target_input_distance
		InputCore.InputType.GAMEPAD:
			target_distance = gamepad_distance
		_:
			target_distance = default_distance

# ===== DISTANCE SMOOTHING =====

func update_distance_smoothing(delta: float):
	if not spring_arm:
		return
	
	# Smooth transition to target distance
	current_distance = lerp(current_distance, target_distance, distance_smoothing * delta)
	
	# Clamp to min/max values
	current_distance = clamp(current_distance, min_distance, max_distance)
	
	# Apply to spring arm
	spring_arm.spring_length = current_distance

# ===== ZOOM CONTROLS =====

func zoom_in():
	var new_distance = target_distance - zoom_speed
	set_target_distance(new_distance)
	
	if debug_enabled:
		print("DistanceComponent: Zoom in to ", new_distance)

func zoom_out():
	var new_distance = target_distance + zoom_speed
	set_target_distance(new_distance)
	
	if debug_enabled:
		print("DistanceComponent: Zoom out to ", new_distance)

func set_target_distance(distance: float):
	target_distance = clamp(distance, min_distance, max_distance)

# ===== PUBLIC API =====

func get_current_distance() -> float:
	return current_distance

func get_target_distance() -> float:
	return target_distance

func set_distance_immediately(distance: float):
	var clamped_distance = clamp(distance, min_distance, max_distance)
	current_distance = clamped_distance
	target_distance = clamped_distance
	
	if spring_arm:
		spring_arm.spring_length = current_distance

func reset_to_default():
	set_target_distance(default_distance)

func set_distance_for_input_type(input_type: InputCore.InputType, distance: float):
	# Allow runtime adjustment of input-specific distances
	match input_type:
		InputCore.InputType.DIRECT:
			direct_input_distance = clamp(distance, min_distance, max_distance)
		InputCore.InputType.TARGET:
			target_input_distance = clamp(distance, min_distance, max_distance)
		InputCore.InputType.GAMEPAD:
			gamepad_distance = clamp(distance, min_distance, max_distance)
	
	# Update current target if this is the active input type
	if input_core and input_core.get_active_input_type() == input_type:
		target_distance = distance

# ===== CONFIGURATION =====

func set_smoothing_speed(speed: float):
	distance_smoothing = clamp(speed, 1.0, 20.0)

func set_zoom_speed(speed: float):
	zoom_speed = clamp(speed, 0.1, 2.0)

func set_distance_limits(min_dist: float, max_dist: float):
	min_distance = max(0.1, min_dist)
	max_distance = max(min_distance + 0.1, max_dist)
	
	# Re-clamp current values
	current_distance = clamp(current_distance, min_distance, max_distance)
	target_distance = clamp(target_distance, min_distance, max_distance)

# ===== DEBUG =====

func get_debug_info() -> Dictionary:
	var input_type_name = "Unknown"
	if input_core:
		input_type_name = input_core.get_input_type_name(input_core.get_active_input_type())
	
	return {
		"current_distance": current_distance,
		"target_distance": target_distance,
		"input_type": input_type_name,
		"spring_arm_length": spring_arm.spring_length if spring_arm else 0.0,
		"zoom_enabled": enable_scroll_zoom,
		"distance_limits": {"min": min_distance, "max": max_distance}
	}
