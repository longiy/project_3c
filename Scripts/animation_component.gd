extends Node
class_name AnimationComponent

@export var animation_tree: AnimationTree
@export var character: CharacterBody3D

var state_machine: AnimationNodeStateMachinePlayback

func _ready():
	if animation_tree:
		animation_tree.active = true
		state_machine = animation_tree.get("parameters/playback")
		print("AnimationTree active: ", animation_tree.active)
		print("State machine found: ", state_machine != null)

func update_animation(delta: float):
	if not state_machine:
		print("ERROR: No state machine found!")
		return
	
	if not animation_tree.active:
		print("ERROR: AnimationTree not active!")
		return
	
	# Calculate movement data from character
	var horizontal_velocity = Vector3(character.velocity.x, 0, character.velocity.z)
	var speed = horizontal_velocity.length()
	var is_moving = speed > 0.5
	var is_grounded = character.is_on_floor()
	var current_state = state_machine.get_current_node()
	
	# Set the BlendSpace2D parameter
	var normalized_speed = speed / character.speed
	animation_tree.set("parameters/Move/blend_position", Vector2(0, normalized_speed))
	
	# DEBUG: Print current values
	print("Speed: ", speed, " | Moving: ", is_moving, " | Grounded: ", is_grounded)
	print("Current state: ", current_state)
	
	# Handle state transitions manually (no landing state)
	if not is_grounded and current_state != "Airborne":
		state_machine.travel("Airborne")
	elif is_grounded and is_moving and current_state != "Move":
		state_machine.travel("Move")
	elif is_grounded and not is_moving and current_state != "Idle":
		state_machine.travel("Idle")
