class_name CCC_CharacterController
extends CharacterBody3D

@export_group("Character Components")
@export var character_physics: CCC_CharacterPhysics
@export var character_actions: CCC_CharacterActions
@export var character_movement: CCC_CharacterMovement
@export var character_state: CCC_CharacterState

@export_group("3C Integration")
@export var camera_controller: CCC_CameraController
@export var input_manager: CCC_InputManager

signal state_changed(new_state: String)
signal movement_changed(velocity: Vector3)

func _ready():
	setup_component_references()
	connect_signals()

func setup_component_references():
	# Set character reference for all components
	if character_physics:
		character_physics.character = self
	if character_actions:
		character_actions.character = self
	if character_movement:
		character_movement.character = self
	if character_state:
		character_state.character = self

func connect_signals():
	if input_manager:
		input_manager.movement_input_changed.connect(_on_movement_input_changed)
		input_manager.action_input_triggered.connect(_on_action_input_triggered)
	
	if character_state:
		character_state.state_changed.connect(_on_state_changed)

func _physics_process(delta):
	if character_physics:
		character_physics.process_physics(delta)
	
	if character_movement:
		var input_direction = input_manager.get_current_input_direction() if input_manager else Vector2.ZERO
		character_movement.process_movement(delta, input_direction)
	
	if character_actions:
		character_actions.process_actions(delta)
	
	if character_state:
		character_state.update_state(delta)

func _on_movement_input_changed(input_direction: Vector2):
	if character_movement:
		character_movement.set_input_direction(input_direction)

func _on_action_input_triggered(action: String):
	if character_actions:
		character_actions.trigger_action(action)

func _on_state_changed(new_state: String):
	state_changed.emit(new_state)
	
	# Notify camera of state changes
	if camera_controller:
		camera_controller.on_character_state_changed(new_state)

func get_current_state() -> String:
	return character_state.get_current_state() if character_state else "unknown"

func get_movement_speed() -> float:
	return velocity.length()

func is_on_floor() -> bool:
	return super.is_on_floor()

func get_debug_info() -> Dictionary:
	var debug_info = {
		"velocity": velocity,
		"speed": get_movement_speed(),
		"on_floor": is_on_floor(),
		"current_state": get_current_state()
	}
	
	if character_physics:
		debug_info.merge(character_physics.get_debug_info())
	if character_movement:
		debug_info.merge(character_movement.get_debug_info())
	if character_actions:
		debug_info.merge(character_actions.get_debug_info())
	if character_state:
		debug_info.merge(character_state.get_debug_info())
	
	return debug_info