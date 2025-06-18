# AnimationController.gd - Industry standard parameter-based approach
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
@export var landing_animation_duration = 0.5

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
	state_machine = animation_tree.get("parameters/playbook") as AnimationNodeStateMachinePlayback
	
	if not state_machine:
		push_error("StateMachine not found in AnimationTree")
		return
	
	print("✅ AnimationController initialized")

func _physics_process(delta):
	if not state_machine or not character:
		return
	
	# STEP 1: Poll current state from character (like Unity)
	poll_current_state()
	
	# STEP 2: Update blend space for movement
	update_blend_space(delta)
	
	# STEP 3: Set parameters for AnimationTree (like Unity's SetBool)
	update_animation_parameters(delta)
	
	# Debug state changes
	var current_state = state_machine.get_current_node()
	if current_state != previous_state:
		print("🎭 State: ", previous_state, " → ", current_state)
		if current_state == "Land":
			landing_timer = landing_animation_duration
		previous_state = current_state

func poll_current_state():
	"""Poll current movement state from character - same as Unity"""
	movement_speed = character.get_movement_speed()
	is_moving = movement_speed > movement_threshold
	is_grounded = character.is_on_floor()
	input_direction = character.get_current_input_direction()

func update_blend_space(delta):
	"""Update movement blend space - same as Unity blend trees"""
	if not use_8_directional:
		var speed_normalized = movement_speed / character.walk_speed
		target_blend_position = Vector2(0, speed_normalized)
	else:
		if is_moving and input_direction.length() > 0.1:
			var speed_multiplier = get_speed_multiplier()
			target_blend_position = input_direction * speed_multiplier
		else:
			target_blend_position = Vector2.ZERO
	
	current_blend_position = current_blend_position.lerp(target_blend_position, strafe_blend_speed * delta)
	animation_tree.set(blend_space_param, current_blend_position)

func update_animation_parameters(delta):
	"""Set animation parameters - equivalent to Unity's animator.SetBool()"""
	
	# Update landing timer
	var current_state = state_machine.get_current_node()
	if current_state == "Land":
		landing_timer -= delta
	
	# Calculate parameter values
	var landing_complete = landing_timer <= 0.0
	
	# Set parameters for AnimationTree transitions (like Unity)
	animation_tree.set("parameters/is_moving", is_moving)
	animation_tree.set("parameters/is_grounded", is_grounded)
	animation_tree.set("parameters/landing_complete", landing_complete)
	
	# Debug parameter changes
	print("📊 Parameters: moving=", is_moving, " grounded=", is_grounded, " landing_complete=", landing_complete)

func get_speed_multiplier() -> float:
	var base_speed = character.walk_speed
	var speed_ratio = movement_speed / base_speed
	return clamp(speed_ratio, 0.0, 2.0)

# Debug info
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
