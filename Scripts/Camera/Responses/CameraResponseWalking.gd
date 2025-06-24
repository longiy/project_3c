# CameraResponseWalking.gd
extends CameraResponseBase
class_name CameraResponseWalking

func _ready():
	# Set target state and default values for walking
	target_state = "walking"
	fov = 60.0
	distance = 4.0
	offset = Vector3(0, 1, 0)
	duration = 0.3
	ease_type = Tween.EASE_OUT
