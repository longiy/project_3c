class_name CCC_CharacterActions
extends Node

@export_group("Jump Settings")
@export var jump_velocity: float = 4.5
@export var max_jump_buffer_time: float = 0.1
@export var max_coyote_time: float = 0.1
@export var variable_jump_height: bool = true
@export var min_jump_height_factor: float = 0.3

@export_group("Action Settings")
@export var action_cooldown: float = 0.5

var character: CharacterBody3D
var character_physics: CCC_CharacterPhysics

var jump_buffer_timer: float = 0.0
var coyote_timer: float = 0.0
var is_jumping: bool = false
var jump_held: bool = false
var was_on_floor_last_frame: bool = false
var last_action_time: float = 0.0

signal action_triggered(action_name: String)
signal jump_started()
signal jump_ended()

func _ready():
	if not character:
		character = get_parent() as CharacterBody3D
	
	# Find physics component
	for child in character.get_children():
		if child is CCC_CharacterPhysics:
			character_physics = child
			break

func process_actions(delta: float):
	update_jump_timers(delta)
	handle_jump_logic()

func trigger_action(action: String):
	match action:
		"jump":
			request_jump()
		"jump_release":
			release_jump()
		_:
			# Generic action handling
			if can_perform_action():
				action_triggered.emit(action)
				last_action_time = Time.get_ticks_msec() / 1000.0

func request_jump():
	jump_held = true
	jump_buffer_timer = max_jump_buffer_time

func release_jump():
	jump_held = false

func update_jump_timers(delta: float):
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta
	
	# Update coyote time
	if character.is_on_floor():
		coyote_timer = max_coyote_time
		was_on_floor_last_frame = true
	else:
		if was_on_floor_last_frame:
			coyote_timer = max_coyote_time
		else:
			coyote_timer -= delta
		was_on_floor_last_frame = false

func handle_jump_logic():
	# Start jump
	if can_jump() and jump_buffer_timer > 0:
		perform_jump()
	
	# Variable jump height
	if variable_jump_height and is_jumping and not jump_held:
		apply_variable_jump_height()

func can_jump() -> bool:
	return (character.is_on_floor() or coyote_timer > 0) and not is_jumping

func perform_jump():
	if character_physics:
		character_physics.add_impulse(Vector3(0, jump_velocity, 0))
	else:
		character.velocity.y = jump_velocity
	
	is_jumping = true
	jump_buffer_timer = 0.0
	coyote_timer = 0.0
	jump_started.emit()

func apply_variable_jump_height():
	if character.velocity.y > jump_velocity * min_jump_height_factor:
		character.velocity.y = jump_velocity * min_jump_height_factor
	is_jumping = false
	jump_ended.emit()

func can_perform_action() -> bool:
	return (Time.get_ticks_msec() / 1000.0) - last_action_time >= action_cooldown

func reset_jump_state():
	if character.is_on_floor() and character.velocity.y <= 0:
		is_jumping = false

func get_debug_info() -> Dictionary:
	return {
		"actions_jump_buffer": jump_buffer_timer,
		"actions_coyote_time": coyote_timer,
		"actions_is_jumping": is_jumping,
		"actions_jump_held": jump_held,
		"actions_can_jump": can_jump(),
		"actions_last_action_time": last_action_time
	}
