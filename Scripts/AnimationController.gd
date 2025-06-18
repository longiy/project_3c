# AnimationController.gd - BlendSpace1D version for speed-based blending
extends Node
class_name AnimationController

@export var animation_tree: AnimationTree
@export var blend_space_param = "parameters/Move/blend_amount"

@export_group("Animation Thresholds")
@export var movement_threshold = 0.3
@export var walk_speed_reference = 3.0
@export var run_speed_reference = 6.0

@export_group("Blend Settings")
@export var blend_smoothing = 8.0

var state_machine: AnimationNodeStateMachinePlayback
var character: CharacterBody3D

# Animation state (single float for 1D blending)
var current_blend_amount = 0.0
var target_blend_amount = 0.0

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
	
	print("✅ AnimationController initialized - using BlendSpace1D")

func _physics_process(delta):
	if not state_machine or not character:
		return
	
	# Debug state changes
	var current_state = state_machine.get_current_node()
	if current_state != previous_state:
		print("🎭 State changed: ", previous_state, " → ", current_state)
		previous_state = current_state
	
	# Update blend space
	update_blend_space_1d(delta)

func update_blend_space_1d(delta):
	# Get current movement speed from character
	var movement_speed = character.get_movement_speed()
	var is_moving = movement_speed > movement_threshold
	
	if is_moving:
		# Map speed to blend space positions
		# 0.0 = Idle, 1.0 = Walk, 2.0 = Run
		target_blend_amount = calculate_blend_amount(movement_speed)
	else:
		target_blend_amount = 0.0  # Idle
	
	# Smooth blend changes
	current_blend_amount = lerp(current_blend_amount, target_blend_amount, blend_smoothing * delta)
	animation_tree.set(blend_space_param, current_blend_amount)

func calculate_blend_amount(speed: float) -> float:
	"""Convert movement speed to BlendSpace1D position"""
	
	if speed <= movement_threshold:
		return 0.0  # Idle
	elif speed <= walk_speed_reference:
		# Between Idle (0.0) and Walk (1.0)
		var ratio = (speed - movement_threshold) / (walk_speed_reference - movement_threshold)
		return lerp(0.0, 1.0, ratio)
	else:
		# Between Walk (1.0) and Run (2.0)
		var ratio = (speed - walk_speed_reference) / (run_speed_reference - walk_speed_reference)
		return lerp(1.0, 2.0, clamp(ratio, 0.0, 1.0))

# Debug info for testing
func get_debug_info() -> Dictionary:
	var movement_speed = character.get_movement_speed() if character else 0.0
	
	return {
		"movement_speed": movement_speed,
		"blend_amount": current_blend_amount,
		"target_blend": target_blend_amount,
		"current_state": state_machine.get_current_node() if state_machine else "None"
	}
