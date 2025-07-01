class_name CCC_CharacterState
extends Node

enum CharacterState {
	IDLE,
	WALKING,
	RUNNING,
	JUMPING,
	FALLING,
	LANDING
}

@export_group("State Settings")
@export var movement_speed_threshold: float = 0.3
@export var falling_velocity_threshold: float = -1.0
@export var landing_detection_time: float = 0.1

var character: CharacterBody3D
var current_state: CharacterState = CharacterState.IDLE
var previous_state: CharacterState = CharacterState.IDLE
var state_enter_time: float = 0.0
var was_airborne: bool = false

signal state_changed(new_state: CharacterState)
signal state_entered(state: CharacterState)
signal state_exited(state: CharacterState)

func _ready():
	if not character:
		character = get_parent() as CharacterBody3D
	
	set_state(CharacterState.IDLE)

func update_state(delta: float):
	var new_state = determine_state()
	
	if new_state != current_state:
		change_state(new_state)

func determine_state() -> CharacterState:
	var horizontal_speed = Vector2(character.velocity.x, character.velocity.z).length()
	var is_on_floor = character.is_on_floor()
	var vertical_velocity = character.velocity.y
	
	# Check for landing first
	if was_airborne and is_on_floor and vertical_velocity <= 0:
		was_airborne = false
		return CharacterState.LANDING
	
	# Airborne states
	if not is_on_floor:
		was_airborne = true
		if vertical_velocity > 0:
			return CharacterState.JUMPING
		elif vertical_velocity < falling_velocity_threshold:
			return CharacterState.FALLING
		else:
			return current_state  # Maintain current airborne state
	
	# Ground states
	was_airborne = false
	
	# Landing state timeout
	if current_state == CharacterState.LANDING:
		if (Time.get_ticks_msec() / 1000.0) - state_enter_time > landing_detection_time:
			# Transition to movement state based on speed
			if horizontal_speed > movement_speed_threshold:
				return CharacterState.WALKING
			else:
				return CharacterState.IDLE
		else:
			return CharacterState.LANDING
	
	# Normal ground movement
	if horizontal_speed > movement_speed_threshold:
		return CharacterState.WALKING
	else:
		return CharacterState.IDLE

func change_state(new_state: CharacterState):
	if new_state == current_state:
		return
	
	exit_state(current_state)
	previous_state = current_state
	current_state = new_state
	state_enter_time = Time.get_ticks_msec() / 1000.0
	enter_state(current_state)
	
	state_changed.emit(current_state)

func enter_state(state: CharacterState):
	state_entered.emit(state)
	
	match state:
		CharacterState.IDLE:
			pass
		CharacterState.WALKING:
			pass
		CharacterState.RUNNING:
			pass
		CharacterState.JUMPING:
			pass
		CharacterState.FALLING:
			pass
		CharacterState.LANDING:
			pass

func exit_state(state: CharacterState):
	state_exited.emit(state)
	
	match state:
		CharacterState.IDLE:
			pass
		CharacterState.WALKING:
			pass
		CharacterState.RUNNING:
			pass
		CharacterState.JUMPING:
			pass
		CharacterState.FALLING:
			pass
		CharacterState.LANDING:
			pass

func set_state(new_state: CharacterState):
	change_state(new_state)

func get_current_state() -> String:
	return CharacterState.keys()[current_state]

func get_current_state_enum() -> CharacterState:
	return current_state

func get_previous_state() -> String:
	return CharacterState.keys()[previous_state]

func get_time_in_current_state() -> float:
	return (Time.get_ticks_msec() / 1000.0) - state_enter_time

func is_airborne() -> bool:
	return current_state == CharacterState.JUMPING or current_state == CharacterState.FALLING

func is_grounded() -> bool:
	return current_state == CharacterState.IDLE or current_state == CharacterState.WALKING or current_state == CharacterState.RUNNING or current_state == CharacterState.LANDING

func get_debug_info() -> Dictionary:
	return {
		"state_current": get_current_state(),
		"state_previous": get_previous_state(),
		"state_time_in_current": get_time_in_current_state(),
		"state_is_airborne": is_airborne(),
		"state_is_grounded": is_grounded(),
		"state_was_airborne": was_airborne
	}
