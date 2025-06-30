# CameraDistanceComponent.gd - Dynamic camera distance control
extends Node
class_name CameraDistanceComponent

# === SIGNALS ===
signal distance_changed(new_distance: float)
signal zoom_input_received(zoom_delta: float)

# === EXPORTS ===
@export_group("Required References")
@export var camera_core: CameraCore
@export var spring_arm: SpringArm3D  # SpringArm3D that controls distance
@export var config_component: Node  # 3CConfigComponent

@export_group("Distance Properties")
@export var enable_smooth_transitions: bool = true
@export var enable_debug_output: bool = false

# === DISTANCE STATE ===
var current_distance: float = 4.0
var target_distance: float = 4.0
var last_emitted_distance: float = 0.0

func _ready():
	validate_setup()
	setup_initial_distance()
	
	if enable_debug_output:
		print("CameraDistanceComponent: Initialized")

func validate_setup():
	"""Validate required references"""
	if not camera_core:
		push_error("CameraDistanceComponent: camera_core reference required")
	
	if not spring_arm:
		push_error("CameraDistanceComponent: spring_arm reference required")
	
	if not config_component:
		push_error("CameraDistanceComponent: config_component reference required")

func setup_initial_distance():
	"""Set initial camera distance"""
	var default_distance = get_config_value("camera_distance", 4.0)
	current_distance = default_distance
	target_distance = default_distance
	
	if spring_arm:
		spring_arm.spring_length = current_distance
	
	last_emitted_distance = current_distance

func _input(event):
	"""Handle zoom input"""
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				handle_zoom_input(-get_config_value("zoom_speed", 0.5))
			MOUSE_BUTTON_WHEEL_DOWN:
				handle_zoom_input(get_config_value("zoom_speed", 0.5))

func _process(delta):
	"""Update distance smoothing"""
	if enable_smooth_transitions:
		update_distance_smoothing(delta)
	else:
		current_distance = target_distance
		apply_distance()

# === DISTANCE CONTROL ===

func handle_zoom_input(zoom_delta: float):
	"""Handle zoom input from mouse wheel"""
	set_target_distance(target_distance + zoom_delta)
	zoom_input_received.emit(zoom_delta)
	
	if enable_debug_output:
		print("CameraDistanceComponent: Zoom input received: ", zoom_delta)

func set_target_distance(new_distance: float):
	"""Set target distance with constraints"""
	var min_distance = get_config_value("min_camera_distance", 1.0)
	var max_distance = get_config_value("max_camera_distance", 10.0)
	
	target_distance = clamp(new_distance, min_distance, max_distance)
	
	if enable_debug_output:
		print("CameraDistanceComponent: Target distance set to ", target_distance)

func set_distance_immediate(new_distance: float):
	"""Set distance immediately without smoothing"""
	set_target_distance(new_distance)
	current_distance = target_distance
	apply_distance()

func update_distance_smoothing(delta: float):
	"""Update distance with smoothing"""
	if abs(current_distance - target_distance) < 0.01:
		current_distance = target_distance
	else:
		var smoothing_speed = get_config_value("camera_smoothing", 8.0)
		current_distance = lerp(current_distance, target_distance, smoothing_speed * delta)
	
	apply_distance()

func apply_distance():
	"""Apply current distance to spring arm"""
	if not spring_arm:
		return
	
	spring_arm.spring_length = current_distance
	
	# Emit signal if distance changed significantly
	if abs(current_distance - last_emitted_distance) > 0.05:
		last_emitted_distance = current_distance
		distance_changed.emit(current_distance)

# === STATE-BASED DISTANCE ===

func set_distance_for_state(state_name: String, transition_time: float = 0.0):
	"""Set distance based on character state"""
	var state_distance = get_distance_for_state(state_name)
	
	if transition_time <= 0:
		set_distance_immediate(state_distance)
	else:
		set_target_distance(state_distance)
		# Could implement custom transition timing here

func get_distance_for_state(state_name: String) -> float:
	"""Get appropriate distance for character state"""
	if config_component and config_component.has_method("get_camera_values_for_state"):
		var camera_values = config_component.get_camera_values_for_state(state_name)
		return camera_values.get("distance", get_config_value("camera_distance", 4.0))
	
	# Fallback values
	match state_name.to_lower():
		"idle":
			return get_config_value("idle_distance", 4.0)
		"walking", "walk":
			return get_config_value("walking_distance", 4.0)
		"running", "run":
			return get_config_value("running_distance", 4.5)
		"jumping", "jump":
			return get_config_value("jumping_distance", 4.8)
		"airborne", "falling":
			return get_config_value("airborne_distance", 5.0)
		_:
			return get_config_value("camera_distance", 4.0)

# === PUBLIC API ===

func get_current_distance() -> float:
	"""Get current camera distance"""
	return current_distance

func get_target_distance() -> float:
	"""Get target camera distance"""
	return target_distance

func get_distance_limits() -> Vector2:
	"""Get min/max distance limits as Vector2(min, max)"""
	return Vector2(
		get_config_value("min_camera_distance", 1.0),
		get_config_value("max_camera_distance", 10.0)
	)

func is_at_min_distance() -> bool:
	"""Check if at minimum distance"""
	var min_distance = get_config_value("min_camera_distance", 1.0)
	return abs(current_distance - min_distance) < 0.1

func is_at_max_distance() -> bool:
	"""Check if at maximum distance"""
	var max_distance = get_config_value("max_camera_distance", 10.0)
	return abs(current_distance - max_distance) < 0.1

func reset_to_default_distance():
	"""Reset to default configuration distance"""
	var default_distance = get_config_value("camera_distance", 4.0)
	set_distance_immediate(default_distance)

# === CONFIGURATION ===

func get_config_value(property_name: String, default_value):
	"""Get configuration value safely"""
	if config_component and config_component.has_method("get_config_value"):
		return config_component.get_config_value(property_name, default_value)
	return default_value

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get debug information about distance component"""
	return {
		"current_distance": current_distance,
		"target_distance": target_distance,
		"distance_limits": get_distance_limits(),
		"smooth_transitions": enable_smooth_transitions,
		"at_min_distance": is_at_min_distance(),
		"at_max_distance": is_at_max_distance(),
		"spring_arm_length": spring_arm.spring_length if spring_arm else 0.0
	}
