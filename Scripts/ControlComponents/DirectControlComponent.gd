# DirectControlComponent.gd
# WASD + mouse control for character movement
# Simple fix: Replace InputPriorityManager with InputCore

extends Node
class_name DirectControlComponent

# Command signals
signal movement_command(direction: Vector2, magnitude: float)
signal look_command(delta: Vector2)
signal action_command(action: String, pressed: bool)

# Export references - CHANGED: InputPriorityManager → InputCore
@export_group("References")
@export var input_core: InputCore
@export var camera_system: CameraSystem

@export_group("Input Settings")
@export var mouse_sensitivity: Vector2 = Vector2(0.003, 0.003)
@export var invert_y: bool = false

# Movement input mapping
var movement_actions = {
	"move_left": Vector2(-1, 0),
	"move_right": Vector2(1, 0),
	"move_forward": Vector2(0, -1),
	"move_backward": Vector2(0, 1)
}

# Internal state
var is_active: bool = false
var current_movement: Vector2 = Vector2.ZERO
var target_movement: Vector2 = Vector2.ZERO

func _ready():
	# Register with InputCore - CHANGED: input_priority_manager → input_core
	if input_core:
		input_core.register_component(InputCore.InputType.DIRECT, self)
	
	# Connect to camera if available
	if camera_system:
		connect_to_camera_system()

func _process(delta):
	# Update movement vector continuously
	calculate_movement_vector()
	
	# Apply movement smoothing
	current_movement = current_movement.lerp(target_movement, 12.0 * delta)
	
	# Emit movement command
	if current_movement.length() > 0.01:
		movement_command.emit(current_movement.normalized(), current_movement.length())

func process_input(event: InputEvent):
	# CHANGED: input_priority_manager → input_core
	if not input_core:
		return
	
	is_active = input_core.is_input_active(InputCore.InputType.DIRECT)
	
	if event is InputEventKey:
		process_keyboard_input(event)
	elif event is InputEventMouseMotion:
		process_mouse_motion(event)

func process_fallback_input(event: InputEvent):
	# Always process movement as fallback
	if event is InputEventKey:
		calculate_movement_vector()

func process_keyboard_input(event: InputEventKey):
	var action_name = get_action_name_for_event(event)
	
	if action_name in ["jump", "sprint", "walk", "reset"] and is_active:
		action_command.emit(action_name, event.pressed)

func process_mouse_motion(event: InputEventMouseMotion):
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and is_active:
		var mouse_delta = event.relative * mouse_sensitivity
		
		if invert_y:
			mouse_delta.y = -mouse_delta.y
		
		look_command.emit(mouse_delta)

func calculate_movement_vector():
	target_movement = Vector2.ZERO
	
	for action in movement_actions:
		if Input.is_action_pressed(action):
			target_movement += movement_actions[action]
	
	if target_movement.length() > 1.0:
		target_movement = target_movement.normalized()

func get_action_name_for_event(event: InputEventKey) -> String:
	for action in movement_actions:
		if InputMap.action_has_event(action, event):
			return action
	
	var other_actions = ["jump", "sprint", "walk", "reset"]
	for action in other_actions:
		if InputMap.action_has_event(action, event):
			return action
	
	return ""

func connect_to_camera_system():
	if camera_system and not look_command.is_connected(_on_look_command):
		look_command.connect(_on_look_command)

func _on_look_command(delta: Vector2):
	if camera_system and camera_system.has_method("handle_look_input"):
		camera_system.handle_look_input(delta)
