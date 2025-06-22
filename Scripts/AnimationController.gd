# AnimationController.gd - Hybrid approach: Code handles parameters, expressions handle transitions
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

# For 1D blend space: 0.0 = Walk, 1.0 = Run
# For 2D blend space: Vector2 for directional movement

var character: CharacterBody3D
var current_blend_value = 0.0  # For 1D
var current_blend_vector = Vector2.ZERO  # For 2D

func _ready():
	character = get_parent() as CharacterBody3D
	
	if not character:
		push_error("AnimationController must be child of CharacterBody3D")
		return
		
	if not animation_tree:
		push_error("AnimationTree not assigned to AnimationController")
		return
	
	animation_tree.active = true
	print("✅ AnimationController initialized - Parameter control only")

func _physics_process(delta):
	if not animation_tree or not character:
		return
	
	# Update blend space parameters (this is what code should handle)
	update_movement_blend_space(delta)

func update_movement_blend_space(delta):
	var movement_speed = character.get_movement_speed()
	
	# Check if we're using 1D or 2D blend space
	if is_using_1d_blend_space():
		update_1d_blend_space(movement_speed, delta)
	else:
		update_2d_blend_space(delta)

func is_using_1d_blend_space() -> bool:
	# Check if the parameter is a float (1D) or Vector2 (2D)
	var current_value = animation_tree.get(move_blend_param)
	return current_value is float

func update_1d_blend_space(movement_speed: float, delta: float):
	var target_blend: float
	
	if movement_speed <= idle_threshold:
		target_blend = 0.0
	else:
		# Map speeds to proper ranges for camera states
		# Walk speed (3.0) should map to -0.5 for Walk state
		# Run speed (6.0) should map to 0.5 for Run state
		if movement_speed <= walk_speed_reference:
			# Walking range: map 0.3 to 3.0 -> -0.8 to -0.1
			target_blend = -0.8 + (movement_speed - idle_threshold) / (walk_speed_reference - idle_threshold) * 0.7
		else:
			# Running range: map 3.0 to 6.0+ -> 0.1 to 1.0+
			target_blend = 0.1 + (movement_speed - walk_speed_reference) / (run_speed_reference - walk_speed_reference) * 0.9
	
	current_blend_value = lerp(current_blend_value, target_blend, blend_smoothing * delta)
	animation_tree.set(move_blend_param, current_blend_value)
	
	## Debug output
	#print("Speed: ", movement_speed, " -> Blend: ", current_blend_value)

func update_2d_blend_space(delta: float):
	# Get input direction for 2D blending (strafe, forward/back)
	var input_direction = character.get_current_input_direction()
	var movement_speed = character.get_movement_speed()
	
	var target_blend = Vector2.ZERO
	
	if movement_speed > idle_threshold:
		# Map input to blend space coordinates
		# Adjust these multipliers based on your blend space setup
		target_blend.x = input_direction.x * 1.5  # Strafe amount
		target_blend.y = -input_direction.y * 1.5  # Forward/back amount
		
		# Scale by movement speed to differentiate walk/run
		var speed_intensity = clamp(movement_speed / run_speed_reference, 0.5, 2.0)
		target_blend *= speed_intensity
	
	# Smooth the blend transition
	current_blend_vector = current_blend_vector.lerp(target_blend, blend_smoothing * delta)
	animation_tree.set(move_blend_param, current_blend_vector)

# === PUBLIC API FOR CHARACTER (expressions use these) ===

func get_movement_speed() -> float:
	"""Proxy method for expressions - keeps character as single source of truth"""
	return character.get_movement_speed() if character else 0.0

func is_on_floor() -> bool:
	"""Proxy method for expressions"""
	return character.is_on_floor() if character else false

func is_grounded() -> bool:
	"""Alternative name for expressions"""
	return is_on_floor()

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	return {
		"movement_speed": get_movement_speed(),
		"blend_1d": current_blend_value,
		"blend_2d": current_blend_vector,
		"is_1d_mode": is_using_1d_blend_space()
	}
