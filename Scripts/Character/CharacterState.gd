# CharacterState.gd - 3C Framework aligned state management
extends Node
class_name CharacterState

# === SIGNALS ===
signal state_changed(old_state_name: String, new_state_name: String)
signal state_entered(state_name: String)
signal state_exited(state_name: String)
signal state_changed_for_camera(state_name: String)

# === 3C FRAMEWORK INTEGRATION ===
signal character_embodiment_changed(embodiment_quality: float)
signal character_responsiveness_changed(responsiveness: float)

# === SETTINGS ===
@export_group("State Configuration")
@export var initial_state_name: String = "idle"
@export var enable_debug_transitions = false
@export var enable_state_history = true
@export var max_history_entries = 8

@export_group("3C Framework")
@export var enable_3c_adaptation = true
@export var embodiment_adaptation_speed = 2.0
@export var responsiveness_adaptation_speed = 3.0

# === CHARACTER REFERENCE ===
var character: CharacterBody3D

# === STATE MACHINE CORE ===
var current_state: State = null
var previous_state: State = null
var states: Dictionary = {}
var state_history: Array[String] = []

# === 3C FRAMEWORK STATE ===
var state_3c_configs: Dictionary = {}
var current_embodiment_quality: float = 1.0
var current_responsiveness: float = 1.0
var target_embodiment_quality: float = 1.0
var target_responsiveness: float = 1.0

# Debug tracking
var transition_count = 0
var states_created = 0

# === COMPATIBILITY INTERFACE ===
var owner_node: Node:
	get:
		return character

func setup_character_reference(char: CharacterBody3D):
	"""Setup character reference and initialize state machine"""
	character = char
	
	if enable_debug_transitions:
		state_changed.connect(_on_debug_state_change)
	
	# Initialize 3C framework
	if enable_3c_adaptation:
		setup_3c_state_configs()
	
	# Setup states from character's existing state nodes
	call_deferred("setup_states_from_character")

# === 3C FRAMEWORK SETUP ===

func setup_3c_state_configs():
	"""Setup 3C configurations for different states"""
	
	# Character Axis configurations per state
	state_3c_configs = {
		"idle": {
			"embodiment_quality": 0.8,  # Relaxed embodiment
			"responsiveness": 1.0,      # Fully responsive
			"temporal_scope": "moment", # Immediate response
			"description": "Avatar at rest, ready for input"
		},
		"walking": {
			"embodiment_quality": 1.0,  # Full embodiment
			"responsiveness": 1.0,      # Fully responsive
			"temporal_scope": "action", # Sustained movement
			"description": "Avatar in deliberate motion"
		},
		"running": {
			"embodiment_quality": 1.2,  # Enhanced embodiment
			"responsiveness": 0.9,      # Slightly less responsive
			"temporal_scope": "flow",   # Flow state
			"description": "Avatar in committed motion"
		},
		"jumping": {
			"embodiment_quality": 1.5,  # Maximum embodiment
			"responsiveness": 0.7,      # Reduced responsiveness
			"temporal_scope": "commitment", # Committed action
			"description": "Avatar in ballistic motion"
		},
		"airborne": {
			"embodiment_quality": 1.3,  # High embodiment
			"responsiveness": 0.8,      # Limited air control
			"temporal_scope": "momentum", # Physics-driven
			"description": "Avatar subject to gravity"
		},
		"landing": {
			"embodiment_quality": 1.1,  # Recovery embodiment
			"responsiveness": 0.6,      # Temporarily unresponsive
			"temporal_scope": "recovery", # Brief recovery
			"description": "Avatar recovering from impact"
		}
	}
	
	print("✅ CharacterState: 3C framework configurations loaded")

func _process(delta):
	"""Update 3C framework adaptations"""
	if enable_3c_adaptation:
		update_3c_adaptations(delta)

func update_3c_adaptations(delta: float):
	"""Smooth adaptation of 3C parameters based on state"""
	# Smoothly interpolate to target values
	current_embodiment_quality = lerp(
		current_embodiment_quality, 
		target_embodiment_quality, 
		embodiment_adaptation_speed * delta
	)
	
	current_responsiveness = lerp(
		current_responsiveness,
		target_responsiveness,
		responsiveness_adaptation_speed * delta
	)
	
	# Emit changes for other systems
	character_embodiment_changed.emit(current_embodiment_quality)
	character_responsiveness_changed.emit(current_responsiveness)

