# FollowComponent.gd
# Day 11: CAMERA Follow Component for smooth character tracking
# Handles advanced following behavior with prediction and smoothing

extends Node
class_name FollowComponent

# References
var camera_system: CameraSystem
var character_system: CharacterSystem
var movement_component: MovementComponent

# Following settings
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

# Internal state
var target_node: Node3D
var last_target_position: Vector3
var predicted_position: Vector3
var vertical_velocity: float = 0.0
var follow_velocity: Vector3 = Vector3.ZERO

# Smoothing state
var smooth_position: Vector3
var smooth_vertical_offset: float

func _ready():
	# Get system references
	camera_system = get_node("../../") as CameraSystem
	if not camera_system:
		push_error("FollowComponent: CAMERA system not found")
		return
	
	character_system = get_node("../../../CHARACTER") as CharacterSystem
	if character_system:
		movement_component = character_system.get_node("CharacterComponents/MovementComponent")
	
	# Get target from camera system
	target_node = camera_system.target_node
	if target_node:
		initialize_follow_state()
	
	print("FollowComponent: Initialized")

func _process(delta):
	if not target_node or not camera_system:
		return
	
	update_follow_position(delta)

func initialize_follow_state():
	if not target_node:
		return
	
	last_target_position = target_node.global_position
	smooth_position = target_node.global_position
	smooth_vertical_offset = height_offset
	predicted_position = target_node.global_position

func update_follow_position(delta: float):
	var current_target_pos = target_node.global_position
	
	# Calculate target velocity for prediction
	var target_velocity = Vector3.ZERO
	if motion_prediction and movement_component:
		target_velocity = get_character_velocity()
	
	# Calculate predicted position
	if motion_prediction:
		predicted_position = current_target_pos + (target_velocity * prediction_strength)
	else:
		predicted_position = current_target_pos
	
	# Calculate desired follow position
	var desired_position = calculate_desired_position(predicted_position, target_velocity, delta)
	
	# Apply distance constraints
	desired_position = apply_distance_constraints(desired_position, current_target_pos)
	
	# Smooth follow movement
	smooth_position = smooth_follow_movement(desired_position, delta)
	
	# Apply to camera system
	camera_system.global_position = smooth_position
	
	# Update state
	last_target_position = current_target_pos

func calculate_desired_position(target_pos: Vector3, velocity: Vector3, delta: float) -> Vector3:
	var desired_pos = target_pos
	
	# Add height offset
	var current_height_offset = height_offset
	
	# Adjust height based on vertical movement
	if vertical_lag and velocity.length() > 0.1:
		var vertical_component = velocity.y
		current_height_offset += vertical_component * vertical_lag_strength
	
	# Apply vertical smoothing
	smooth_vertical_offset = lerp(smooth_vertical_offset, current_height_offset, vertical_smoothing * delta)
	desired_pos.y += smooth_vertical_offset
	
	# Look ahead based on movement direction
	if follow_distance_ahead > 0 and velocity.length() > 0.5:
		var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
		if horizontal_velocity.length() > 0.1:
			desired_pos += horizontal_velocity.normalized() * follow_distance_ahead * min(velocity.length() / 5.0, 1.0)
	
	return desired_pos

func apply_distance_constraints(desired_pos: Vector3, target_pos: Vector3) -> Vector3:
	var distance_to_target = desired_pos.distance_to(target_pos)
	
	# Snap if too far away
	if distance_to_target > snap_distance:
		return target_pos + Vector3(0, height_offset, 0)
	
	# Constrain maximum follow distance
	if distance_to_target > max_follow_distance:
		var direction = (desired_pos - target_pos).normalized()
		desired_pos = target_pos + direction * max_follow_distance
	
	return desired_pos

func smooth_follow_movement(desired_pos: Vector3, delta: float) -> Vector3:
	var current_pos = camera_system.global_position
	var distance = current_pos.distance_to(desired_pos)
	
	# Use different smoothing for different distances
	var effective_smoothing = follow_smoothing
	
	# Faster movement when far away
	if distance > 5.0:
		effective_smoothing = follow_smoothing * 2.0
	elif distance < 1.0:
		effective_smoothing = follow_smoothing * 0.5
	
	# Apply smoothing with velocity tracking
	follow_velocity = (desired_pos - current_pos) * effective_smoothing * delta
	return current_pos + follow_velocity

func get_character_velocity() -> Vector3:
	if not movement_component:
		return Vector3.ZERO
	
	# Try to get velocity from movement component
	if movement_component.has_method("get_velocity"):
		return movement_component.get_velocity()
	elif movement_component.has_method("get_current_velocity"):
		return movement_component.get_current_velocity()
	
	# Fallback: calculate velocity from position change
	var current_pos = target_node.global_position
	var velocity = (current_pos - last_target_position) / get_process_delta_time()
	return velocity

# === PUBLIC API ===

func set_target(new_target: Node3D):
	target_node = new_target
	camera_system.target_node = new_target
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
	if target_node:
		smooth_position = target_node.global_position + Vector3(0, height_offset, 0)
		camera_system.global_position = smooth_position
		follow_velocity = Vector3.ZERO

# === FOLLOW PRESETS ===

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

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	var current_distance = 0.0
	if target_node and camera_system:
		current_distance = camera_system.global_position.distance_to(target_node.global_position)
	
	return {
		"target_assigned": target_node != null,
		"current_distance": current_distance,
		"follow_velocity": follow_velocity.length(),
		"predicted_position": predicted_position,
		"smooth_position": smooth_position,
		"vertical_offset": smooth_vertical_offset,
		"motion_prediction": motion_prediction,
		"vertical_lag": vertical_lag
	}
