# CharacterStateMachine.gd - Node-based state system with drag-and-drop configuration
extends Node
class_name CharacterStateMachine

# Base state machine functionality
signal state_changed(old_state_name: String, new_state_name: String)
signal state_entered(state_name: String)
signal state_exited(state_name: String)

var current_state: State = null
var previous_state: State = null
var states: Dictionary = {}
var owner_node: Node
var state_history: Array[String] = []
var max_history_size = 10

@export_group("State Configuration")
@export var state_nodes: Array[Node] = []
@export var initial_state_name: String = "idle"
@export var enable_debug_transitions = false
@export var enable_state_history = true
@export var max_history_entries = 8

# State tracking for better debugging
var transition_count = 0
var states_created = 0

func _ready():
	owner_node = get_parent()
	
	if enable_state_history:
		max_history_size = max_history_entries
	
	# Connect signals for enhanced debugging
	if enable_debug_transitions:
		state_changed.connect(_on_debug_state_change)
	
	# Setup states from nodes
	setup_states_from_nodes()

# === BASE STATE MACHINE FUNCTIONALITY ===

func get_current_state_name() -> String:
	"""Get current state name"""
	return current_state.state_name if current_state else "none"

func get_previous_state_name() -> String:
	"""Get previous state name"""
	return previous_state.state_name if previous_state else "none"

func update(delta: float):
	"""Call from parent's _physics_process"""
	if current_state:
		current_state.update(delta)

func handle_input(event: InputEvent):
	"""Call from parent's _input"""
	if current_state:
		current_state.handle_input(event)

func has_state(state_name: String) -> bool:
	"""Check if state exists"""
	return states.has(state_name)

func get_state_history() -> Array[String]:
	"""Get recent state history for debugging"""
	return state_history.duplicate()

func setup_states_from_nodes():
	"""Initialize states from the state_nodes array"""
	print("=== STATE MACHINE SETUP ===")
	
	if state_nodes.is_empty():
		push_error("No state nodes assigned! Please assign state nodes in the inspector.")
		return
	
	for state_node in state_nodes:
		if not state_node:
			push_warning("Null state node found in array")
			continue
		
		if not state_node.script:
			push_warning("State node " + state_node.name + " has no script assigned")
			continue
		
		# Extract state name from node name
		var state_name = extract_state_name(state_node.name)
		
		# Use the node itself as the state instance
		var state_instance = state_node
		
		# Set up state properties
		state_instance.state_node = state_node
		
		# Add to state machine
		add_state(state_name, state_instance)
		
		print("✅ Added state: ", state_name, " from node: ", state_node.name)
	
	# Start with initial state
	if has_state(initial_state_name):
		change_state(initial_state_name)
		print("🎯 Started with state: ", initial_state_name)
	else:
		push_error("Initial state '" + initial_state_name + "' not found!")
	
	print("✅ State machine setup complete with ", states.size(), " states")

func extract_state_name(node_name: String) -> String:
	"""Extract clean state name from node name"""
	var state_name = node_name.to_lower()
	
	# Remove common prefixes/suffixes
	state_name = state_name.replace("state", "")
	state_name = state_name.replace("node", "")
	state_name = state_name.strip_edges()
	
	# Handle empty result
	if state_name.is_empty():
		state_name = node_name.to_lower()
	
	return state_name

func add_state(state_name: String, state: State):
	"""Add a state to the machine with automatic setup"""
	if states.has(state_name):
		push_warning("State already exists: " + state_name)
		return
	
	states[state_name] = state
	state.state_machine = self
	state.owner_node = owner_node
	state.state_name = state_name
	states_created += 1
	
	if enable_debug_transitions:
		print("➕ Added state: ", state_name, " (Total: ", states_created, ")")

func change_state(new_state_name: String):
	"""Change to a different state with transition counting"""
	if not states.has(new_state_name):
		push_error("State not found: " + new_state_name)
		return
	
	if current_state and current_state.state_name == new_state_name:
		return  # Already in this state
	
	var old_state_name = current_state.state_name if current_state else "none"
	
	# Exit current state
	if current_state:
		current_state.exit()
		state_exited.emit(old_state_name)
		previous_state = current_state
	
	# Enter new state
	current_state = states[new_state_name]
	current_state.enter()
	
	# Update history
	state_history.append(new_state_name)
	if state_history.size() > max_history_size:
		state_history.pop_front()
	
	# Emit signals
	state_entered.emit(new_state_name)
	state_changed.emit(old_state_name, new_state_name)
	
	if old_state_name != new_state_name:
		transition_count += 1
		print("🔄 ", old_state_name, " → ", new_state_name)

# === STATE NODE ACCESS ===

func get_state_node(state_name: String) -> Node:
	"""Get the scene node associated with a state"""
	if not has_state(state_name):
		return null
	
	var state = states[state_name]
	return state.state_node if state.has_method("get") and state.get("state_node") else null

