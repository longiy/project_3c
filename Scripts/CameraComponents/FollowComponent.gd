# FollowComponent.gd
# CAMERA Follow Component for smooth character tracking
# Fixed: Export variables instead of hardcoded paths

extends Node
class_name FollowComponent

# Export references for inspector assignment
@export_group("System References")
@export var camera_system: CameraSystem
@export var character_system: CharacterSystem
@export var movement_component: Node  # Changed from MovementComponent to Node
@export var target_node: Node3D

@export_group("Follow Settings")
@export var follow_smoothing: float = 8.0
@export var height_offset: float = 1.6
@export var follow_distance_ahead: float = 1.0
@export var vertical_smoothing: float = 6.0

@export_group("Advanced Follow")
@export var motion_prediction: bool = true
@export var prediction_strength: float = 0.5
@export var vertical_lag: bool = true
@export var vertical_lag_strength: float = 0.3

@export_group("Boundary Settings")
@export var max_follow_distance: float = 8.0
@export var snap_distance: float = 15.0
@export var boundary_smoothing: float = 12.0

# Internal state
var last_target_position: Vector3
var predicted_position: Vector3
var vertical_velocity: float = 0.0
var follow_velocity: Vector3 = Vector3.ZERO

# Smoothing state
var smooth_position: Vector3
var smooth_vertical_offset: float

func _ready():
	if not verify_references():
		return
	
	if target_node:
		initialize_follow_state()
	
	print("FollowComponent: Initialized")

func verify_references() -> bool:
	var missing = []
	
	if not camera_system:
		missing.append("camera_system")
	if not target_node:
		missing.append("target_node")
	
	if missing.size() > 0:
		push_error("FollowComponent: Missing references: " + str(missing))
		push_error("Please assign missing references in the Inspector")
		return false
	
	return true

func _process(delta):
	if not target_node or not camera_system:
		return
	
	update_follow_position(delta)

func initialize_follow_state():
	if target_node:
		last_target_position = target_node.global_position
		smooth_position = target_node.global_position
		smooth_vertical_offset = height_offset

func update_follow_position(delta):
	var target_pos = target_node.global_position
	
	# Calculate desired position
	var desired_pos = calculate_desired_position(target_pos)
	
	# Apply distance constraints
	desired_pos = apply_distance_constraints(desired_pos, target_pos)
	
	# Smooth the movement
	var new_pos = smooth_follow_movement(desired_pos, delta)
	
	# Update camera position
	camera_system.global_position = new_pos
	
	# Update state
	last_target_position = target_pos

func calculate_desired_position(target_pos: Vector3) -> Vector3:
	var desired_pos = target_pos + Vector3(0, height_offset, 0)
	
	# Apply motion prediction if enabled
	if motion_prediction and movement_component:
		var velocity = get_character_velocity()
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
	if camera_system:
		camera_system.target_node = new_target
	initialize_follow_state()

func set_follow_smoothing(smoothing: float):
	follow_smoothing = clamp(smoothing, 0.1, 50.0)

func set_height_offset(offset: float):
	height_offset = offset

func set_prediction_enabled(enabled: bool):
	motion_prediction = enabled

func get_follow_distance() -> float:
	if target_node and camera_system:
		return camera_system.global_position.distance_to(target_node.global_position)
	return 0.0

func get_is_following() -> bool:
	return target_node != null and camera_system != null
