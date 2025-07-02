# OrbitComponent.gd
# Clean CCC Framework camera orbit component
# Controls SpringArm3D rotation through CAMERA system

extends Node
class_name OrbitComponent

# System references
var camera_system: CameraSystem

# Orbit settings
@export var mouse_sensitivity: Vector2 = Vector2(0.003, 0.003)
@export var pitch_limits: Vector2 = Vector2(-80, 50)
@export var invert_y: bool = false

# Internal rotation state
var current_pitch: float = 0.0
var current_yaw: float = 0.0

func _ready():
	# Get parent CAMERA system
	camera_system = get_parent().get_parent() as CameraSystem
	if not camera_system:
		push_error("OrbitComponent: Must be child of CAMERA system")
		return
	
	# Initialize rotation
	current_pitch = deg_to_rad(-20.0)  # Slight downward angle
	current_yaw = 0.0

func _on_look_command(delta: Vector2):
	# Receive look input from DirectControlComponent
	apply_mouse_look(delta)

func apply_mouse_look(mouse_delta: Vector2):
	# Apply sensitivity
	var look_delta = mouse_delta * mouse_sensitivity.x
	
	# Invert Y if needed
	if invert_y:
		look_delta.y = -look_delta.y
	
	# Update rotation values
	current_yaw -= look_delta.x
	current_pitch -= look_delta.y * mouse_sensitivity.y
	
	# Clamp pitch
	current_pitch = clamp(
		current_pitch,
		deg_to_rad(pitch_limits.x),
		deg_to_rad(pitch_limits.y)
	)
	
	# Apply to camera system
	if camera_system:
		camera_system.apply_rotation(current_yaw, current_pitch)

# Public API for camera control
func set_sensitivity(sensitivity: Vector2):
	mouse_sensitivity = sensitivity

func set_pitch_limits(limits: Vector2):
	pitch_limits = limits

func set_invert_y(invert: bool):
	invert_y = invert

func get_current_rotation() -> Vector2:
	return Vector2(current_pitch, current_yaw)

func reset_rotation():
	current_pitch = deg_to_rad(-20.0)
	current_yaw = 0.0
	if camera_system:
		camera_system.apply_rotation(current_yaw, current_pitch)
