class_name CCC_AnimationManager
extends Node

@export_group("Animation Components")
@export var animation_tree: AnimationTree
@export var animation_player: AnimationPlayer

@export_group("3C Integration")
@export var character_controller: CCC_CharacterController
@export var character_state: CCC_CharacterState
@export var character_movement: CCC_CharacterMovement
@export var character_physics: CCC_CharacterPhysics

@export_group("Support Systems")
@export var debug_system: CCC_DebugSystem
@export var ui_manager: CCC_UIManager

@export_group("Animation Settings")
@export var blend_speed: float = 5.0
@export var movement_threshold: float = 0.1
@export var enable_root_motion: bool = false

var state_machine: AnimationNodeStateMachine
var current_animation_state: String = "idle"
var animation_parameters: Dictionary = {}

signal animation_state_changed(new_state: String)
signal animation_event_triggered(event_name: String)

func _ready():
	setup_animation_system()
	connect_signals()
	setup_support_systems()

func setup_animation_system():
	if animation_tree:
		animation_tree.active = true
		state_machine = animation_tree.tree_root as AnimationNodeStateMachine
		
		# Initialize animation parameters
		animation_parameters = {
			"movement_speed": 0.0,
			"is_grounded": true,
			"is_jumping": false,
			"is_falling": false,
			"movement_direction": Vector2.ZERO
		}

func setup_support_systems():
	# Set up references for support systems
	if debug_system:
		debug_system.animation_manager = self
		debug_system.character_controller = character_controller
		debug_system.character_state = character_state
		debug_system.character_movement = character_movement
		debug_system.character_physics = character_physics
	
	if ui_manager:
		ui_manager.animation_manager = self
		ui_manager.character_controller = character_controller

func connect_signals():
	if character_state:
		character_state.state_changed.connect(_on_character_state_changed)
		character_state.state_entered.connect(_on_state_entered)
		character_state.state_exited.connect(_on_state_exited)
	
	if character_movement:
		character_movement.movement_state_changed.connect(_on_movement_state_changed)

func _process(delta):
	update_animation_parameters()
	update_animation_tree()

func update_animation_parameters():
	if not character_controller:
		return
	
	# Update movement speed
	animation_parameters["movement_speed"] = character_controller.get_movement_speed()
	
	# Update grounded state
	animation_parameters["is_grounded"] = character_controller.is_on_floor()
	
	# Update movement direction
	if character_movement:
		var input_dir = character_movement.current_input_direction
		animation_parameters["movement_direction"] = input_dir
	
	# Update state flags
	if character_state:
		var current_state = character_state.get_current_state_enum()
		animation_parameters["is_jumping"] = current_state == CCC_CharacterState.State.JUMPING
		animation_parameters["is_falling"] = current_state == CCC_CharacterState.State.FALLING

func update_animation_tree():
	if not animation_tree:
		return
	
	# Set animation tree parameters
	for param_name in animation_parameters:
		var param_path = "parameters/" + param_name
		if animation_tree.has_method("set"):
			animation_tree.set(param_path, animation_parameters[param_name])

func _on_character_state_changed(new_state):
	var state_name = CCC_CharacterState.State.keys()[new_state]
	play_state_animation(state_name)

func _on_state_entered(state):
	var state_name = CCC_CharacterState.State.keys()[state]
	
	match state:
		CCC_CharacterState.State.JUMPING:
			trigger_animation_event("jump_start")
		CCC_CharacterState.State.LANDING:
			trigger_animation_event("land")
		CCC_CharacterState.State.FALLING:
			trigger_animation_event("fall_start")

func _on_state_exited(state):
	var state_name = CCC_CharacterState.State.keys()[state]
	
	match state:
		CCC_CharacterState.State.JUMPING:
			trigger_animation_event("jump_end")
		CCC_CharacterState.State.LANDING:
			trigger_animation_event("land_end")

func _on_movement_state_changed(is_moving: bool):
	if is_moving:
		trigger_animation_event("movement_start")
	else:
		trigger_animation_event("movement_stop")

func play_state_animation(state_name: String):
	if current_animation_state == state_name:
		return
	
	current_animation_state = state_name
	animation_state_changed.emit(state_name)
	
	# Map character states to animation states
	var animation_state = map_character_state_to_animation(state_name)
	
	if animation_tree and state_machine:
		# Transition to new animation state
		animation_tree.set("parameters/conditions/" + animation_state, true)

func map_character_state_to_animation(character_state: String) -> String:
	match character_state:
		"IDLE":
			return "idle"
		"WALKING":
			return "move"
		"RUNNING":
			return "move"
		"JUMPING":
			return "airborne"
		"FALLING":
			return "airborne"
		"LANDING":
			return "land"
		_:
			return "idle"

func trigger_animation_event(event_name: String):
	animation_event_triggered.emit(event_name)
	
	# Handle specific animation events
	match event_name:
		"jump_start":
			play_one_shot_animation("jump_start")
		"land":
			play_one_shot_animation("land")
		"footstep":
			play_sound_effect("footstep")

func play_one_shot_animation(animation_name: String):
	if animation_player and animation_player.has_animation(animation_name):
		animation_player.play(animation_name)

func play_sound_effect(sound_name: String):
	# Placeholder for sound system integration
	print("Playing sound: ", sound_name)

func set_animation_speed(speed: float):
	if animation_tree:
		animation_tree.set("parameters/TimeScale/scale", speed)

func get_current_animation_state() -> String:
	return current_animation_state

func get_animation_parameter(param_name: String):
	return animation_parameters.get(param_name, null)

func set_animation_parameter(param_name: String, value):
	animation_parameters[param_name] = value

func get_debug_info() -> Dictionary:
	return {
		"animation_current_state": current_animation_state,
		"animation_parameters": animation_parameters,
		"animation_tree_active": animation_tree.active if animation_tree else false,
		"animation_blend_speed": blend_speed,
		"animation_root_motion": enable_root_motion
	}