# AnimationController.gd - Simplified for direct expression usage
extends Node
class_name AnimationController

@export var animation_tree: AnimationTree
@export var blend_space_param = "parameters/Move/blend_position"

@export_group("Animation Thresholds")
@export var movement_threshold = 0.3
@export var run_threshold = 6.0

@export_group("Blend Space Setup")
@export var strafe_blend_speed = 8.0

var state_machine: AnimationNodeStateMachinePlayback
var character: CharacterBody3D

# Animation state (only for blend space)
var current_blend_position = Vector2.ZERO
var target_blend_position = Vector2.ZERO

# State tracking for debug
var previous_state = ""

func _ready():
	character = get_parent() as CharacterBody3D
	
	if not character:
		push_error("AnimationController must be child of CharacterBody3D")
		return
		
	if not animation_tree:
		push_error("AnimationTree not assigned to AnimationController")
		return
	
	# Setup animation tree
	animation_tree.active = true
	state_machine = animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	
	if not state_machine:
		push_error("StateMachine not found in AnimationTree")
		return
	
	print("✅ AnimationController initialized - using direct expressions")

func _physics_process(delta):
	if not state_machine or not character:
		return
	
	# Debug state changes
	var current_state = state_machine.get_current_node()
	if current_state != previous_state:
		print("🎭 State changed: ", previous_state, " → ", current_state)
		previous_state = current_state
	
	# Only handle blend space - expressions handle state transitions
	update_blend_space(delta)

func update_blend_space(delta):
	# Get current data from character
	var movement_speed = character.get_movement_speed()
	var is_moving = movement_speed > movement_threshold
	
	# Simple forward/back blending based on actual speed
	if is_moving:
		var speed_multiplier = get_speed_multiplier()
		target_blend_position = Vector2(0, speed_multiplier)
	else:
		target_blend_position = Vector2.ZERO
	
	# Smooth blend position changes
	current_blend_position = current_blend_position.lerp(target_blend_position, strafe_blend_speed * delta)
	animation_tree.set(blend_space_param, current_blend_position)

func get_speed_multiplier() -> float:
	# Map actual movement speed to blend space positions
	var movement_speed = character.get_movement_speed()
	var base_speed = character.walk_speed  # Normal walk (3.0) = baseline
	var speed_ratio = movement_speed / base_speed
	
	# Clamp to reasonable range for blend space
	return clamp(speed_ratio, 0.0, 2.0)

# Debug info for testing
func get_debug_info() -> Dictionary:
	var movement_speed = character.get_movement_speed() if character else 0.0
	
	return {
		"movement_speed": movement_speed,
		"blend_position": current_blend_position,
		"current_state": state_machine.get_current_node() if state_machine else "None"
	}
