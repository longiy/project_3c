# OrbitComponent.gd
# Enhanced orbit control for SpringArm3D camera system
# Handles mouse look with proper SpringArm3D integration

extends Node
class_name OrbitComponent

# System references
var camera_system: CameraSystem

# Orbit settings
@export_group("Mouse Look Settings")
@export var mouse_sensitivity: Vector2 = Vector2(0.003, 0.003)
@export var pitch_limits: Vector2 = Vector2(-80, 50)
@export var invert_y: bool = false

@export_group("Smoothing")
@export var rotation_smoothing: float = 12.0
@export var use_smoothing: bool = true

# Internal rotation state
var current_pitch: float = 0.0
var current_yaw: float = 0.0
var target_pitch: float = 0.0
var target_yaw: float = 0.0

func _ready():
	# Get parent CAMERA system
	camera_system = get_parent().get_parent() as CameraSystem
	if not camera_system:
		push_error("OrbitComponent: Must be child of CAMERA system")
		return
	
	# Initialize rotation
	current_pitch = deg_to_rad(-20.0)
	current_yaw = 0.0
	target_pitch = current_pitch
	target_yaw = current_yaw
	
	# Wait for camera system to be fully initialized
	call_deferred("apply_initial_rotation")
	
	print("OrbitComponent: Initialized with SpringArm3D")

func _process(delta):
	# Smooth rotation if enabled
	if use_smoothing:
		apply_smooth_rotation(delta)

func _on_look_command(delta: Vector2):
	# Receive look input from DirectControlComponent
	apply_mouse_look(delta)



func apply_mouse_look(mouse_delta: Vector2):
	# Apply sensitivity
	var look_delta = mouse_delta * mouse_sensitivity
	
	# Invert Y if needed
	if invert_y:
		look_delta.y = -look_delta.y
	
	# Update target rotation values
	target_yaw -= look_delta.x
	target_pitch -= look_delta.y
	
	# Clamp pitch
	target_pitch = clamp(
		target_pitch,
		deg_to_rad(pitch_limits.x),
		deg_to_rad(pitch_limits.y)
	)
	
	# Apply immediately if no smoothing
	if not use_smoothing:
		current_pitch = target_pitch
		current_yaw = target_yaw
		apply_rotation_to_camera()

func apply_initial_rotation():
	# Apply initial rotation after everything is set up
	if camera_system:
		camera_system.apply_rotation(current_yaw, current_pitch)

func apply_smooth_rotation(delta: float):
	# Smoothly interpolate to target rotation
	var old_pitch = current_pitch
	var old_yaw = current_yaw
	
	current_yaw = lerp_angle(current_yaw, target_yaw, rotation_smoothing * delta)
	current_pitch = lerp(current_pitch, target_pitch, rotation_smoothing * delta)
	
	# Only update camera if rotation changed
	if abs(current_pitch - old_pitch) > 0.001 or abs(current_yaw - old_yaw) > 0.001:
		apply_rotation_to_camera()

func apply_rotation_to_camera():
	# Apply rotation through camera system
	if camera_system:
		camera_system.apply_rotation(current_yaw, current_pitch)

# Public API for camera control
func set_sensitivity(sensitivity: Vector2):
	mouse_sensitivity = sensitivity

func set_pitch_limits(limits: Vector2):
	pitch_limits = limits

func set_invert_y(invert: bool):
	invert_y = invert

func set_smoothing(enabled: bool, speed: float = 12.0):
	use_smoothing = enabled
	rotation_smoothing = speed

func get_current_rotation() -> Vector2:
	return Vector2(current_pitch, current_yaw)

func reset_rotation():
	target_pitch = deg_to_rad(-20.0)
	target_yaw = 0.0
	
	if not use_smoothing:
		current_pitch = target_pitch
		current_yaw = target_yaw
		apply_rotation_to_camera()

func snap_to_target():
	# Instantly snap to target rotation (useful for teleporting)
	current_pitch = target_pitch
	current_yaw = target_yaw
	apply_rotation_to_camera()

# Debug info
func get_debug_info() -> Dictionary:
	return {
		"current_rotation_deg": Vector2(rad_to_deg(current_pitch), rad_to_deg(current_yaw)),
		"target_rotation_deg": Vector2(rad_to_deg(target_pitch), rad_to_deg(target_yaw)),
		"mouse_sensitivity": mouse_sensitivity,
		"smoothing_enabled": use_smoothing,
		"pitch_limits": pitch_limits
	}
