# AnimationManager.gd - Updated for CCC and MovementManager compatibility
extends Node
class_name AnimationManager

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

# CCC Enhancement tracking
var connected_to_ccc = false
var connected_to_legacy = false

func _ready():
	character = get_parent() as CharacterBody3D
	
	if not character:
		push_error("AnimationManager must be child of CharacterBody3D")
		return
		
	if not animation_tree:
		push_error("AnimationTree not assigned to AnimationManager")
		return
	
	animation_tree.active = true
	detect_connection_type()
	print("✅ AnimationManager: Ready - Connection type detected")

func detect_connection_type():
	"""Detect whether we're connected to CCC or legacy architecture"""
	var ccc_character_manager = get_parent().get_node_or_null("CCC_CharacterManager")
	var legacy_movement_manager = get_parent().get_node_or_null("MovementManager")
	
	if ccc_character_manager:
		connected_to_ccc = true
		print("🔗 AnimationManager: Connected to CCC architecture")
	elif legacy_movement_manager:
		connected_to_legacy = true
		print("🔗 AnimationManager: Connected to legacy architecture")
	else:
		print("⚠️ AnimationManager: No movement system detected")

func _physics_process(delta):
	if animation_tree:
		update_blend_smoothing(delta)

# === SIGNAL HANDLERS (Called by Character when connecting signals) ===

func _on_movement_changed(is_moving: bool, direction: Vector2, speed: float):
	"""Handle movement changes from CCC or legacy systems"""
	received_is_movement_active = is_moving
	received_input_direction = direction
	received_movement_speed = speed
	update_animation_immediately()
	
	if connected_to_ccc:
		coordinate_with_ccc_systems(is_moving, direction, speed)

func _on_mode_changed(is_running: bool, is_slow_walking: bool):
	"""Handle mode changes from CCC or legacy systems"""
	received_is_running = is_running
	received_is_slow_walking = is_slow_walking
	update_animation_immediately()

func coordinate_with_ccc_systems(is_moving: bool, direction: Vector2, speed: float):
	"""Enhanced coordination with CCC systems"""
	# This can be expanded for more sophisticated CCC coordination
	# For now, standard animation handling is sufficient
	pass

func update_animation_immediately():
	"""Update animation based on received signals"""
	if is_using_1d_blend_space():
		calculate_1d_blend_target()
	else:
		calculate_2d_blend_target()

# === BLEND SPACE CALCULATION ===

func calculate_1d_blend_target():
	"""Calculate 1D blend space target"""
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
	"""Calculate 2D blend space target"""
	if not received_is_movement_active:
		target_blend_vector = Vector2.ZERO
		return
	
	var input_magnitude = received_input_direction.length()
	
	if input_magnitude < 0.1:
		target_blend_vector = Vector2.ZERO
		return
	
	target_blend_vector.x = received_input_direction.x * 1.0
	target_blend_vector.y = -received_input_direction.y * 1.0
	
	# Apply speed scaling for running/walking
	var speed_multiplier = 1.0
	if received_is_running:
		speed_multiplier = 1.5
	elif received_is_slow_walking:
		speed_multiplier = 0.5
	
	target_blend_vector *= speed_multiplier

# === BLEND SPACE SMOOTHING ===

func update_blend_smoothing(delta: float):
	"""Smooth blend space transitions"""
	if is_using_1d_blend_space():
		update_1d_smoothing(delta)
	else:
		update_2d_smoothing(delta)

func update_1d_smoothing(delta: float):
	"""Update 1D blend smoothing"""
	current_blend_value = move_toward(current_blend_value, target_blend_value, blend_smoothing * delta)
	
	if animation_tree:
		animation_tree.set(move_blend_param, current_blend_value)

func update_2d_smoothing(delta: float):
	"""Update 2D blend smoothing"""
	current_blend_vector = current_blend_vector.move_toward(target_blend_vector, blend_smoothing * delta)
	
	if animation_tree:
		animation_tree.set(move_blend_param, current_blend_vector)

# === UTILITY METHODS ===

func is_using_1d_blend_space() -> bool:
	"""Check if using 1D blend space"""
	if not animation_tree:
		return false
	
	var blend_param = animation_tree.get(move_blend_param)
	return blend_param is float

# === CCC ENHANCEMENT METHODS ===

func update_movement_blend(direction: Vector2, magnitude: float):
	"""CCC Enhancement: Direct animation update"""
	if connected_to_ccc:
		received_input_direction = direction
		received_is_movement_active = magnitude > 0.01
		update_animation_immediately()

func set_character_type_animation(character_type: String):
	"""CCC Enhancement: Adapt animations for character type"""
	match character_type:
		"AVATAR":
			blend_smoothing = 8.0  # Responsive
		"OBSERVER":
			blend_smoothing = 2.0  # Slower, less responsive
		"COMMANDER":
			blend_smoothing = 5.0  # Moderate responsiveness

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get debug information"""
	var debug_data = {
		"connected_to_ccc": connected_to_ccc,
		"connected_to_legacy": connected_to_legacy,
		"movement_active": received_is_movement_active,
		"input_direction": received_input_direction,
		"movement_speed": received_movement_speed,
		"is_running": received_is_running,
		"is_slow_walking": received_is_slow_walking,
		"current_blend": current_blend_value if is_using_1d_blend_space() else current_blend_vector,
		"target_blend": target_blend_value if is_using_1d_blend_space() else target_blend_vector,
		"animation_tree_active": animation_tree.active if animation_tree else false
	}
	
	return debug_data
