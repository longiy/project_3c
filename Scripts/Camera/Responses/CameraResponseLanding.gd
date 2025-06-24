# CameraResponseLanding.gd
extends CameraResponseBase
class_name CameraResponseLanding

func _ready():
	# Set target state and default values for landing
	target_state = "landing"
	fov = 75.0
	distance = 4.0
	offset = Vector3(0, 0.1, 0)
	duration = 0.1  # Fast transition
	ease_type = Tween.EASE_IN
