# === ACTION CLASS ===
class_name Action
extends RefCounted

var name: String
var context: Dictionary
var timestamp: float
var expiry_time: float
var failure_reason: String = ""

func _init(action_name: String, action_context: Dictionary = {}, buffer_time: float = 0.15):
	name = action_name
	context = action_context
	timestamp = Time.get_ticks_msec() / 1000.0
	expiry_time = timestamp + buffer_time
	
	if buffer_time < 0:
		buffer_time = get_default_buffer_time(action_name)

func get_default_buffer_time(action_name: String) -> float:
	match action_name:
		"jump": return 0.1
		"sprint_start", "sprint_end": return 0.05
		_: return 0.15

func is_expired() -> bool:
	return Time.get_ticks_msec() / 1000.0 > expiry_time

func get_age() -> float:
	return Time.get_ticks_msec() / 1000.0 - timestamp

func serialize() -> Dictionary:
	return {
		"name": name,
		"context": context,
		"timestamp": timestamp
	}
