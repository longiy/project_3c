# AnimationController.gd - With debug function to find the real issue
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
	state_machine = animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	
	if not state_machine:
		push_error("StateMachine not found in AnimationTree")
		return
	
	print("✅ AnimationController initialized")
	
	# DEBUG: Find out what parameters actually exist
	debug_animation_tree_parameters()

func debug_animation_tree_parameters():
	print("\n🔍 DEBUGGING ANIMATIONTREE PARAMETERS:")
	print("AnimationTree active: ", animation_tree.active)
	print("AnimationTree tree_root: ", animation_tree.tree_root)
	
	# Get all properties from AnimationTree
	var props = animation_tree.get_property_list()
	var param_count = 0
	
	print("\n📋 All AnimationTree parameters:")
	for prop in props:
		if prop.name.begins_with("parameters/"):
			param_count += 1
			var value = animation_tree.get(prop.name)
			print("  ", prop.name, " = ", value, " (type: ", typeof(value), ")")
	
	print("Total parameters found: ", param_count)
	
	# Test setting a parameter
	print("\n🧪 Testing parameter setting:")
	animation_tree.set("parameters/is_moving", true)
	var test_value = animation_tree.get("parameters/is_moving")
	print("Set is_moving=true, got back: ", test_value)
	
	# Check if StateMachine has conditions
	if state_machine:
		print("\n🎭 StateMachine info:")
		print("Current node: ", state_machine.get_current_node())
		print("Travel path: ", state_machine.get_travel_path())
	
	print("----------------------------------------\n")

func _physics_process(delta):
	if not state_machine or not character:
		return
	
	# Debug state changes
	var current_state = state_machine.get_current_node()
	if current_state != previous_state:
		print("🎭 State changed: ", previous_state, " → ", current_state)
		
		# Reset landing timer when entering Land state
		if current_state == "Land":
			landing_timer = landing_animation_duration
			
		previous_state = current_state
	
	# POLL current state from character only
	poll_current_state()
	update_blend_space(delta)
	
	# Try setting parameters (even though they don't exist yet)
	set_animation_parameters(delta)

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

func set_animation_parameters(delta):
	"""Try to set parameters - this will show us if they exist"""
	
	# Update landing timer
	var current_state = state_machine.get_current_node()
	if current_state == "Land":
		landing_timer -= delta
	
	# Calculate current values
	var curr_grounded = is_grounded
	var curr_moving = is_moving
	var curr_landing_complete = landing_timer <= 0.1
	
	# Try to set parameters (this might fail if they don't exist)
	animation_tree.set("parameters/is_grounded", curr_grounded)
	animation_tree.set("parameters/is_moving", curr_moving)
	animation_tree.set("parameters/landing_complete", curr_landing_complete)
	
	# Print every 60 frames
	if Engine.get_process_frames() % 60 == 0:
		print("📊 Parameters: moving=", curr_moving, " grounded=", curr_grounded, " landing_complete=", curr_landing_complete)

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