# === STATE MANAGEMENT WITH 3C INTEGRATION ===

func setup_states_from_character():
	"""Find and setup states from character's existing state machine"""
	# Find existing CharacterStateMachine node
	var old_state_machine = character.get_node_or_null("CharacterStateMachine")
	if not old_state_machine:
		push_error("CharacterState: No existing CharacterStateMachine found!")
		return
	
	# Check if it has state_nodes property
	if not "state_nodes" in old_state_machine:
		push_error("CharacterState: CharacterStateMachine missing state_nodes property!")
		return
	
	# Extract state nodes from old state machine
	var state_nodes = old_state_machine.state_nodes
	if state_nodes.is_empty():
		push_error("CharacterState: No state nodes found in existing state machine!")
		return
	
	# Setup states from existing nodes
	for state_node in state_nodes:
		if not state_node or not state_node.script:
			continue
		
		var state_name = extract_state_name(state_node.name)
		add_state(state_name, state_node)
	
	# Start with initial state
	if has_state(initial_state_name):
		change_state(initial_state_name)
	else:
		push_error("CharacterState: Initial state '" + initial_state_name + "' not found!")

func extract_state_name(node_name: String) -> String:
	"""Extract state name from node name"""
	var clean_name = node_name.to_lower()
	if clean_name.ends_with("state"):
		clean_name = clean_name.substr(0, clean_name.length() - 5)
	return clean_name

func add_state(state_name: String, state_instance: State):
	"""Add a state to the state machine with compatibility handling"""
	if states.has(state_name):
		push_warning("CharacterState: State '" + state_name + "' already exists - overwriting")
	
	# Setup state references - handle compatibility with both old and new systems
	state_instance.state_machine = self  # This works because State.state_machine is untyped
	state_instance.owner_node = character
	state_instance.state_name = state_name
	
	# Store state
	states[state_name] = state_instance
	states_created += 1
	
	print("✅ CharacterState: Added state: ", state_name)

func change_state(new_state_name: String):
	"""Change to a new state with 3C framework integration"""
	if not states.has(new_state_name):
		push_error("CharacterState: State '" + new_state_name + "' not found!")
		return
	
	var old_state_name = ""
	
	# Exit current state
	if current_state:
		old_state_name = current_state.state_name
		current_state.exit()
		state_exited.emit(old_state_name)
		previous_state = current_state
	
	# Enter new state
	current_state = states[new_state_name]
	current_state.enter()
	state_entered.emit(new_state_name)
	
	# Update 3C framework for new state
	if enable_3c_adaptation:
		apply_3c_configuration(new_state_name)
	
	# Update history
	if enable_state_history:
		state_history.append(new_state_name)
		if state_history.size() > max_history_entries:
			state_history.pop_front()
	
	# Emit signals
	state_changed.emit(old_state_name, new_state_name)
	state_changed_for_camera.emit(new_state_name)
	
	transition_count += 1

func apply_3c_configuration(state_name: String):
	"""Apply 3C framework configuration for the given state"""
	if not state_3c_configs.has(state_name):
		# Use default configuration
		target_embodiment_quality = 1.0
		target_responsiveness = 1.0
		return
	
	var config = state_3c_configs[state_name]
	target_embodiment_quality = config.get("embodiment_quality", 1.0)
	target_responsiveness = config.get("responsiveness", 1.0)
	
	if enable_debug_transitions:
		print("🎮 3C Config for ", state_name, 
			  " | Embodiment: ", target_embodiment_quality,
			  " | Responsiveness: ", target_responsiveness)

func update_state_machine(delta: float):
	"""Update current state - called from CharacterController"""
	if current_state:
		current_state.update(delta)

# === 3C FRAMEWORK PUBLIC API ===

func get_current_embodiment_quality() -> float:
	"""Get current character embodiment quality"""
	return current_embodiment_quality

func get_current_responsiveness() -> float:
	"""Get current character responsiveness"""
	return current_responsiveness

