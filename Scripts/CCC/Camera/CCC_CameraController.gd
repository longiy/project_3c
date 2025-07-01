class_name CCC_CameraController
extends Node

@export_group("Camera Components")
@export var camera_rig: Node3D
@export var active_camera: Camera3D
@export var camera_input: CCC_CameraInput
@export var camera_responder: CCC_CameraResponder
@export var camera_modes: CCC_CameraModes

@export_group("3C Integration")
@export var character_controller: CCC_CharacterController
@export var input_manager: CCC_InputManager

signal camera_mode_changed(new_mode: int)
signal camera_target_changed(target: Node3D)

func _ready():
	setup_camera_components()
	connect_signals()

func setup_camera_components():
	# Set up references between camera components
	if camera_input:
		camera_input.camera_responder = camera_responder
		camera_input.camera_modes = camera_modes
	
	if camera_responder:
		camera_responder.camera_input = camera_input
		camera_responder.camera_modes = camera_modes
		camera_responder.character_controller = character_controller
	
	if camera_modes:
		camera_modes.camera_input = camera_input
		camera_modes.camera_responder = camera_responder
		camera_modes.character_controller = character_controller
		camera_modes.input_manager = input_manager

func connect_signals():
	if character_controller:
		character_controller.state_changed.connect(_on_character_state_changed)
	
	if camera_responder:
		camera_responder.camera_transform_updated.connect(_on_camera_transform_updated)
		camera_responder.camera_zoom_updated.connect(_on_camera_zoom_updated)
	
	if camera_modes:
		camera_modes.mode_changed.connect(_on_camera_mode_changed)

func _on_camera_transform_updated(transform: Transform3D):
	if active_camera:
		active_camera.global_transform = transform

func _on_camera_zoom_updated(zoom: float):
	# Handle zoom updates if needed
	pass

func _on_camera_mode_changed(new_mode: String, old_mode: String):
	# Notify other systems of camera mode change
	pass

func set_camera_mode(mode_name: String):
	if camera_modes:
		camera_modes.set_mode(mode_name)

func get_current_mode() -> int:
	if camera_modes:
		return camera_modes.get_current_mode_index()
	return 0

func get_mode_name(mode: int) -> String:
	if camera_modes:
		var modes = camera_modes.get_available_modes()
		if mode >= 0 and mode < modes.size():
			return modes[mode]
	return "unknown"

func get_camera_basis() -> Basis:
	if active_camera:
		return active_camera.global_transform.basis
	return Basis.IDENTITY

func get_active_camera() -> Camera3D:
	return active_camera

func set_camera_target(target: Node3D):
	if camera_rig and camera_rig.has_method("set_target"):
		camera_rig.set_target(target)
	camera_target_changed.emit(target)

func _on_character_state_changed(new_state: String):
	# React to character state changes
	match new_state:
		"JUMPING":
			# Could adjust camera settings for jump
			pass
		"FALLING":
			# Could adjust camera settings for fall
			pass
		_:
			pass

func on_character_state_changed(state: String):
	_on_character_state_changed(state)

func get_camera_forward() -> Vector3:
	if active_camera:
		return -active_camera.global_transform.basis.z
	return Vector3.FORWARD

func get_camera_right() -> Vector3:
	if active_camera:
		return active_camera.global_transform.basis.x
	return Vector3.RIGHT

func get_debug_info() -> Dictionary:
	var debug_info = {
		"camera_position": active_camera.global_position if active_camera else Vector3.ZERO,
		"camera_rotation": active_camera.global_rotation if active_camera else Vector3.ZERO
	}
	
	if camera_input:
		debug_info.merge(camera_input.get_debug_info())
	if camera_responder:
		debug_info.merge(camera_responder.get_debug_info())
	if camera_modes:
		debug_info.merge(camera_modes.get_debug_info())
	
	return debug_info