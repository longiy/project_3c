# CharacterStateMachine.gd - Enhanced with direct camera integration
extends Node
class_name CharacterStateMachine

# === SIGNALS ===
signal state_changed(old_state_name: String, new_state_name: String)
signal state_entered(state_name: String)
signal state_exited(state_name: String)
signal character_state_changed(old_state: String, new_state: String)
signal state_changed_for_camera(state_name: String)

# === CAMERA INTEGRATION ===
@export_group("Camera Integration")
@export var camera_rig: CameraRig
@export var enable_camera_responses = true

@export_group("Camera State Values")
@export var idle_fov = 50.0
@export var idle_distance = 4.0
@export var idle_transition_time = 0.3

@export var walking_fov = 60.0
@export var walking_distance = 4.0
@export var walking_transition_time = 0.3

@export var running_fov = 70.0
@export var running_distance = 4.5
@export var running_transition_time = 0.3

@export var jumping_fov = 85.0
@export var jumping_distance = 4.8
@export var jumping_transition_time = 0.1

@export var airborne_fov = 90.0
@export var airborne_distance = 5.0
@export var airborne_transition_time = 0.3

@export var landing_fov = 75.0
@export var landing_distance = 4.0
@export var landing_transition_time = 0.1

# === STATE MACHINE CORE ===
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

var transition_count = 0
var states_created = 0

func _ready():
	owner_node = get_parent()
	
	if enable_state_history:
		max_history_size = max_history_entries
	
	if enable_debug_transitions:
		state_changed.connect(_on_debug_state_change)
	
	setup_camera_connection()
	setup_states_from_nodes()

func setup_camera_connection():
	"""Setup camera rig connection"""
	if not camera_rig and enable_camera_responses:
		# Try to find camera rig automatically
		camera_rig = get_node_or_null("../../CAMERARIG") as CameraRig
		if camera_rig:
			print("✅ CharacterStateMachine: Found CameraRig automatically")
		else:
			print("⚠️ CharacterStateMachine: No CameraRig found - set camera_rig property")

func setup_states_from_nodes():
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
		
		var state_name = extract_state_name(state_node.name)
		var state_instance = state_node
		state_instance.state_node = state_node
		add_state(state_name, state_instance)
	
	if has_state(initial_state_name):
		change_state(initial_state_name)
	else:
		push_error("Initial state '" + initial_state_name + "' not found!")

func extract_state_name(node_name: String) -> String:
	"""Extract state name from node name"""
	var clean_name = node_name.to_lower()
	if clean_name.ends_with("state"):
		clean_name = clean_name.substr(0, clean_name.length() - 5)
	return clean_name

func add_state(state_name: String, state_instance: State):
	"""Add a state to the state machine"""
	if states.has(state_name):
		push_warning("State '" + state_name + "' already exists - overwriting")
	
	state_instance.state_machine = self
	state_instance.owner_node = owner_node
	state_instance.state_name = state_name
	states[state_name] = state_instance
	states_created += 1

func change_state(new_state_name: String):
	"""Change to a new state"""
	if not states.has(new_state_name):
		push_error("State '" + new_state_name + "' not found!")
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
	
	# Update history
	if enable_state_history:
		state_history.append(new_state_name)
		if state_history.size() > max_history_size:
			state_history.pop_front()
	
	# Emit signals
	state_changed.emit(old_state_name, new_state_name)
	character_state_changed.emit(old_state_name, new_state_name)
	
	state_changed_for_camera.emit(new_state_name)
	# NEW: Handle camera response
	handle_camera_response(new_state_name)

# === NEW: CAMERA RESPONSE HANDLING ===

func handle_camera_response(state_name: String):
	"""Handle camera response to state change"""
	if not enable_camera_responses or not camera_rig:
		return
	
	var camera_data = get_camera_data_for_state(state_name)
	if camera_data:
		camera_rig.respond_to_character_state(
			state_name,
			camera_data.fov,
			camera_data.distance,
			camera_data.transition_time
		)

