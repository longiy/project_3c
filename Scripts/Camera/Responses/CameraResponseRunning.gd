# CameraResponseRunning.gd
extends CameraResponseBase
class_name CameraResponseRunning

func _ready():
	# Set target state and default values for running
	target_state = "running"
	fov = 70.0
	distance = 4.0
	offset = Vector3(0, 2, 0)
	duration = 0.3
	ease_type = Tween.EASE_OUT
