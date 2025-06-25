# CameraResponseJumping.gd
extends CameraResponseBase
class_name CameraResponseJumping

func _ready():
	# Set target state and default values for jumping
	target_state = "jumping"
	fov = 85.0
	distance = 4.8
	offset = Vector3(0, 0.3, 0)
	duration = 0.1  # Fast transition
	ease_type = Tween.EASE_OUT
