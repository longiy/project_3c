# CameraProperties.gd - Unified camera properties class
class_name CameraProperties
extends RefCounted

# === CORE CAMERA PROPERTIES ===
var fov: float = 75.0
var distance: float = 4.0
var offset: Vector3 = Vector3.ZERO

# === FOLLOW BEHAVIOR ===
var follow_speed: float = 8.0
var rotation_speed: float = 12.0
var anticipation: float = 0.0  # How much to anticipate movement

# === LOOK BEHAVIOR ===
var mouse_sensitivity: float = 0.002
var pitch_limits: Vector2 = Vector2(-80.0, 50.0)
var yaw_limits: Vector2 = Vector2.ZERO  # 0,0 = unlimited

# === SPECIAL PROPERTIES ===
var smoothing: float = 1.0
var collision_enabled: bool = true
var shake_intensity: float = 0.0

func _init(
	p_fov: float = 75.0,
	p_distance: float = 4.0,
	p_offset: Vector3 = Vector3.ZERO
):
	fov = p_fov
	distance = p_distance
	offset = p_offset

# === BLENDING METHODS ===

func blend_towards(target: CameraProperties, delta: float):
	"""Blend towards target properties"""
	fov = lerp(fov, target.fov, delta)
	distance = lerp(distance, target.distance, delta)
	offset = offset.lerp(target.offset, delta)
	follow_speed = lerp(follow_speed, target.follow_speed, delta)
	rotation_speed = lerp(rotation_speed, target.rotation_speed, delta)
	anticipation = lerp(anticipation, target.anticipation, delta)
	mouse_sensitivity = lerp(mouse_sensitivity, target.mouse_sensitivity, delta)
	smoothing = lerp(smoothing, target.smoothing, delta)
	shake_intensity = lerp(shake_intensity, target.shake_intensity, delta)

func copy_from(other: CameraProperties):
	"""Copy all properties from another instance"""
	fov = other.fov
	distance = other.distance
	offset = other.offset
	follow_speed = other.follow_speed
	rotation_speed = other.rotation_speed
	anticipation = other.anticipation
	mouse_sensitivity = other.mouse_sensitivity
	pitch_limits = other.pitch_limits
	yaw_limits = other.yaw_limits
	smoothing = other.smoothing
	collision_enabled = other.collision_enabled
	shake_intensity = other.shake_intensity

func equals(other: CameraProperties, tolerance: float = 0.01) -> bool:
	"""Check if properties are approximately equal"""
	return (
		abs(fov - other.fov) < tolerance and
		abs(distance - other.distance) < tolerance and
		offset.distance_to(other.offset) < tolerance and
		abs(follow_speed - other.follow_speed) < tolerance and
		abs(anticipation - other.anticipation) < tolerance
	)

# === UTILITY METHODS ===

func to_dict() -> Dictionary:
	"""Convert to dictionary for debugging"""
	return {
		"fov": fov,
		"distance": distance,
		"offset": offset,
		"follow_speed": follow_speed,
		"rotation_speed": rotation_speed,
		"anticipation": anticipation,
		"mouse_sensitivity": mouse_sensitivity,
		"smoothing": smoothing,
		"shake_intensity": shake_intensity
	}

func from_dict(data: Dictionary):
	"""Load from dictionary"""
	fov = data.get("fov", fov)
	distance = data.get("distance", distance)
	offset = data.get("offset", offset)
	follow_speed = data.get("follow_speed", follow_speed)
	rotation_speed = data.get("rotation_speed", rotation_speed)
	anticipation = data.get("anticipation", anticipation)
	mouse_sensitivity = data.get("mouse_sensitivity", mouse_sensitivity)
	smoothing = data.get("smoothing", smoothing)
	shake_intensity = data.get("shake_intensity", shake_intensity)

func clone() -> CameraProperties:
	"""Create a copy of this properties instance"""
	var copy = CameraProperties.new()
	copy.copy_from(self)
	return copy

# === PRESET CREATION ===

static func create_follow_preset() -> CameraProperties:
	"""Create preset for normal follow camera"""
	var props = CameraProperties.new(75.0, 4.0, Vector3.ZERO)
	props.follow_speed = 8.0
	props.anticipation = 0.0
	return props

static func create_click_follow_preset() -> CameraProperties:
	"""Create preset for click navigation camera"""
	var props = CameraProperties.new(70.0, 4.5, Vector3(0, 0.2, 0))
	props.follow_speed = 6.0
	props.anticipation = 0.3  # Anticipate movement slightly
	return props

static func create_cinematic_preset() -> CameraProperties:
	"""Create preset for cinematic camera"""
	var props = CameraProperties.new(60.0, 3.0, Vector3.ZERO)
	props.follow_speed = 2.0
	props.smoothing = 0.5
	return props

static func create_state_preset(state_name: String) -> CameraProperties:
	"""Create preset based on character state"""
	match state_name:
		"idle":
			var props = CameraProperties.new(50.0, 4.0, Vector3.ZERO)
			props.follow_speed = 10.0
			return props
		
		"walking":
			var props = CameraProperties.new(60.0, 4.0, Vector3(0, 1, 0))
			props.follow_speed = 8.0
			return props
		
		"running":
			var props = CameraProperties.new(70.0, 4.2, Vector3(0, 2, 0))
			props.follow_speed = 6.0
			props.anticipation = 0.1
			return props
		
		"jumping":
			var props = CameraProperties.new(85.0, 4.8, Vector3(0, 0.3, 0))
			props.follow_speed = 4.0
			return props
		
		"airborne":
			var props = CameraProperties.new(90.0, 5.0, Vector3(0, 0.4, 0))
			props.follow_speed = 5.0
			return props
		
		"landing":
			var props = CameraProperties.new(75.0, 4.0, Vector3(0, 0.1, 0))
			props.follow_speed = 12.0
			return props
		
		_:
			return create_follow_preset()

# === VALIDATION ===

func validate() -> bool:
	"""Validate that properties are within reasonable ranges"""
	if fov <= 0 or fov > 180:
		push_warning("CameraProperties: Invalid FOV: " + str(fov))
		return false
	
	if distance <= 0:
		push_warning("CameraProperties: Invalid distance: " + str(distance))
		return false
	
	if follow_speed < 0 or rotation_speed < 0:
		push_warning("CameraProperties: Invalid speed values")
		return false
	
	return true

func clamp_to_valid_ranges():
	"""Clamp all properties to valid ranges"""
	fov = clamp(fov, 10.0, 170.0)
	distance = clamp(distance, 0.1, 50.0)
	follow_speed = clamp(follow_speed, 0.1, 100.0)
	rotation_speed = clamp(rotation_speed, 0.1, 100.0)
	anticipation = clamp(anticipation, 0.0, 2.0)
	mouse_sensitivity = clamp(mouse_sensitivity, 0.0001, 0.1)
	smoothing = clamp(smoothing, 0.0, 10.0)
	shake_intensity = clamp(shake_intensity, 0.0, 10.0)
