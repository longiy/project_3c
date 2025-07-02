# DirectControlComponent.gd
# Handles WASD movement and mouse look input
# Generates standardized commands for CHARACTER and CAMERA systems

extends Node
class_name DirectControlComponent

# Command signals - these drive the CHARACTER and CAMERA systems
signal movement_command(direction: Vector2, magnitude: float)
signal look_command(delta: Vector2)
signal action_command(action: String, pressed: bool)

# Input settings
@export_group("Movement Settings")
@export var movement_deadzone: float = 0.1
@export var movement_smoothing: float = 8.0

@export_group("Mouse Look Settings")
@export var mouse_sensitivity: Vector2 = Vector2(0.003, 0.003)
@export var invert_y: bool = false

# Internal state
var input_priority_manager: InputPriorityManager
var current_movement: Vector2 = Vector2.ZERO
var target_movement: Vector2 = Vector2.ZERO
var is_active: bool = false

# Movement action mappings
var movement_actions = {
	"move_left": Vector2(-1, 0),
	"move_right": Vector2(1, 0),
	"move_forward": Vector2(0, -1),
	"move_backward": Vector2(0, 1)
}

func _ready():
	# Get reference to InputPriorityManager
	input_priority_manager = get_node("../../InputCore/InputPriorityManager")
	if input_priority_manager:
		input_priority_manager.register_component(InputPriorityManager.InputType.DIRECT, self)
	
	# Connect to camera orbit component
	connect_to_camera_system()

func _process(delta):
	# Smooth movement input
	if current_movement != target_movement:
		current_movement = current_movement.lerp(target_movement, movement_smoothing * delta)
		
		# Emit movement command if we're the active input
		if is_active and current_movement.length() > movement_deadzone:
			movement_command.emit(current_movement.normalized(), current_movement.length())

func process_input(event: InputEvent):
	# Main input processing - called by InputPriorityManager
	if not input_priority_manager:
		return
	
	# Check if we should be active
	is_active = input_priority_manager.is_input_active(InputPriorityManager.InputType.DIRECT)
	
	# Process different input types
	if event is InputEventKey:
		process_keyboard_input(event)
	elif event is InputEventMouseMotion:
		process_mouse_motion(event)

func process_fallback_input(event: InputEvent):
	# Always process movement as fallback, even when not primary input
	if event is InputEventKey:
		process_movement_keys(event)

func process_keyboard_input(event: InputEventKey):
	# Handle movement keys
	process_movement_keys(event)
	
	# Handle action keys
	process_action_keys(event)

func process_movement_keys(event: InputEventKey):
	# Update target movement based on currently pressed keys
	calculate_movement_vector()

func process_action_keys(event: InputEventKey):
	# Handle non-movement actions
	var action_name = get_action_name_for_event(event)
	
	if action_name in ["jump", "sprint", "walk", "reset"]:
		if is_active:  # Only emit actions when we're the primary input
			action_command.emit(action_name, event.pressed)

func process_mouse_motion(event: InputEventMouseMotion):
	# Only process mouse look when mouse is captured and we're active
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and is_active:
		var mouse_delta = event.relative
		
		# Apply sensitivity
		mouse_delta *= mouse_sensitivity
		
		# Invert Y if needed
		if invert_y:
			mouse_delta.y = -mouse_delta.y
		
		# Send to camera system
		look_command.emit(mouse_delta)

func calculate_movement_vector():
	# Calculate movement vector from currently pressed keys
	var movement_vector = Vector2.ZERO
	
	for action in movement_actions:
		if Input.is_action_pressed(action):
			movement_vector += movement_actions[action]
	
	# Update target movement
	target_movement = movement_vector.limit_length(1.0)
	
	# Set this input as active if movement detected
	if target_movement.length() > 0 and input_priority_manager:
		input_priority_manager.set_active_input(InputPriorityManager.InputType.DIRECT)

func get_action_name_for_event(event: InputEventKey) -> String:
	# Map key events to action names
	var all_actions = ["move_left", "move_right", "move_forward", "move_backward", 
					   "jump", "sprint", "walk", "reset"]
	
	for action in all_actions:
		if InputMap.action_has_event(action, event):
			return action
	
	return ""

func connect_to_camera_system():
	# Connect our look_command to the camera's OrbitComponent
	var camera_system = get_node("../../../CAMERA")
	if camera_system:
		var orbit_component = camera_system.get_node("CameraComponents/OrbitComponent")
		if orbit_component and orbit_component.has_method("_on_look_command"):
			look_command.connect(orbit_component._on_look_command)
			print("DirectControlComponent: Connected to OrbitComponent")

# Public API for other systems
func get_current_movement() -> Vector2:
	return current_movement

func get_is_active() -> bool:
	return is_active

func reset_movement():
	current_movement = Vector2.ZERO
	target_movement = Vector2.ZERO

# Debug info
func get_debug_info() -> Dictionary:
	return {
		"is_active": is_active,
		"current_movement": current_movement,
		"target_movement": target_movement,
		"mouse_captured": Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	}