func get_camera_data_for_state(state_name: String) -> Dictionary:
	"""Get camera response data for a state"""
	match state_name:
		"idle":
			return {
				"fov": idle_fov,
				"distance": idle_distance,
				"transition_time": idle_transition_time
			}
		"walking":
			return {
				"fov": walking_fov,
				"distance": walking_distance,
				"transition_time": walking_transition_time
			}
		"running":
			return {
				"fov": running_fov,
				"distance": running_distance,
				"transition_time": running_transition_time
			}
		"jumping":
			return {
				"fov": jumping_fov,
				"distance": jumping_distance,
				"transition_time": jumping_transition_time
			}
		"airborne":
			return {
				"fov": airborne_fov,
				"distance": airborne_distance,
				"transition_time": airborne_transition_time
			}
		"landing":
			return {
				"fov": landing_fov,
				"distance": landing_distance,
				"transition_time": landing_transition_time
			}
		_:
			# Return default values
			return {
				"fov": camera_rig.default_fov if camera_rig else 75.0,
				"distance": camera_rig.default_distance if camera_rig else 4.0,
				"transition_time": 0.3
			}

# === CAMERA CONTROL API ===

func emit_camera_change(state_name: String, fov: float, distance: float, transition_time: float = 0.3):
	"""Direct method for states to trigger camera changes"""
	if enable_camera_responses and camera_rig:
		camera_rig.respond_to_character_state(state_name, fov, distance, transition_time)

func set_camera_enabled(enabled: bool):
	"""Enable/disable camera responses"""
	enable_camera_responses = enabled
	print("📹 CharacterStateMachine: Camera responses ", "enabled" if enabled else "disabled")

# === CORE STATE MACHINE METHODS ===

func update(delta: float):
	if current_state:
		current_state.update(delta)

func handle_input(event: InputEvent):
	if current_state:
		current_state.handle_input(event)

func has_state(state_name: String) -> bool:
	return states.has(state_name)

func get_current_state_name() -> String:
	return current_state.state_name if current_state else "none"

func get_previous_state_name() -> String:
	return previous_state.state_name if previous_state else "none"

func get_state_history() -> Array[String]:
	return state_history.duplicate()

# === DEBUG AND VALIDATION ===

func _on_debug_state_change(old_state: String, new_state: String):
	"""Debug callback for state changes - only when enabled"""
	if old_state != new_state:
		transition_count += 1
		# Only print if debug enabled
		if enable_debug_transitions:
			var character = owner_node as CharacterBody3D
			var speed = character.get_movement_speed() if character else 0.0
			var grounded = character.is_on_floor() if character else false
			
			print("🔄 [", transition_count, "] ", old_state, " → ", new_state, 
				  " | Speed: ", "%.1f" % speed, 
				  " | Grounded: ", grounded)

func validate_state_setup() -> bool:
	var required_states = ["idle", "walking", "running", "jumping", "airborne", "landing"]
	var missing_states = []
	
	for state_name in required_states:
		if not has_state(state_name):
			missing_states.append(state_name)
	
	if missing_states.size() > 0:
		push_error("Missing required states: " + str(missing_states))
		return false
	
	return true

func get_state_transition_summary() -> Dictionary:
	return {
		"total_transitions": transition_count,
		"states_created": states_created,
		"current_state": get_current_state_name(),
		"previous_state": get_previous_state_name(),
		"recent_history": get_state_history() if enable_state_history else [],
		"time_in_current": current_state.time_in_state if current_state else 0.0,
		"state_nodes_count": state_nodes.size(),
		"has_current_node": get_current_state_node() != null,
		"camera_connected": camera_rig != null,
		"camera_responses_enabled": enable_camera_responses
	}

func get_current_state_node() -> Node:
	return get_state_node(get_current_state_name())

func get_state_node(state_name: String) -> Node:
	if not has_state(state_name):
		return null
	
	var state = states[state_name]
	return state.state_node if state.has_method("get") and state.get("state_node") else null

func is_in_movement_state() -> bool:
	return get_current_state_name() in ["walking", "running"]

func is_in_air_state() -> bool:
	return get_current_state_name() in ["jumping", "airborne"]

func is_in_ground_state() -> bool:
	return get_current_state_name() in ["idle", "walking", "running", "landing"]
