# DirectControlComponent.gd
# WASD + mouse control for character movement
# STEP 4: Fixed camera connection with export validation

extends Node
class_name DirectControlComponent

# Command signals
signal movement_command(direction: Vector2, magnitude: float)
signal look_command(delta: Vector2)
signal action_command(action: String, pressed: bool)

# Export references
@export var input_core: InputCore
@export var camera_system: CameraSystem
@export var orbit_component: OrbitComponent  # NEW: Direct reference to avoid fragile paths

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
	if not verify_references():
		return
	
	if input_core:
		input_core.register_component(InputCore.InputType.DIRECT, self)
	
	connect_to_camera_system()
		
func verify_references() -> bool:
	var missing = []
	
	if not input_core: missing.append("input_core")
	if not camera_system: missing.append("camera_system")
	
	if missing.size() > 0:
		push_error("DirectControlComponent: Missing references: " + str(missing))
		return false
	
	return true
	
func _process(delta):
	# Update movement vector continuously
	calculate_movement_vector()
	
	# Apply movement smoothing
	current_movement = current_movement.lerp(target_movement, 12.0 * delta)
	
	# Emit movement command
	if current_movement.length() > 0.01:
		movement_command.emit(current_movement.normalized(), current_movement.length())

func process_input(event: InputEvent):
	if not input_core:
		return
	
	# Check activity with InputCore
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
	# Only process mouse look when in orbit mode (captured) and active
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
	
	target_movement = target_movement.limit_length(1.0)
	
	# Set as active input if movement detected
	if target_movement.length() > 0 and input_core:
		input_core.set_active_input(InputCore.InputType.DIRECT)

func get_action_name_for_event(event: InputEventKey) -> String:
	var actions = ["move_left", "move_right", "move_forward", "move_backward", 
				   "jump", "sprint", "walk", "reset"]
	
	for action in actions:
		if InputMap.action_has_event(action, event):
			return action
	
	return ""

func connect_to_camera_system():
	if not camera_system:
		push_error("DirectControlComponent: camera_system not assigned")
		return
	
	# FIXED: Use export reference first, fallback to path if needed
	if not orbit_component:
		orbit_component = camera_system.get_node_or_null("CameraComponents/OrbitComponent")
	
	if not orbit_component:
		push_error("DirectControlComponent: orbit_component not found in camera_system")
		return
	
	# Verify orbit component has the required method
	if not orbit_component.has_method("_on_look_command"):
		push_error("DirectControlComponent: orbit_component missing _on_look_command method")
		return
	
	# Connect the signal with null check
	if not look_command.is_connected(orbit_component._on_look_command):
		look_command.connect(orbit_component._on_look_command)
		print("DirectControlComponent: Connected look_command to OrbitComponent")
	else:
		print("DirectControlComponent: look_command already connected")

# Public API
func get_current_movement() -> Vector2:
	return current_movement

func get_is_active() -> bool:
	return is_active

func reset_movement():
	current_movement = Vector2.ZERO
	target_movement = Vector2.ZERO
