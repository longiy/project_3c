extends Node
class_name AnimationComponent

@export var animation_tree: AnimationTree
@export var character: CharacterBody3D

var state_machine: AnimationNodeStateMachinePlayback

func _ready():
	if animation_tree:
		animation_tree.active = true
		state_machine = animation_tree.get("parameters/playback")

func update_animation(delta: float):
	if not state_machine:
		return
	
	# Calculate movement data from character
	var horizontal_velocity = Vector3(character.velocity.x, 0, character.velocity.z)
	var speed = horizontal_velocity.length()
	var is_moving = speed > 0.5
	var is_grounded = character.is_on_floor()
	
	# Update AnimationTree parameters
	animation_tree.set("parameters/is_moving", is_moving)
	animation_tree.set("parameters/is_grounded", is_grounded)
	animation_tree.set("parameters/movement_speed", speed / character.speed) # normalized 0-1
	
	# ADD THIS LINE:
	animation_tree.set("parameters/Move/blend_position", Vector2(0, speed / character.speed))
	
	# Handle landing detection
	var current_state = state_machine.get_current_node()
	if current_state == "AIRBORNE" and is_grounded:
		animation_tree.set("parameters/just_landed", true)
		await get_tree().process_frame # Reset next frame
		animation_tree.set("parameters/just_landed", false)
