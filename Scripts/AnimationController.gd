# AnimationController.gd - Parameter-based state machine (no travel() calls)
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

@export_group("Landing Settings")
@export var landing_animation_duration = 2.0

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
	state_machine = animation_tree.get("parameters/playback")
	
	if not state_machine:
		push_error("StateMachine not found in AnimationTree")

func _physics_process(delta):
	if not state_machine or not character:
		return
	
	# Debug state changes
	var current_state = state_machine.get_current_node()
	if current_state != previous_state:
		print("State changed: ", previous_state, " -> ", current_state)
		
		# Reset landing timer when entering Land state
		if current_state == "Land":
			landing_timer = landing_animation_duration
			
		previous_state = current_state
	
	# POLL current state from character only
	poll_current_state()
	update_blend_space(delta)
	update_state_machine_parameters(delta)

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

func update_state_machine_parameters(delta):
	"""Set parameters for automatic state transitions - NO travel() calls"""
	
	# Update landing timer
	var current_state = state_machine.get_current_node()
	if current_state == "Land":
		landing_timer -= delta
	
	# Set all condition parameters for the state machine
	animation_tree.set("parameters/conditions/is_grounded", is_grounded)
	animation_tree.set("parameters/conditions/is_moving", is_moving)
	animation_tree.set("parameters/conditions/is_airborne", not is_grounded)
	animation_tree.set("parameters/conditions/is_idle", not is_moving)
	animation_tree.set("parameters/conditions/landing_complete", landing_timer <= 0.1)
	
	# Let the StateMachine arrows handle all transitions automatically
	# No more travel() calls!

# Debug info for testing
func get_debug_info() -> Dictionary:
	return {
		"movement_speed": movement_speed,
		"is_moving": is_moving,
		"is_grounded": is_grounded,
		"input_direction": input_direction,
		"blend_position": current_blend_position,
		"current_state": state_machine.get_current_node() if state_machine else "None",
		"landing_timer": landing_timer
	}
