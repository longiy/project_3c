# DistanceComponent.gd
# CAMERA Distance Component for SpringArm3D zoom control
# PHASE 4: Updated to reference InputCore directly, removed InputPriorityManager dependency

extends Node
class_name DistanceComponent

# Export references for modularity
@export var camera_system: CameraSystem
@export var input_core: InputCore
@export var direct_control_component: DirectControlComponent

# Distance settings
@export_group("Distance Settings")
@export var zoom_speed: float = 1.0
@export var zoom_smoothing: float = 8.0
@export var min_distance: float = 1.0
@export var max_distance: float = 10.0
@export var default_distance: float = 4.0

@export_group("Input Settings")
@export var mouse_wheel_enabled: bool = true
@export var gamepad_zoom_enabled: bool = true
@export var keyboard_zoom_enabled: bool = true

# Zoom input tracking
var target_distance: float
var zoom_input_velocity: float = 0.0
var last_zoom_time: float = 0.0

# Input actions for keyboard zoom
var zoom_in_action: String = "zoom_in"    # + key
var zoom_out_action: String = "zoom_out"  # - key

func _ready():
	# Fallback to node paths if exports not set
	if not camera_system:
		camera_system = get_node("../../") as CameraSystem
	
	if not camera_system:
		push_error("DistanceComponent: CAMERA system not found")
		return
	
	if not input_core:
		input_core = get_node("../../../CONTROL/InputCore")
	
	# Initialize distance
	target_distance = default_distance
	
	# Connect to input signals if available
	connect_input_signals()
	
	print("DistanceComponent: Initialized")

func _input(event):
	# Handle mouse wheel zoom
	if mouse_wheel_enabled and event is InputEventMouseButton:
		handle_mouse_wheel_zoom(event)

func _process(delta):
	# Handle continuous keyboard zoom
	if keyboard_zoom_enabled:
		handle_keyboard_zoom(delta)
	
	# Handle gamepad zoom
	if gamepad_zoom_enabled:
		handle_gamepad_zoom(delta)
	
	# Update camera distance smoothly
	update_distance_smoothing(delta)

func connect_input_signals():
	# Connect to control components for integrated zoom input
	if not direct_control_component:
		direct_control_component = get_node("../../../CONTROL/ControlComponents/DirectControlComponent")
	
	if direct_control_component and direct_control_component.has_signal("action_command"):
		direct_control_component.action_command.connect(_on_action_command)

func handle_mouse_wheel_zoom(event: InputEventMouseButton):
	if event.pressed:
		var zoom_delta = 0.0
		
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_delta = -zoom_speed
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_delta = zoom_speed
		
		if zoom_delta != 0.0:
			apply_zoom_delta(zoom_delta)
			update_zoom_activity()

func handle_keyboard_zoom(delta: float):
	var zoom_delta = 0.0
	
	if Input.is_action_pressed(zoom_in_action):
		zoom_delta = -zoom_speed * delta * 3.0  # Continuous zoom
	elif Input.is_action_pressed(zoom_out_action):
		zoom_delta = zoom_speed * delta * 3.0
	
	if zoom_delta != 0.0:
		apply_zoom_delta(zoom_delta)
		update_zoom_activity()

func handle_gamepad_zoom(delta: float):
	if not input_core:
		return
	
	# Use gamepad triggers for zoom (assuming RT=zoom out, LT=zoom in)
	var zoom_out = Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT)
	var zoom_in = Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT)
	
	var zoom_delta = 0.0
	
	# Apply deadzone
	var trigger_deadzone = 0.1
	if zoom_out > trigger_deadzone:
		zoom_delta = zoom_speed * zoom_out * delta * 2.0
	elif zoom_in > trigger_deadzone:
		zoom_delta = -zoom_speed * zoom_in * delta * 2.0
	
	if zoom_delta != 0.0:
		apply_zoom_delta(zoom_delta)
		update_zoom_activity()
		
		# UPDATED: Notify InputCore of gamepad activity
		if input_core.has_method("set_active_input"):
			input_core.set_active_input(InputCore.InputType.GAMEPAD)

func apply_zoom_delta(delta: float):
	# Apply zoom change with velocity for smooth feel
	zoom_input_velocity += delta
	target_distance = clamp(target_distance + delta, min_distance, max_distance)

func update_distance_smoothing(delta: float):
	# Apply velocity damping
	zoom_input_velocity = lerp(zoom_input_velocity, 0.0, 5.0 * delta)
	
	# Get current distance from camera system
	var current_distance = camera_system.get_current_distance()
	
	# Apply smooth zoom if distance changed
	if abs(target_distance - current_distance) > 0.01:
		camera_system.set_distance(target_distance, true)

func update_zoom_activity():
	last_zoom_time = Time.get_ticks_msec() / 1000.0

func _on_action_command(action: String, pressed: bool):
	# Handle zoom actions from other input components
	if not pressed:
		return
	
	match action:
		"zoom_in":
			apply_zoom_delta(-zoom_speed * 0.5)
			update_zoom_activity()
		"zoom_out":
			apply_zoom_delta(zoom_speed * 0.5)
			update_zoom_activity()

# === PUBLIC API ===

func set_zoom_speed(speed: float):
	zoom_speed = clamp(speed, 0.1, 5.0)

func set_distance_range(min_dist: float, max_dist: float):
	min_distance = min_dist
	max_distance = max_dist
	target_distance = clamp(target_distance, min_distance, max_distance)

func set_target_distance(distance: float, smooth: bool = true):
	target_distance = clamp(distance, min_distance, max_distance)
	if not smooth:
		camera_system.set_distance(target_distance, false)

func get_target_distance() -> float:
	return target_distance

func get_zoom_activity_level() -> float:
	var current_time = Time.get_ticks_msec() / 1000.0
	var time_since_zoom = current_time - last_zoom_time
	return max(0.0, 1.0 - (time_since_zoom / 2.0))  # Activity decays over 2 seconds

func reset_to_default():
	target_distance = default_distance
	zoom_input_velocity = 0.0

# === CONFIGURATION API ===

func enable_mouse_wheel(enabled: bool):
	mouse_wheel_enabled = enabled

func enable_gamepad_zoom(enabled: bool):
	gamepad_zoom_enabled = enabled

func enable_keyboard_zoom(enabled: bool):
	keyboard_zoom_enabled = enabled

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	return {
		"target_distance": target_distance,
		"current_distance": camera_system.get_current_distance() if camera_system else 0.0,
		"zoom_velocity": zoom_input_velocity,
		"activity_level": get_zoom_activity_level(),
		"mouse_wheel_enabled": mouse_wheel_enabled,
		"gamepad_enabled": gamepad_zoom_enabled,
		"keyboard_enabled": keyboard_zoom_enabled
	}
