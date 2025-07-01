class_name CCC_CharacterState
extends Node

enum State {
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
var current_state: State = State.IDLE
var previous_state: State = State.IDLE
var state_enter_time: float = 0.0
var was_airborne: bool = false

signal state_changed(new_state: State)
signal state_entered(state: State)
signal state_exited(state: State)

func _ready():
	if not character:
		character = get_parent() as CharacterBody3D
	
	set_state(State.IDLE)

func update_state(delta: float):
	var new_state = determine_state()
	
	if new_state != current_state:
		change_state(new_state)

func determine_state() -> State:
	var horizontal_speed = Vector2(character.velocity.x, character.velocity.z).length()
	var is_on_floor = character.is_on_floor()
	var vertical_velocity = character.velocity.y
	
	# Check for landing first
	if was_airborne and is_on_floor and vertical_velocity <= 0:
		was_airborne = false
		return State.LANDING
	
	# Airborne states
	if not is_on_floor:
		was_airborne = true
		if vertical_velocity > 0:
			return State.JUMPING
		elif vertical_velocity < falling_velocity_threshold:
			return State.FALLING
		else:
			return current_state  # Maintain current airborne state
	
	# Ground states
	was_airborne = false
	
	# Landing state timeout
	if current_state == State.LANDING:
		if Time.get_time() - state_enter_time > landing_detection_time:
			# Transition to movement state based on speed
			if horizontal_speed > movement_speed_threshold:
				return State.WALKING
			else:
				return State.IDLE
		else:
			return State.LANDING
	
	# Normal ground movement
	if horizontal_speed > movement_speed_threshold:
		return State.WALKING
	else:
		return State.IDLE

func change_state(new_state: State):
	if new_state == current_state:
		return
	
	exit_state(current_state)
	previous_state = current_state
	current_state = new_state
	state_enter_time = Time.get_time()
	enter_state(current_state)
	
	state_changed.emit(current_state)

func enter_state(state: State):
	state_entered.emit(state)
	
	match state:
		State.IDLE:
			pass
		State.WALKING:
			pass
		State.RUNNING:
			pass
		State.JUMPING:
			pass
		State.FALLING:
			pass
		State.LANDING:
			pass

func exit_state(state: State):
	state_exited.emit(state)
	
	match state:
		State.IDLE:
			pass
		State.WALKING:
			pass
		State.RUNNING:
			pass
		State.JUMPING:
			pass
		State.FALLING:
			pass
		State.LANDING:
			pass

func set_state(new_state: State):
	change_state(new_state)

func get_current_state() -> String:
	return State.keys()[current_state]

func get_current_state_enum() -> State:
	return current_state

func get_previous_state() -> String:
	return State.keys()[previous_state]

func get_time_in_current_state() -> float:
	return Time.get_time() - state_enter_time

func is_airborne() -> bool:
	return current_state == State.JUMPING or current_state == State.FALLING

func is_grounded() -> bool:
	return current_state == State.IDLE or current_state == State.WALKING or current_state == State.RUNNING or current_state == State.LANDING

func get_debug_info() -> Dictionary:
	return {
		"state_current": get_current_state(),
		"state_previous": get_previous_state(),
		"state_time_in_current": get_time_in_current_state(),
		"state_is_airborne": is_airborne(),
		"state_is_grounded": is_grounded(),
		"state_was_airborne": was_airborne
	}