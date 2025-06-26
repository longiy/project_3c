# CharacterStatesBase.gd - DIAGNOSTIC VERSION with debug prints
class_name CharacterStateBase
extends State

var character: CharacterBody3D
var action_system: ActionSystem

# Movement state (managed through actions)
var current_movement_vector: Vector2 = Vector2.ZERO
var movement_magnitude: float = 0.0
var movement_start_time: float = 0.0
var is_movement_active: bool = false

# Transition thresholds
var movement_stop_threshold: float = 0.1
var movement_start_threshold: float = 0.05

func enter():
	super.enter()
	character = owner_node as CharacterBody3D
	if not character:
		push_error("CharacterState requires CharacterBody3D owner")
		return
	
	action_system = character.get_node_or_null("ActionSystem")
	print("🔧 [", state_name, "] Entered state, action_system: ", action_system != null)

func update(delta: float):
	super.update(delta)
	
	# TEMPORARILY DISABLE common transitions to test basic movement
	# handle_common_transitions()

# === MOVEMENT ACTION HANDLERS ===

func handle_move_start_action(action: Action):
	current_movement_vector = action.get_movement_vector()
	movement_magnitude = action.context.get("magnitude", current_movement_vector.length())
	movement_start_time = Time.get_ticks_msec() / 1000.0
	is_movement_active = true
	
	print("🔧 [", state_name, "] Move START - Vector: ", current_movement_vector, " Magnitude: ", movement_magnitude)
	
	character.movement_state_changed.emit(true, current_movement_vector, movement_magnitude)
	on_movement_started(current_movement_vector, movement_magnitude)

func handle_move_update_action(action: Action):
	current_movement_vector = action.get_movement_vector()
	movement_magnitude = action.context.get("magnitude", current_movement_vector.length())
	
	print("🔧 [", state_name, "] Move UPDATE - Vector: ", current_movement_vector)
	
	character.movement_state_changed.emit(true, current_movement_vector, movement_magnitude)
	on_movement_updated(current_movement_vector, movement_magnitude)

func handle_move_end_action(action: Action):
	current_movement_vector = Vector2.ZERO
	movement_magnitude = 0.0
	is_movement_active = false
	
	print("🔧 [", state_name, "] Move END")
	
	character.movement_state_changed.emit(false, Vector2.ZERO, 0.0)
	on_movement_ended()

# === ACTION SYSTEM INTERFACE ===

func can_execute_action(action: Action) -> bool:
	match action.name:
		"move_start", "move_update", "move_end":
			return can_handle_movement_action(action)
		"sprint_start", "sprint_end", "slow_walk_start", "slow_walk_end":
			return can_handle_mode_action(action)
		"reset":
			return true
		_:
			return false

func execute_action(action: Action):
	print("🔧 [", state_name, "] Executing action: ", action.name)
	
	match action.name:
		"move_start":
			handle_move_start_action(action)
		"move_update":
			handle_move_update_action(action)
		"move_end":
			handle_move_end_action(action)
		"sprint_start":
			character.is_running = true
			character.emit_movement_mode_changes()
		"sprint_end":
			character.is_running = false
			character.emit_movement_mode_changes()
		"slow_walk_start":
			character.is_slow_walking = true
			character.emit_movement_mode_changes()
		"slow_walk_end":
			character.is_slow_walking = false
			character.emit_movement_mode_changes()
		"reset":
			character.reset_character()
		_:
			print("🔧 [", state_name, "] UNHANDLED action: ", action.name)

# === VIRTUAL METHODS FOR CHILD STATES ===

func on_movement_started(direction: Vector2, magnitude: float):
	pass

func on_movement_updated(direction: Vector2, magnitude: float):
	pass

func on_movement_ended():
	pass

# === CONDITION HELPERS ===

func can_handle_movement_action(action: Action) -> bool:
	return true

func can_handle_mode_action(action: Action) -> bool:
	return true

# === CONSOLIDATED TRANSITION LOGIC (DISABLED FOR DIAGNOSTIC) ===

func handle_common_transitions():
	"""Handle transitions common to all states - DISABLED for diagnostic"""
	# TEMPORARILY DISABLED to test basic movement
	pass

func should_transition_to_air() -> bool:
	var ground_states = ["idle", "walking", "running", "landing"]
	return state_name in ground_states and not character.is_on_floor()

func should_transition_to_ground() -> bool:
	var air_states = ["jumping", "airborne"]
	return state_name in air_states and character.is_on_floor()

func can_do_movement_transitions() -> bool:
	var no_movement_transition_states = ["jumping", "landing"]
	return not (state_name in no_movement_transition_states)

func handle_movement_transitions():
	"""Handle movement-based state transitions - DISABLED for diagnostic"""
	print("🔧 [", state_name, "] handle_movement_transitions called - DISABLED for diagnostic")
	# TEMPORARILY DISABLED
	pass

func can_transition_to_idle() -> bool:
	return true

func get_target_movement_state() -> String:
	if not is_movement_active:
		return "idle"
	
	if character.is_running:
		return "running"
	else:
		return "walking"

# === MOVEMENT HELPERS ===

func get_current_movement_input() -> Vector2:
	return current_movement_vector

func get_movement_magnitude() -> float:
	return movement_magnitude

func get_movement_duration() -> float:
	if is_movement_active:
		return (Time.get_ticks_msec() / 1000.0) - movement_start_time
	return 0.0

func transition_and_forward_action(new_state_name: String, action: Action):
	change_to(new_state_name)
	
	if state_machine and state_machine.current_state:
		var new_state = state_machine.current_state
		if new_state != self and new_state.has_method("execute_action"):
			print("🔧 Forwarding action ", action.name, " to new state: ", new_state_name)
			new_state.execute_action(action)