func get_current_state_node() -> Node:
	"""Get the scene node for the current state"""
	return get_state_node(get_current_state_name())

# === RUNTIME STATE MANAGEMENT ===

func add_runtime_state(state_name: String, state_script: Script) -> bool:
	"""Add a state at runtime without a scene node"""
	if has_state(state_name):
		push_warning("State already exists: " + state_name)
		return false
	
	var state_instance = state_script.new()
	add_state(state_name, state_instance)
	
	print("🔧 Added runtime state: ", state_name)
	return true

func remove_state(state_name: String) -> bool:
	"""Remove a state from the machine"""
	if not has_state(state_name):
		return false
	
	if get_current_state_name() == state_name:
		push_error("Cannot remove current state: " + state_name)
		return false
	
	states.erase(state_name)
	print("➖ Removed state: ", state_name)
	return true

# === VALIDATION ===

func validate_state_setup() -> bool:
	"""Validate that all required states are present and properly configured"""
	var required_states = ["idle", "walking", "running", "jumping", "airborne", "landing"]
	var missing_states = []
	var invalid_states = []
	
	# Check for missing states
	for state_name in required_states:
		if not has_state(state_name):
			missing_states.append(state_name)
	
	# Check for invalid state configurations
	for state_name in states.keys():
		var state = states[state_name]
		if not state.has_method("enter") or not state.has_method("update"):
			invalid_states.append(state_name)
	
	# Report issues
	if missing_states.size() > 0:
		push_error("Missing required states: " + str(missing_states))
	
	if invalid_states.size() > 0:
		push_error("Invalid state configurations: " + str(invalid_states))
	
	return missing_states.size() == 0 and invalid_states.size() == 0

# === INSPECTOR HELPERS ===

func _get_configuration_warnings() -> PackedStringArray:
	"""Provide warnings in the editor if states are not properly configured"""
	var warnings = PackedStringArray()
	
	if state_nodes.is_empty():
		warnings.append("No state nodes assigned. Please drag state nodes into the State Nodes array.")
	
	for i in range(state_nodes.size()):
		var node = state_nodes[i]
		if not node:
			warnings.append("State node slot " + str(i) + " is empty.")
		elif not node.script:
			warnings.append("State node '" + node.name + "' has no script assigned.")
	
	if initial_state_name.is_empty():
		warnings.append("No initial state specified.")
	
	return warnings

# === DEBUG INFO ===

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
		"character_grounded": character.is_on_floor() if character else false,
		"state_node_exists": get_current_state_node() != null
	}

func get_state_transition_summary() -> Dictionary:
	"""Get summary of state transitions for debugging"""
	return {
		"total_transitions": transition_count,
		"states_created": states_created,
		"current_state": get_current_state_name(),
		"previous_state": get_previous_state_name(),
		"recent_history": get_state_history() if enable_state_history else [],
		"time_in_current": current_state.time_in_state if current_state else 0.0,
		"state_nodes_count": state_nodes.size(),
		"has_current_node": get_current_state_node() != null
	}

func _on_debug_state_change(old_state: String, new_state: String):
	"""Debug callback for state changes"""
	var character = owner_node as CharacterBody3D
	var speed = character.get_movement_speed() if character else 0.0
	var grounded = character.is_on_floor() if character else false
	
	print("🔄 [", transition_count, "] ", old_state, " → ", new_state, 
		  " | Speed: ", "%.1f" % speed, 
		  " | Grounded: ", grounded)

# === UTILITY METHODS ===

func is_in_movement_state() -> bool:
	return get_current_state_name() in ["walking", "running"]

func is_in_air_state() -> bool:
	return get_current_state_name() in ["jumping", "airborne"]

func is_in_ground_state() -> bool:
	return get_current_state_name() in ["idle", "walking", "running", "landing"]

func force_state_refresh():
	"""Force reevaluation of current state"""
	if current_state:
		var state_name = current_state.state_name
		current_state.exit()
		current_state.enter()
		
		if enable_debug_transitions:
			print("🔄 Force refreshed state: ", state_name)

func get_debug_overlay_info() -> Dictionary:
	"""Get formatted info for debug overlay"""
	var info = get_state_transition_summary()
	var movement_info = get_movement_state_info()
	
	return {
		"state_line": "%s (%.1fs)" % [movement_info.current_state, info.time_in_current],
		"transition_line": "Transitions: %d | Previous: %s" % [info.total_transitions, info.previous_state],
		"physics_line": "Speed: %.1f | Grounded: %s" % [movement_info.character_speed, movement_info.character_grounded],
		"history_line": "Recent: %s" % " → ".join(info.recent_history.slice(-3)) if info.recent_history.size() > 0 else "Recent: None",
		"nodes_line": "State Nodes: %d | Current Node: %s" % [info.state_nodes_count, "Yes" if info.has_current_node else "No"]
	}
