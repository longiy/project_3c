# AnimationController.gd - UPDATED: Connect to MovementStateManager
extends Node
class_name AnimationController

@export var animation_tree: AnimationTree

@export_group("Blend Space Settings") 
@export var move_blend_param = "parameters/Move/blend_position"
@export var blend_smoothing = 8.0

@export_group("Speed Mapping")
@export var idle_threshold = 0.3
@export var walk_speed_reference = 3.0
@export var run_speed_reference = 6.0

var character: CharacterBody3D

var current_blend_value = 0.0
var current_blend_vector = Vector2.ZERO
var target_blend_value = 0.0
var target_blend_vector = Vector2.ZERO

# Signal-driven state
var received_movement_speed = 0.0
var received_input_direction = Vector2.ZERO
var received_is_movement_active = false
var received_is_running = false
var received_is_slow_walking = false

func _ready():
	character = get_parent() as CharacterBody3D
	
	if not character:
		push_error("AnimationController must be child of CharacterBody3D")
		return
		
	if not animation_tree:
		push_error("AnimationTree not assigned to AnimationController")
		return
	
	animation_tree.active = true
	connect_to_movement_state_manager()

func connect_to_movement_state_manager():
	"""UPDATED: Connect to MovementStateManager instead of character"""
	var movement_manager = character.get_node_or_null("MovementStateManager")
	if movement_manager:
		movement_manager.movement_state_changed.connect(_on_movement_state_changed)
		movement_manager.movement_mode_changed.connect(_on_movement_mode_changed)
		movement_manager.speed_changed.connect(_on_speed_changed)
		print("✅ AnimationController: Connected to MovementStateManager")
	else:
		push_error("AnimationController: No MovementStateManager found!")

func _physics_process(delta):
	if animation_tree:
		update_blend_smoothing(delta)

# === SIGNAL HANDLERS ===

func _on_movement_state_changed(is_moving: bool, direction: Vector2, magnitude: float):
	received_is_movement_active = is_moving
	received_input_direction = direction
	update_animation_immediately()

func _on_movement_mode_changed(is_running: bool, is_slow_walking: bool):
	received_is_running = is_running
	received_is_slow_walking = is_slow_walking
	update_animation_immediately()

func _on_speed_changed(new_speed: float):
	received_movement_speed = new_speed
	update_animation_immediately()

func update_animation_immediately():
	if is_using_1d_blend_space():
		calculate_1d_blend_target()
	else:
		calculate_2d_blend_target()

# === BLEND SPACE CALCULATION ===

func calculate_1d_blend_target():
	if not received_is_movement_active:
		target_blend_value = 0.0
		return
	
	var input_magnitude = received_input_direction.length()
	
	if input_magnitude < 0.1:
		target_blend_value = 0.0
		return
	
	if received_is_running:
		target_blend_value = 0.5
	elif received_is_slow_walking:
		target_blend_value = -0.5
	else:
		target_blend_value = -0.2

func calculate_2d_blend_target():
	if not received_is_movement_active:
		target_blend_vector = Vector2.ZERO
		return
	
	var input_magnitude = received_input_direction.length()
	
	if input_magnitude < 0.1:
		target_blend_vector = Vector2.ZERO
		return
	
	target_blend_vector.x = received_input_direction.x * 1.0
	target_blend_vector.y = -received_input_direction.y * 1.0
	
	if received_is_running:
		target_blend_vector *= 1.5
	elif received_is_slow_walking:
		target_blend_vector *= 0.5
	else:
		target_blend_vector *= 1.0

func update_blend_smoothing(delta: float):
	if not animation_tree:
		return
	
	if is_using_1d_blend_space():
		current_blend_value = lerp(current_blend_value, target_blend_value, blend_smoothing * delta)
		animation_tree.set(move_blend_param, current_blend_value)
	else:
		current_blend_vector = current_blend_vector.lerp(target_blend_vector, blend_smoothing * delta)
		animation_tree.set(move_blend_param, current_blend_vector)

func is_using_1d_blend_space() -> bool:
	var current_value = animation_tree.get(move_blend_param)
	return current_value is float

func get_debug_info() -> Dictionary:
	return {
		"movement_speed": received_movement_speed,
		"input_direction": received_input_direction,
		"is_movement_active": received_is_movement_active,
		"is_running": received_is_running,
		"is_slow_walking": received_is_slow_walking,
		"blend_1d": current_blend_value,
		"blend_2d": current_blend_vector,
		"target_1d": target_blend_value,
		"target_2d": target_blend_vector,
		"is_1d_mode": is_using_1d_blend_space(),
		"system_type": "MovementStateManager-Driven",
		"connection_status": "Connected to MovementStateManager"
	}
