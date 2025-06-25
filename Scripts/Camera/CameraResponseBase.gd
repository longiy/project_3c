# CameraResponseBase.gd - Base class for camera state responses
extends Node
class_name CameraResponseBase

@export_group("State Mapping")
@export var target_state: String = ""

@export_group("Camera Properties")
@export var fov: float = 75.0
@export var distance: float = 4.0
@export var offset: Vector3 = Vector3.ZERO

@export_group("Transition Settings")
@export var duration: float = 0.3
@export var ease_type: Tween.EaseType = Tween.EASE_OUT

@export_group("Advanced Settings")
@export var use_custom_transition: bool = false

# Override this in child classes for custom behavior
func get_custom_transition_data() -> Dictionary:
	"""Override this for complex custom transitions"""
	return {}

func has_custom_transition() -> bool:
	"""Check if this response uses custom transition logic"""
	return use_custom_transition

# Validation for inspector
func _get_configuration_warnings() -> PackedStringArray:
	var warnings = PackedStringArray()
	
	if target_state.is_empty():
		warnings.append("Target State must be set (e.g., 'idle', 'walking', 'running')")
	
	if fov <= 0:
		warnings.append("FOV must be greater than 0")
	
	if distance <= 0:
		warnings.append("Distance must be greater than 0")
	
	if duration <= 0:
		warnings.append("Duration must be greater than 0")
	
	return warnings
