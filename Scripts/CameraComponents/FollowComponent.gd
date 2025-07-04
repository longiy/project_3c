# FollowComponent.gd
# CAMERA Follow Component for smooth character tracking
# STEP 3 REFACTOR: Export references only, comprehensive null checks

extends Node
class_name FollowComponent

# ===== EXPORT REFERENCES =====
@export var camera_system: CameraSystem
@export var character_system: CharacterSystem
@export var movement_component: MovementComponent
@export var target_node: Node3D

@export_group("Follow Settings")
@export var follow_smoothing: float = 8.0
@export var height_offset: float = 1.6
@export var follow_distance_ahead: float = 1.0  # Look ahead distance
@export var vertical_smoothing: float = 6.0

@export_group("Advanced Follow")
@export var motion_prediction: bool = true
@export var prediction_strength: float = 0.5
@export var vertical_lag: bool = true
@export var vertical_lag_strength: float = 0.3

@export_group("Boundary Settings")
@export var max_follow_distance: float = 8.0
@export var snap_distance: float = 15.0  # Distance to snap instead of smooth follow
@export var boundary_smoothing: float = 12.0

# ===== INTERNAL STATE =====
var last_target_position: Vector3
var predicted_position: Vector3
var vertical_velocity: float = 0.0
var follow_velocity: Vector3 = Vector3.ZERO

# Smoothing state
var smooth_position: Vector3
var smooth_vertical_offset: float

# ===== INITIALIZATION =====
func _ready():
	if not verify_references():
		return
	
	initialize_follow_state()
	print("FollowComponent: Initialized successfully")

func verify_references() -> bool:
	var missing = []
	
	if not camera_system: missing.append("camera_system")
	if not target_node: missing.append("target_node")
	
	# Optional references - warn but don't fail
	if not character_system:
		print("FollowComponent: Warning - character_system not assigned (motion prediction disabled)")
	if not movement_component:
		print("FollowComponent: Warning - movement_component not assigned (advanced prediction disabled)")
	
	if missing.size() > 0:
		push_error("FollowComponent: Missing critical references: " + str(missing))
		return false
	
	return true

# ===== FRAME PROCESSING =====
func _process(delta):
	if not camera_system or not target_node:
		return
	
	update_follow_position(delta)

# ===== FOLLOW LOGIC =====
func initialize_follow_state():
	if not target_node or not camera_system:
		return
		
	smooth_position = target_node.global_position + Vector3(0, height_offset, 0)
	camera_system.global_position = smooth_position
	last_target_position = target_node.global_position
	follow_velocity = Vector3.ZERO

func update_follow_position(delta: float):
	if not target_node or not camera_system:
		return
	
	var current_target_pos = target_node.global_position
	
	# Calculate target velocity for prediction
	var target_velocity = Vector3.ZERO
	if delta > 0:
		target_velocity = (current_target_pos - last_target_position) / delta
		last_target_position = current_target_pos
	
	# Apply motion prediction if enabled and movement component available
	var follow_target = current_target_pos
	if motion_prediction and movement_component:
		var prediction_offset = get_prediction_offset(target_velocity)
		follow_target += prediction_offset
	
	# Calculate desired camera position
	var desired_position = follow_target + Vector3(0, height_offset, 0)
	
	# Handle snapping for large distances
	var distance_to_target = camera_system.global_position.distance_to(desired_position)
	if distance_to_target > snap_distance:
		camera_system.global_position = desired_position
		smooth_position = desired_position
		return
	
	# Apply smoothing
	smooth_position = smooth_position.lerp(desired_position, follow_smoothing * delta)
	
	# Apply vertical lag if enabled
	if vertical_lag:
		apply_vertical_lag(delta)
	
	# Update camera position
	camera_system.global_position = smooth_position

func get_prediction_offset(target_velocity: Vector3) -> Vector3:
	if not movement_component:
		return target_velocity * prediction_strength * follow_distance_ahead
	
	# Enhanced prediction using movement component data
	var movement_direction = Vector3.ZERO
	# Add movement component integration here if needed
	
	return target_velocity * prediction_strength * follow_distance_ahead

func apply_vertical_lag(delta: float):
	if not target_node:
		return
		
	var target_y = target_node.global_position.y + height_offset
	var current_y = smooth_position.y
	
	var y_difference = target_y - current_y
	var lag_factor = 1.0 - vertical_lag_strength
	
	smooth_position.y = lerp(current_y, target_y, vertical_smoothing * lag_factor * delta)

# ===== PUBLIC API =====
func set_target(new_target: Node3D):
	target_node = new_target
	if new_target:
		initialize_follow_state()

func set_follow_smoothing(smoothing: float):
	follow_smoothing = clamp(smoothing, 1.0, 20.0)

func set_height_offset(offset: float):
	height_offset = offset

func set_prediction_enabled(enabled: bool):
	motion_prediction = enabled

func set_prediction_strength(strength: float):
	prediction_strength = clamp(strength, 0.0, 2.0)

func enable_vertical_lag(enabled: bool):
	vertical_lag = enabled

func set_follow_distance_ahead(distance: float):
	follow_distance_ahead = clamp(distance, 0.0, 5.0)

func reset_to_target():
	"""Instantly snap camera to target position"""
	if not target_node or not camera_system:
		push_error("FollowComponent: Cannot reset - missing target_node or camera_system")
		return
		
	smooth_position = target_node.global_position + Vector3(0, height_offset, 0)
	camera_system.global_position = smooth_position
	follow_velocity = Vector3.ZERO

# ===== FOLLOW PRESETS =====
func apply_follow_preset(preset_name: String):
	match preset_name:
		"tight":
			follow_smoothing = 12.0
			prediction_strength = 0.2
			follow_distance_ahead = 0.5
		"normal":
			follow_smoothing = 8.0
			prediction_strength = 0.5
			follow_distance_ahead = 1.0
		"loose":
			follow_smoothing = 4.0
			prediction_strength = 0.8
			follow_distance_ahead = 2.0
		"cinematic":
			follow_smoothing = 3.0
			prediction_strength = 1.0
			follow_distance_ahead = 3.0
			vertical_lag = true
			vertical_lag_strength = 0.5

# ===== DEBUG INFO =====
func get_debug_info() -> Dictionary:
	var current_distance = 0.0
	if target_node and camera_system:
		current_distance = camera_system.global_position.distance_to(target_node.global_position)
	
	return {
		"target_assigned": target_node != null,
		"camera_system_assigned": camera_system != null,
		"current_distance": current_distance,
		"follow_velocity": follow_velocity.length(),
		"predicted_position": predicted_position,
		"smooth_position": smooth_position,
		"vertical_offset": smooth_vertical_offset,
		"motion_prediction": motion_prediction,
		"vertical_lag": vertical_lag
	}
