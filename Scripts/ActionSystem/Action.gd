# Action.gd - Fixed for proper global class registration
class_name Action
extends RefCounted

var name: String
var context: Dictionary
var timestamp: float
var expiry_time: float
var failure_reason: String = ""

func _init(action_name: String = "", action_context: Dictionary = {}, buffer_time: float = -1):
	name = action_name
	context = action_context
	timestamp = Time.get_ticks_msec() / 1000.0
	
	if buffer_time < 0:
		buffer_time = get_default_buffer_time(action_name)
	
	expiry_time = timestamp + buffer_time

func get_default_buffer_time(action_name: String) -> float:
	match action_name:
		# Movement actions - very short buffer (need immediate response)
		"move_start", "move_update", "move_end":
			return 0.02
		# Look actions - no buffer (immediate)
		"look_delta":
			return 0.01
		# Camera actions - immediate response
		"camera_zoom", "camera_toggle_mouse", "camera_set_fov", "camera_set_distance":
			return 0.01
		# Jump actions - standard buffer for timing
		"jump":
			return 0.1
		# Mode toggles - short buffer
		"sprint_start", "sprint_end", "slow_walk_start", "slow_walk_end":
			return 0.05
		# Utility actions
		"reset":
			return 0.2
		# Default for new action types
		_:
			return 0.15

func is_expired() -> bool:
	return Time.get_ticks_msec() / 1000.0 > expiry_time

func get_age() -> float:
	return Time.get_ticks_msec() / 1000.0 - timestamp

func is_movement_action() -> bool:
	return name in ["move_start", "move_update", "move_end"]

func is_look_action() -> bool:
	return name in ["look_delta"]

func is_mode_action() -> bool:
	return name in ["sprint_start", "sprint_end", "slow_walk_start", "slow_walk_end"]

func is_camera_action() -> bool:
	return name in ["look_delta", "camera_zoom", "camera_toggle_mouse", "camera_set_fov", "camera_set_distance"]

func is_jump_action() -> bool:
	return name in ["jump"]

func get_movement_vector() -> Vector2:
	"""Helper to extract movement vector from context"""
	return context.get("direction", Vector2.ZERO)

func get_look_delta() -> Vector2:
	"""Helper to extract look delta from context"""
	return context.get("delta", Vector2.ZERO)

func get_zoom_delta() -> float:
	"""Helper to extract zoom delta from context"""
	return context.get("zoom_delta", 0.0)

func get_camera_context() -> Dictionary:
	"""Helper to extract camera-specific context"""
	return context

func serialize() -> Dictionary:
	return {
		"name": name,
		"context": context,
		"timestamp": timestamp,
		"age": get_age(),
		"is_movement": is_movement_action(),
		"is_camera": is_camera_action(),
		"is_mode": is_mode_action()
	}