func get_state_3c_config(state_name: String) -> Dictionary:
	"""Get 3C configuration for a specific state"""
	return state_3c_configs.get(state_name, {})

func set_state_3c_config(state_name: String, config: Dictionary):
	"""Set 3C configuration for a specific state"""
	state_3c_configs[state_name] = config

func override_3c_temporarily(embodiment: float, responsiveness: float, duration: float):
	"""Temporarily override 3C parameters"""
	target_embodiment_quality = embodiment
	target_responsiveness = responsiveness
	
	# Restore after duration
	var restore_timer = get_tree().create_timer(duration)
	restore_timer.timeout.connect(_restore_3c_from_current_state)

func _restore_3c_from_current_state():
	"""Restore 3C configuration from current state"""
	if current_state:
		apply_3c_configuration(current_state.state_name)

# === STATE QUERIES ===

func has_state(state_name: String) -> bool:
	"""Check if state exists"""
	return states.has(state_name)

func get_current_state_name() -> String:
	"""Get current state name"""
	return current_state.state_name if current_state else "none"

func get_previous_state_name() -> String:
	"""Get previous state name"""
	return previous_state.state_name if previous_state else "none"

func get_state_history() -> Array[String]:
	"""Get state transition history"""
	return state_history.duplicate()

func get_current_state() -> State:
	"""Get current state object"""
	return current_state

# === STATE MACHINE RESET ===

func reset_to_initial_state():
	"""Reset state machine to initial state"""
	if has_state(initial_state_name):
		change_state(initial_state_name)
	
	# Reset 3C framework
	if enable_3c_adaptation:
		apply_3c_configuration(initial_state_name)
	
	# Clear history
	state_history.clear()
	
	print("🔄 CharacterState: Reset to initial state: ", initial_state_name)

# === DEBUG SYSTEM ===

func _on_debug_state_change(old_state: String, new_state: String):
	"""Debug callback for state changes"""
	if old_state != new_state:
		var speed = character.get_movement_speed() if character else 0.0
		var grounded = character.is_on_floor() if character else false
		
		print("🔄 [", transition_count, "] ", old_state, " → ", new_state, 
			  " | Speed: ", "%.1f" % speed, 
			  " | Grounded: ", grounded,
			  " | Embodiment: ", "%.2f" % target_embodiment_quality,
			  " | Responsiveness: ", "%.2f" % target_responsiveness)

func validate_state_setup() -> bool:
	"""Validate that all required states exist"""
	var required_states = ["idle", "walking", "running", "jumping", "airborne", "landing"]
	var missing_states = []
	
	for state_name in required_states:
		if not has_state(state_name):
			missing_states.append(state_name)
	
	if missing_states.size() > 0:
		push_error("CharacterState: Missing required states: " + str(missing_states))
		return false
	
	return true

# === CONFIGURATION ===

func set_initial_state(state_name: String):
	"""Set initial state name"""
	initial_state_name = state_name

func enable_debug(enabled: bool):
	"""Enable/disable debug transitions"""
	enable_debug_transitions = enabled
	
	if enabled and not state_changed.is_connected(_on_debug_state_change):
		state_changed.connect(_on_debug_state_change)
	elif not enabled and state_changed.is_connected(_on_debug_state_change):
		state_changed.disconnect(_on_debug_state_change)

func enable_3c_framework(enabled: bool):
	"""Enable/disable 3C framework integration"""
	enable_3c_adaptation = enabled
	
	if enabled:
		setup_3c_state_configs()

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get state machine debug information"""
	return {
		"current_state": get_current_state_name(),
		"previous_state": get_previous_state_name(),
		"total_states": states.size(),
		"states_created": states_created,
		"transition_count": transition_count,
		"state_history": get_state_history(),
		"available_states": states.keys(),
		"initial_state": initial_state_name,
		"debug_enabled": enable_debug_transitions,
		"history_enabled": enable_state_history,
		"3c_enabled": enable_3c_adaptation,
		"current_embodiment": current_embodiment_quality,
		"current_responsiveness": current_responsiveness,
		"target_embodiment": target_embodiment_quality,
		"target_responsiveness": target_responsiveness
	}
