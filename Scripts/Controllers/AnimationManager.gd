# AnimationManager.gd - Fixed blend value mapping
extends Node
class_name AnimationManager

@export var animation_tree: AnimationTree

@export_group("Blend Space Settings") 
@export var move_blend_param = "parameters/Move/blend_position"
@export var blend_smoothing = 8.0

# Signal-driven state
var received_movement_speed = 0.0
var received_input_direction = Vector2.ZERO
var received_is_movement_active = false
var received_is_running = false
var received_is_slow_walking = false

var character: CharacterBody3D
var current_blend_value = 0.0
var target_blend_value = 0.0

func _ready():
	character = get_parent() as CharacterBody3D
	
	if not character:
		push_error("AnimationManager must be child of CharacterBody3D")
		return
		
	if not animation_tree:
		push_error("AnimationTree not assigned to AnimationManager")
		return
	
	animation_tree.active = true
	print("✅ AnimationManager: Ready")

func _physics_process(delta):
	if animation_tree:
		update_blend_smoothing(delta)

# === SIGNAL HANDLERS ===

func _on_movement_changed(is_moving: bool, direction: Vector2, speed: float):
	received_is_movement_active = is_moving
	received_input_direction = direction
	received_movement_speed = speed
	calculate_blend_target()

func _on_mode_changed(is_running: bool, is_slow_walking: bool):
	received_is_running = is_running
	received_is_slow_walking = is_slow_walking
	calculate_blend_target()

# === BLEND CALCULATION - FIXED FOR 1D BLEND SPACE ===

func calculate_blend_target():
	# Map to 1D blend space: Idle(0), Walk(-1), Run(1)
	if not received_is_movement_active:
		target_blend_value = 0.0  # Idle at center
		return
	
	if received_is_running:
		target_blend_value = 1.0  # Run at positive end
	else:
		target_blend_value = -1.0  # Walk at negative end
	
	# Apply immediately for testing
	if animation_tree:
		animation_tree.set(move_blend_param, target_blend_value)
		print("🎭 Animation: Blend set to ", target_blend_value)

func update_blend_smoothing(delta):
	if abs(target_blend_value - current_blend_value) > 0.01:
		current_blend_value = move_toward(current_blend_value, target_blend_value, blend_smoothing * delta)
		if animation_tree:
			animation_tree.set(move_blend_param, current_blend_value)
