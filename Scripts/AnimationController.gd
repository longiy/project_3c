# AnimationController.gd - Decoupled from specific input components
extends Node
class_name AnimationController

@export var animation_tree: AnimationTree
@export var blend_space_param = "parameters/Move/blend_position"

@export_group("Animation Thresholds")
@export var movement_threshold = 0.3
@export var run_threshold = 6.0

@export_group("Blend Space Setup")
@export var use_8_directional = true
@export var strafe_blend_speed = 8.0

var state_machine: AnimationNodeStateMachinePlayback
var character: CharacterBody3D

# Animation state
var current_blend_position = Vector2.ZERO
var target_blend_position = Vector2.ZERO
var is_moving = false
var is_grounded = false
var movement_speed = 0.0
var input_direction = Vector2.ZERO
var landing_timer = 0.0

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
	state_machine = animation_tree.get("parameters/playback")
	
	if not state_machine:
		push_error("StateMachine not found in AnimationTree")

func _physics_process(delta):
	if not state_machine or not character:
		return
	
	# POLL current state from character only
	poll_current_state()
	update_blend_space(delta)
	update_state_machine(delta)

func poll_current_state():
	"""POLL current movement and input state - only talks to character"""
	# Get movement data from character
	movement_speed = character.get_movement_speed()
	is_moving = movement_speed > movement_threshold
	is_grounded = character.is_on_floor()
	
	# Get input direction from character (character handles input arbitration)
	input_direction = character.get_current_input_direction()

func update_blend_space(delta):
	if not use_8_directional:
		# Simple forward/back blending
		var speed_normalized = movement_speed / character.walk_speed
		target_blend_position = Vector2(0, speed_normalized)
	else:
		# 8-directional blending based on input direction
		if is_moving and input_direction.length() > 0.1:
			# Use input direction for immediate responsiveness
			var speed_multiplier = get_speed_multiplier()
			target_blend_position = input_direction * speed_multiplier
		else:
			target_blend_position = Vector2.ZERO
	
	# Smooth blend position changes
	current_blend_position = current_blend_position.lerp(target_blend_position, strafe_blend_speed * delta)
	animation_tree.set(blend_space_param, current_blend_position)

func get_speed_multiplier() -> float:
	# Map actual movement speed to blend space positions
	var base_speed = character.walk_speed  # Normal walk (3.0) = baseline
	var speed_ratio = movement_speed / base_speed
	
	# Clamp to reasonable range for blend space
	return clamp(speed_ratio, 0.0, 2.0)
	
	# Results:
	# Slow walk (2.0 speed): 2.0/3.0 = 0.67 → Slow walk animations at position ±0.67
	# Walk (3.0 speed):      3.0/3.0 = 1.0  → Walk animations at position ±1.0
	# Run (6.0 speed):       6.0/3.0 = 2.0  → Run animations at position ±2.0

func update_state_machine(delta):
	var current_state = state_machine.get_current_node()

	if not is_grounded and current_state != "Airborne":
		state_machine.travel("Airborne")
	elif is_grounded and current_state == "Airborne":
		state_machine.travel("Land")
		landing_timer = 2.0  # Duration of your landing animation
	elif current_state == "Land":
		if is_moving:
			state_machine.travel("Move")  # Quick blend to movement
		else:
			landing_timer -= delta
			if landing_timer <= 0.1:  # Transition slightly before animation ends
				state_machine.travel("Idle")  # Smooth blend to idle
	elif is_grounded and is_moving and current_state != "Move":
		state_machine.travel("Move")
	elif is_grounded and not is_moving and current_state != "Idle":
		state_machine.travel("Idle")

# Debug info for testing
func get_debug_info() -> Dictionary:
	return {
		"movement_speed": movement_speed,
		"is_moving": is_moving,
		"is_grounded": is_grounded,
		"input_direction": input_direction,
		"blend_position": current_blend_position,
		"current_state": state_machine.get_current_node() if state_machine else "None"
	}
