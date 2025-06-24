# CharacterStateMachine.gd - Streamlined state machine for focused states
extends StateMachine
class_name CharacterStateMachine

@export_group("State Configuration")
@export var enable_debug_transitions = false
@export var enable_state_history = true
@export var max_history_entries = 8

# State tracking for better debugging
var transition_count = 0
var states_created = 0

func _ready():
	super._ready()
	
	if enable_state_history:
		max_history_size = max_history_entries
	
	# Connect signals for enhanced debugging
	if enable_debug_transitions:
		state_changed.connect(_on_debug_state_change)

func add_state(state_name: String, state: State):
	"""Enhanced state addition with automatic setup"""
	super.add_state(state_name, state)
	states_created += 1
	
	if enable_debug_transitions:
		print("➕ Added state: ", state_name, " (Total: ", states_created, ")")

func change_state(new_state_name: String):
	"""Enhanced state change with transition counting"""
	var old_state_name = get_current_state_name()
	super.change_state(new_state_name)
	
	if old_state_name != new_state_name:
		transition_count += 1

func setup_basic_movement_states():
	"""Automatically create and configure all basic movement states"""
	# Core movement states
	add_state("idle", StateIdle.new())
	add_state("walking", StateWalking.new())
	add_state("running", StateRunning.new())
	add_state("jumping", StateJumping.new())
	add_state("airborne", StateAirborne.new())
	add_state("landing", StateLanding.new())
	
	print("✅ Character State Machine: Setup complete with ", states.size(), " states")

func setup_extended_states():
	"""Add extended states for advanced features"""
	# Future extended states
	# add_state("sliding", StateSliding.new())
	# add_state("dashing", StateDashing.new())  
	# add_state("climbing", StateClimbing.new())
	# add_state("swimming", StateSwimming.new())
	
	print("🔧 Extended states ready for implementation")

func get_movement_state_info() -> Dictionary:
	"""Get movement-specific state information"""
	var current = get_current_state_name()
	var character = owner_node as CharacterBody3D
	
	return {
		"current_state": current,
		"is_grounded_state": current in ["idle", "walking", "running", "landing"],
		"is_airborne_state": current in ["jumping", "airborne"],
		"is_moving_state": current in ["walking", "running"],
		"character_speed": character.get_movement_speed() if character else 0.0,
		"character_grounded": character.is_on_floor() if character else false
	}

func force_state_refresh():
	"""Force reevaluation of current state (useful for debugging)"""
	if current_state:
		var state_name = current_state.state_name
		current_state.exit()
		current_state.enter()
		
		if enable_debug_transitions:
			print("🔄 Force refreshed state: ", state_name)

func get_state_transition_summary() -> Dictionary:
	"""Get summary of state transitions for debugging"""
	return {
		"total_transitions": transition_count,
		"states_created": states_created,
		"current_state": get_current_state_name(),
		"previous_state": get_previous_state_name(),
		"recent_history": get_state_history() if enable_state_history else [],
		"time_in_current": current_state.time_in_state if current_state else 0.0
	}

func _on_debug_state_change(old_state: String, new_state: String):
	"""Debug callback for state changes"""
	var character = owner_node as CharacterBody3D
	var speed = character.get_movement_speed() if character else 0.0
	var grounded = character.is_on_floor() if character else false
	
	print("🔄 [", transition_count, "] ", old_state, " → ", new_state, 
		  " | Speed: ", "%.1f" % speed, 
		  " | Grounded: ", grounded)

# === UTILITY METHODS FOR STATES ===

func is_in_movement_state() -> bool:
	"""Check if currently in any movement state"""
	return get_current_state_name() in ["walking", "running"]

func is_in_air_state() -> bool:
	"""Check if currently in any air state"""
	return get_current_state_name() in ["jumping", "airborne"]

func is_in_ground_state() -> bool:
	"""Check if currently in any ground state"""
	return get_current_state_name() in ["idle", "walking", "running", "landing"]

func can_transition_to_air() -> bool:
	"""Check if current state allows air transitions"""
	return is_in_ground_state()

func can_transition_to_ground() -> bool:
	"""Check if current state allows ground transitions"""
	return is_in_air_state()

# === STATE VALIDATION ===

func validate_state_setup() -> bool:
	"""Validate that all required states are present"""
	var required_states = ["idle", "walking", "running", "jumping", "airborne", "landing"]
	var missing_states = []
	
	for state_name in required_states:
		if not has_state(state_name):
			missing_states.append(state_name)
	
	if missing_states.size() > 0:
		push_error("Missing required states: " + str(missing_states))
		return false
	
	return true

func get_debug_overlay_info() -> Dictionary:
	"""Get formatted info for debug overlay"""
	var info = get_state_transition_summary()
	var movement_info = get_movement_state_info()
	
	return {
		"state_line": "%s (%.1fs)" % [movement_info.current_state, info.time_in_current],
		"transition_line": "Transitions: %d | Previous: %s" % [info.total_transitions, info.previous_state],
		"physics_line": "Speed: %.1f | Grounded: %s" % [movement_info.character_speed, movement_info.character_grounded],
		"history_line": "Recent: %s" % " → ".join(info.recent_history.slice(-3)) if info.recent_history.size() > 0 else "Recent: None"
	}
