class_name CCC_CameraResponder
extends Node

@export_group("Response Settings")
@export var look_response_speed: float = 1.0
@export var zoom_response_speed: float = 1.0
@export var auto_level_strength: float = 0.5
@export var smooth_transitions: bool = true

@export_group("Camera Components")
@export var camera_input: CCC_CameraInput
@export var camera_modes: CCC_CameraModes

@export_group("3C Integration")
@export var character_controller: CCC_CharacterController

var current_pitch: float = 0.0
var current_yaw: float = 0.0
var current_zoom: float = 5.0
var target_zoom: float = 5.0

signal camera_transform_updated(transform: Transform3D)
signal camera_zoom_updated(zoom: float)

func _ready():
	connect_signals()

func _process(delta):
	if smooth_transitions:
		interpolate_zoom(delta)

func connect_signals():
	if camera_input:
		camera_input.camera_look_input.connect(_on_camera_look_input)
		camera_input.camera_zoom_input.connect(_on_camera_zoom_input)
		camera_input.camera_action_triggered.connect(_on_camera_action_triggered)

func _on_camera_look_input(delta_input: Vector2):
	if not camera_modes:
		return
	
	var current_mode = camera_modes.get_current_mode()
	
	match current_mode:
		"follow":
			handle_follow_look(delta_input)
		"orbit":
			handle_orbit_look(delta_input)
		"free":
			handle_free_look(delta_input)

func handle_follow_look(delta_input: Vector2):
	# Follow mode: rotate around character
	current_yaw -= delta_input.x * look_response_speed
	current_pitch -= delta_input.y * look_response_speed
	current_pitch = clamp(current_pitch, -85, 85)
	
	update_camera_transform()

func handle_orbit_look(delta_input: Vector2):
	# Orbit mode: free rotation around target
	current_yaw -= delta_input.x * look_response_speed
	current_pitch -= delta_input.y * look_response_speed
	current_pitch = clamp(current_pitch, -89, 89)
	
	update_camera_transform()

func handle_free_look(delta_input: Vector2):
	# Free mode: unconstrained camera movement
	current_yaw -= delta_input.x * look_response_speed
	current_pitch -= delta_input.y * look_response_speed
	current_pitch = clamp(current_pitch, -89, 89)
	
	update_camera_transform()

func _on_camera_zoom_input(zoom_delta: float):
	target_zoom -= zoom_delta * zoom_response_speed
	target_zoom = clamp(target_zoom, 1.0, 20.0)
	
	if not smooth_transitions:
		current_zoom = target_zoom
		camera_zoom_updated.emit(current_zoom)

func interpolate_zoom(delta: float):
	if abs(target_zoom - current_zoom) > 0.01:
		current_zoom = lerp(current_zoom, target_zoom, delta * 5.0)
		camera_zoom_updated.emit(current_zoom)

func _on_camera_action_triggered(action: String):
	match action:
		"mode_toggle":
			if camera_modes:
				camera_modes.cycle_mode()
		"reset":
			reset_camera()

func update_camera_transform():
	var target_position = Vector3.ZERO
	
	if character_controller:
		target_position = character_controller.global_position
	
	# Create camera transform based on current mode
	var camera_transform = create_camera_transform(target_position)
	camera_transform_updated.emit(camera_transform)

func create_camera_transform(target_position: Vector3) -> Transform3D:
	var transform = Transform3D()
	
	# Apply rotations
	transform = transform.rotated(Vector3.UP, deg_to_rad(current_yaw))
	transform = transform.rotated(Vector3.RIGHT, deg_to_rad(current_pitch))
	
	# Apply offset based on zoom
	var offset = Vector3(0, 0, current_zoom)
	transform.origin = target_position + transform.basis * offset
	
	# Look at target
	transform = transform.looking_at(target_position, Vector3.UP)
	
	return transform

func reset_camera():
	current_pitch = 0.0
	current_yaw = 0.0
	target_zoom = 5.0
	current_zoom = 5.0
	
	update_camera_transform()
	camera_zoom_updated.emit(current_zoom)

func set_look_angles(pitch: float, yaw: float):
	current_pitch = clamp(pitch, -89, 89)
	current_yaw = yaw
	update_camera_transform()

func set_zoom(zoom: float):
	target_zoom = clamp(zoom, 1.0, 20.0)
	if not smooth_transitions:
		current_zoom = target_zoom
	camera_zoom_updated.emit(current_zoom)

func get_current_pitch() -> float:
	return current_pitch

func get_current_yaw() -> float:
	return current_yaw

func get_current_zoom() -> float:
	return current_zoom

func get_debug_info() -> Dictionary:
	return {
		"camera_responder_pitch": current_pitch,
		"camera_responder_yaw": current_yaw,
		"camera_responder_zoom": current_zoom,
		"camera_responder_target_zoom": target_zoom,
		"camera_responder_mode": camera_modes.get_current_mode() if camera_modes else "unknown"
	}
