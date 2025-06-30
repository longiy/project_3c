# CharacterStateMachine3C.gd - Updated state machine for 3C architecture
extends Node
class_name CharacterStateMachine3C

# === SIGNALS ===
signal state_changed(old_state_name: String, new_state_name: String)
signal state_entered(state_name: String)
signal state_exited(state_name: String)
signal character_state_changed(old_state: String, new_state: String)
signal state_changed_for_camera(state_name: String)

# === 3C CAMERA INTEGRATION ===
@export_group("3C Camera Integration")
@export var camera_3c_manager: Camera3CManager
@export var enable_camera_responses = true

@export_group("3C Camera State Values")
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
	
	setup_3c_camera_connection()
	setup_states_from_nodes()

func setup_3c_camera_connection():
	"""Setup 3C camera manager connection"""
	if not camera_3c_manager and enable_camera_responses:
		# Try to find camera 3C manager automatically
		camera_3c_manager = get_node_or_null("../../CAMERARIG") as Camera3CManager
		if camera_3c_manager:
			print("✅ CharacterStateMachine3C: Found Camera3CManager automatically")
		else:
			print("⚠️ CharacterStateMachine3C: No Camera3CManager found - set camera_3c_manager property")

func setup_states_from_nodes():
	if state_nodes.is_empty():
		push_error("No state nodes assigned! Please assign state nodes in the inspector.")
		return
	
	for state_node in state_nodes:
		if state_node:
			var state_name = get_state_name_from_node(state_node)
			if state_name != "":
				create_state(state_name, state_node)
			else:
				push_warning("Could not determine state name for node: " + str(state_node))
		else:
			push_warning("Invalid state node: " + str(state_node))
	
	if not validate_state_setup():
		return
	
	start(initial_state_name)
	print("✅ CharacterStateMachine3C: Setup complete with ", states.size(), " states")

func get_state_name_from_node(state_node: Node) -> String:
	# Since all states now have get_state_name() method, just use that
	if state_node.has_method("get_state_name"):
		return state_node.get_state_name()
	
	# Fallback: extract from node name (StateIdle -> "idle")
	return extract_state_name(state_node.name)

func extract_state_name(node_name: String) -> String:
	# Extract state name from node name
	var clean_name = node_name.to_lower()
	if clean_name.begins_with("state"):
		clean_name = clean_name.substr(5)  # Remove "state" prefix
	return clean_name

func create_state(state_name: String, state_node: Node):
	"""Create a state from a node"""
	if state_name in states:
		push_warning("State already exists: " + state_name)
		return
	
	# Set up the state node safely
	if "state_name" in state_node:
		state_node.state_name = state_name
	
	if "owner_node" in state_node:
		state_node.owner_node = owner_node
	
	# Only set state_machine if the property exists
	if "state_machine" in state_node:
		state_node.state_machine = self
	
	states[state_name] = state_node
	states_created += 1
	
	if enable_debug_transitions:
		print("📝 Created state: ", state_name, " from node: ", state_node.name)

func start(initial_state: String = ""):
	"""Start the state machine"""
	var start_state = initial_state if initial_state != "" else initial_state_name
	
	if not has_state(start_state):
		push_error("Initial state does not exist: " + start_state)
		return
	
	change_state(start_state)

func update(delta: float):
	"""Update current state"""
	if current_state and current_state.has_method("update"):
		current_state.update(delta)

func change_state(new_state_name: String):
	"""Change to a new state"""
	if not has_state(new_state_name):
		push_error("State does not exist: " + new_state_name)
		return
	
	var old_state_name = get_current_state_name()
	
	# Exit current state
	if current_state:
		current_state.exit()
		state_exited.emit(old_state_name)
		previous_state = current_state
	
	# Enter new state
	current_state = states[new_state_name]
	current_state.enter()
	
	# Update history
	if enable_state_history:
		update_state_history(new_state_name)
	
	transition_count += 1
	
	# Emit signals
	state_entered.emit(new_state_name)
	state_changed.emit(old_state_name, new_state_name)
	character_state_changed.emit(old_state_name, new_state_name)
	state_changed_for_camera.emit(new_state_name)
	
	# Handle 3C camera response
	if enable_camera_responses and camera_3c_manager:
		handle_3c_camera_response(new_state_name)

func handle_3c_camera_response(state_name: String):
	"""Handle camera response to state change using 3C architecture"""
	if not camera_3c_manager:
		return
	
	match state_name:
		"idle":
			apply_camera_state_3c(idle_fov, idle_distance, idle_transition_time)
		"walking":
			apply_camera_state_3c(walking_fov, walking_distance, walking_transition_time)
		"running":
			apply_camera_state_3c(running_fov, running_distance, running_transition_time)
		"jumping":
			apply_camera_state_3c(jumping_fov, jumping_distance, jumping_transition_time)
		"airborne":
			apply_camera_state_3c(airborne_fov, airborne_distance, airborne_transition_time)
		"landing":
			apply_camera_state_3c(landing_fov, landing_distance, landing_transition_time)

