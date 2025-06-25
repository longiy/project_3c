# CameraResponseAirborne.gd
extends CameraResponseBase
class_name CameraResponseAirborne

func _ready():
	# Set target state and default values for airborne
	target_state = "airborne"
	fov = 90.0
	distance = 5.0
	offset = Vector3(0, 0.4, 0)
	duration = 0.3
	ease_type = Tween.EASE_OUT
