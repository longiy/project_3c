# CameraResponseIdle.gd
extends CameraResponseBase
class_name CameraResponseIdle

func _ready():
	# Set target state and default values for idle
	target_state = "idle"
	fov = 50.0
	distance = 4.0
	offset = Vector3.ZERO
	duration = 0.3
	ease_type = Tween.EASE_OUT