func apply_camera_state_3c(target_fov: float, target_distance: float, transition_time: float):
	"""Apply camera state changes through 3C manager"""
	if camera_3c_manager:
		camera_3c_manager.smooth_fov_transition(target_fov, transition_time)
		camera_3c_manager.smooth_distance_transition(target_distance, transition_time)

# === STATE MANAGEMENT ===

func has_state(state_name: String) -> bool:
	"""Check if state exists"""
	return state_name in states

func get_current_state_name() -> String:
	"""Get current state name"""
	return current_state.state_name if current_state else ""

func get_previous_state_name() -> String:
	"""Get previous state name"""
	return previous_state.state_name if previous_state else ""

func get_current_state() -> State:
	"""Get current state object"""
	return current_state

func get_state_history() -> Array[String]:
	"""Get state history"""
	return state_history.duplicate()

func update_state_history(state_name: String):
	"""Update state history"""
	state_history.append(state_name)
	if state_history.size() > max_history_size:
		state_history.pop_front()

func force_state_change(state_name: String):
	"""Force a state change (for debugging)"""
	if enable_debug_transitions:
		print("🔧 Forcing state change to: ", state_name)
	change_state(state_name)

# === DEBUG AND UTILITY ===

func _on_debug_state_change(old_state: String, new_state: String):
	"""Debug output for state changes"""
	if owner_node:
		var character = owner_node as Character3CManager
		if character:
			var speed = character.velocity.length()
			var grounded = character.is_on_floor()
			var movement_mode = character.current_movement_mode
			
			print("🔄 [", transition_count, "] ", old_state, " → ", new_state, 
				  " | Speed: ", "%.1f" % speed, 
				  " | Grounded: ", grounded,
				  " | Mode: ", movement_mode)

func validate_state_setup() -> bool:
	"""Validate that required states exist"""
	var required_states = ["idle", "walking", "running", "jumping", "airborne", "landing"]
	var missing_states = []
	
	for state_name in required_states:
		if not has_state(state_name):
			missing_states.append(state_name)
	
	if missing_states.size() > 0:
		push_warning("Some required states missing: " + str(missing_states) + " - continuing anyway")
		# Don't return false, just warn and continue
	
	return true

func get_state_transition_summary() -> Dictionary:
	"""Get comprehensive state machine information"""
	return {
		"total_transitions": transition_count,
		"states_created": states_created,
		"current_state": get_current_state_name(),
		"previous_state": get_previous_state_name(),
		"recent_history": get_state_history() if enable_state_history else [],
		"time_in_current": current_state.time_in_state if current_state else 0.0,
		"state_nodes_count": state_nodes.size(),
		"has_current_node": get_current_state_node() != null,
		"camera_3c_connected": camera_3c_manager != null,
		"camera_responses_enabled": enable_camera_responses,
		"3c_camera_mode": camera_3c_manager.get_current_mode() if camera_3c_manager else "none"
	}

func get_current_state_node() -> Node:
	"""Get current state node"""
	return get_state_node(get_current_state_name())

func get_state_node(state_name: String) -> Node:
	"""Get state node by name"""
	if not has_state(state_name):
		return null
	
	var state = states[state_name]
	return state if state is Node else null

func is_in_movement_state() -> bool:
	"""Check if in movement state"""
	return get_current_state_name() in ["walking", "running"]

func is_in_air_state() -> bool:
	"""Check if in air state"""
	return get_current_state_name() in ["jumping", "airborne"]

func is_in_ground_state() -> bool:
	"""Check if in ground state"""
	return get_current_state_name() in ["idle", "walking", "running", "landing"]

# === 3C INTEGRATION ===

func configure_camera_from_3c(config: CharacterConfig):
	"""Configure camera responses based on 3C config"""
	if not config:
		return
	
	# Update camera values based on 3C configuration
	match config.camera_type:
		CharacterConfig.CameraType.ORBITAL:
			# More dynamic camera for orbital
			running_fov = 75.0
			jumping_fov = 90.0
		CharacterConfig.CameraType.FOLLOWING:
			# Steadier camera for following
			running_fov = 65.0
			jumping_fov = 70.0
		CharacterConfig.CameraType.FIXED:
			# Minimal camera changes for fixed
			running_fov = config.camera_fov
			jumping_fov = config.camera_fov

func get_3c_debug_info() -> Dictionary:
	"""Get 3C-specific debug information"""
	return {
		"camera_3c_manager": camera_3c_manager != null,
		"camera_mode": camera_3c_manager.get_mode_name(camera_3c_manager.get_current_mode()) if camera_3c_manager else "none",
		"camera_responses_enabled": enable_camera_responses,
		"current_camera_fov": camera_3c_manager.camera.fov if camera_3c_manager and camera_3c_manager.camera else 0.0,
		"current_camera_distance": camera_3c_manager.target_distance if camera_3c_manager else 0.0
	}
