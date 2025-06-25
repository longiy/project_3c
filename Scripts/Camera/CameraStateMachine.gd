# CameraStateMachine.gd - Node-based camera state responses with manual connections
extends Node
class_name CameraStateMachine

# Signals for communication
signal camera_state_changed(state_name: String)
signal camera_transition_started(state_name: String)
signal camera_transition_completed(state_name: String)

@export_group("References")
@export var character: CharacterBody3D
@export var camera: Camera3D
@export var spring_arm: SpringArm3D

@export_group("Manual Connection")
@export var character_state_machine: CharacterStateMachine

@export_group("Component Control")
@export var enable_camera_state_machine = true

@export_group("Camera Response Configuration")
@export var camera_response_nodes: Array[Node] = []

@export_group("Default Settings")
@export var default_fov = 75.0
@export var default_distance = 4.0
@export var default_transition_speed = 0.3

# Camera state management
var camera_responses: Dictionary = {}
var current_camera_state: String = ""
var current_tween: Tween

# External control tracking
var is_external_control_active = false

func _ready():
	setup_camera_responses()
	setup_manual_connections()

func setup_camera_responses():
	"""Initialize camera responses from the response_nodes array"""
	print("=== CAMERA STATE MACHINE SETUP ===")
	
	if camera_response_nodes.is_empty():
		push_error("No camera response nodes assigned! Please assign response nodes in the inspector.")
		return
	
	for response_node in camera_response_nodes:
		if not response_node:
			push_warning("Null camera response node found in array")
			continue
		
		if not response_node.script:
			push_warning("Camera response node " + response_node.name + " has no script assigned")
			continue
		
		# Get target_state from the response node
		var target_state = get_response_property(response_node, "target_state", "")
		if target_state.is_empty():
			push_warning("Response node " + response_node.name + " has no target_state set")
			continue
		
		# Add to camera responses dictionary using target_state
		camera_responses[target_state] = response_node
		
		print("✅ Added camera response: ", target_state, " from node: ", response_node.name)
	
	print("✅ Camera state machine setup complete with ", camera_responses.size(), " responses")

func setup_manual_connections():
	"""Setup manually assigned connections"""
	if not enable_camera_state_machine:
		print("📹 CameraStateMachine: Disabled - skipping connections")
		return
	
	# Manual connection to assigned character state machine
	if character_state_machine:
		if character_state_machine.has_signal("state_changed"):
			character_state_machine.state_changed.connect(_on_character_state_changed)
			print("✅ CameraStateMachine: Manually connected to CharacterStateMachine")
		else:
			push_error("Assigned CharacterStateMachine has no state_changed signal")
	else:
		print("⚠️ CameraStateMachine: No CharacterStateMachine assigned - camera won't respond to character states")
	
	# Validate other references
	if not character:
		push_warning("No character assigned")
	if not camera:
		push_warning("No camera assigned")
	if not spring_arm:
		push_warning("No spring arm assigned")

# === MODULAR CONTROL API ===

func set_enabled(enabled: bool):
	"""Enable/disable the camera state machine"""
	enable_camera_state_machine = enabled
	print("📹 CameraStateMachine: ", "Enabled" if enabled else "Disabled")

func is_enabled() -> bool:
	return enable_camera_state_machine

func set_external_control_active(active: bool):
	"""Called by CameraCinema to pause/resume responses"""
	is_external_control_active = active
	
	if active:
		# Stop any active tween when external control takes over
		if current_tween:
			current_tween.kill()
		print("📹 CameraStateMachine: Paused due to external control")
	else:
		print("📹 CameraStateMachine: Resumed after external control")

# === MANUAL CONNECTION HELPERS ===

func connect_to_character_state_machine(state_machine: CharacterStateMachine) -> bool:
	"""Manually connect to a character state machine"""
	if not state_machine:
		push_error("Cannot connect to null state machine")
		return false
	
	if not state_machine.has_signal("state_changed"):
		push_error("State machine has no state_changed signal")
		return false
	
	# Disconnect existing connection if any
	if character_state_machine and character_state_machine.state_changed.is_connected(_on_character_state_changed):
		character_state_machine.state_changed.disconnect(_on_character_state_changed)
	
	# Connect to new state machine
	character_state_machine = state_machine
	character_state_machine.state_changed.connect(_on_character_state_changed)
	
	print("✅ CameraStateMachine: Connected to new CharacterStateMachine")
	return true

func disconnect_from_character_state_machine():
	"""Manually disconnect from character state machine"""
	if character_state_machine and character_state_machine.state_changed.is_connected(_on_character_state_changed):
		character_state_machine.state_changed.disconnect(_on_character_state_changed)
		character_state_machine = null
		print("📹 CameraStateMachine: Disconnected from CharacterStateMachine")

func is_connected_to_character_state_machine() -> bool:
	"""Check if connected to character state machine"""
	return character_state_machine != null and character_state_machine.state_changed.is_connected(_on_character_state_changed)

# === SIGNAL HANDLERS ===

func _on_character_state_changed(_old_state: String, new_state: String):
	"""Respond to character state changes"""
	if not enable_camera_state_machine or is_external_control_active:
		return
	
	change_camera_state(new_state)

# === CAMERA STATE MANAGEMENT ===

func change_camera_state(state_name: String):
	"""Change camera state and apply response"""
	if not enable_camera_state_machine or is_external_control_active:
		return
	
	current_camera_state = state_name
	
	# Emit signal that state is changing
	camera_state_changed.emit(state_name)
	camera_transition_started.emit(state_name)
	
	# Apply camera response
	apply_camera_response(state_name)

func apply_camera_response(state_name: String):
	"""Apply camera response for given state"""
	if not camera_responses.has(state_name):
		print("⚠️ CameraStateMachine: No response found for state: ", state_name)
		apply_default_response()
		return
	
	var response_node = camera_responses[state_name]
	
	# Stop any existing tween
	if current_tween:
		current_tween.kill()
	
	# Create new tween
	current_tween = create_tween()
	current_tween.set_parallel(true)
	
	# Get response properties from the node
	var fov = get_response_property(response_node, "fov", default_fov)
	var distance = get_response_property(response_node, "distance", default_distance)
	var offset = get_response_property(response_node, "offset", Vector3.ZERO)
	var duration = get_response_property(response_node, "duration", default_transition_speed)
	var ease_type = get_response_property(response_node, "ease_type", Tween.EASE_OUT)
	
	# Apply camera properties
	tween_camera_properties(fov, distance, offset, duration, ease_type)
	
	# Emit completion signal when tween finishes
	if current_tween:
		current_tween.finished.connect(func(): camera_transition_completed.emit(state_name))

func get_response_property(response_node: Node, property_name: String, default_value):
	"""Get property from response node with fallback"""
	if response_node.has_method("get") and property_name in response_node:
		return response_node.get(property_name)
	return default_value

func tween_camera_properties(fov: float, distance: float, offset: Vector3, duration: float, ease_type: Tween.EaseType):
	"""Tween camera properties"""
	if not current_tween:
		return
	
	# Tween FOV
	if fov > 0 and camera:
		current_tween.tween_property(camera, "fov", fov, duration).set_ease(ease_type)
	
	# Tween distance
	if distance > 0 and spring_arm:
		current_tween.tween_property(spring_arm, "spring_length", distance, duration).set_ease(ease_type)
	
	# Note: Offset handling would need camera controller integration
	# This is simplified for the current architecture

func apply_default_response():
	"""Apply default camera response when no specific response found"""
	if current_tween:
		current_tween.kill()
	
	current_tween = create_tween()
	current_tween.set_parallel(true)
	
	tween_camera_properties(default_fov, default_distance, Vector3.ZERO, default_transition_speed, Tween.EASE_OUT)
	
	if current_tween:
		current_tween.finished.connect(func(): camera_transition_completed.emit("default"))

# === VALIDATION ===

func validate_camera_responses() -> bool:
	"""Validate that camera responses are properly configured"""
	var required_states = ["idle", "walking", "running", "jumping", "airborne", "landing"]
	var missing_responses = []
	var duplicate_states = []
	var state_counts = {}
	
	# Check for missing states and duplicates
	for state_name in required_states:
		if not camera_responses.has(state_name):
			missing_responses.append(state_name)
	
	# Count occurrences of each state
	for response_node in camera_response_nodes:
		if response_node:
			var target_state = get_response_property(response_node, "target_state", "")
			if not target_state.is_empty():
				if target_state in state_counts:
					state_counts[target_state] += 1
				else:
					state_counts[target_state] = 1
	
	# Find duplicates
	for state in state_counts:
		if state_counts[state] > 1:
			duplicate_states.append(state + " (" + str(state_counts[state]) + " nodes)")
	
	# Report issues
	if missing_responses.size() > 0:
		push_warning("Missing camera responses for states: " + str(missing_responses))
	
	if duplicate_states.size() > 0:
		push_warning("Duplicate camera responses found: " + str(duplicate_states))
	
	return missing_responses.size() == 0 and duplicate_states.size() == 0

# === INSPECTOR HELPERS ===

func _get_configuration_warnings() -> PackedStringArray:
	"""Provide warnings in the editor if responses are not properly configured"""
	var warnings = PackedStringArray()
	
	if camera_response_nodes.is_empty():
		warnings.append("No camera response nodes assigned. Please drag response nodes into the Camera Response Nodes array.")
	
	if not character_state_machine:
		warnings.append("No CharacterStateMachine assigned. Camera will not respond to character state changes.")
	
	# Check each response node
	var target_states = []
	var duplicates = []
	
	for i in range(camera_response_nodes.size()):
		var node = camera_response_nodes[i]
		if not node:
			warnings.append("Camera response node slot " + str(i) + " is empty.")
		elif not node.script:
			warnings.append("Camera response node '" + node.name + "' has no script assigned.")
		else:
			# Check target_state
			var target_state = get_response_property(node, "target_state", "")
			if target_state.is_empty():
				warnings.append("Camera response node '" + node.name + "' has no target_state set.")
			elif target_state in target_states:
				duplicates.append(target_state)
			else:
				target_states.append(target_state)
	
	# Warn about duplicates
	if duplicates.size() > 0:
		warnings.append("Duplicate target_states found: " + str(duplicates))
	
	# Check required references
	if not character:
		warnings.append("No character assigned.")
	
	if not camera:
		warnings.append("No camera assigned.")
	
	if not spring_arm:
		warnings.append("No spring arm assigned.")
	
	return warnings

# === UTILITY METHODS ===

func has_response(state_name: String) -> bool:
	"""Check if response exists for state"""
	return camera_responses.has(state_name)

func get_current_camera_state() -> String:
	"""Get current camera state name"""
	return current_camera_state

func get_response_node(state_name: String) -> Node:
	"""Get response node for state"""
	return camera_responses.get(state_name, null)

func force_camera_state(state_name: String):
	"""Force camera to specific state (for testing)"""
	change_camera_state(state_name)

# === DEBUG AND TESTING ===

func test_all_camera_states():
	"""Test camera responses for all states"""
	if not enable_camera_state_machine:
		print("❌ CameraStateMachine: Cannot test - state machine disabled")
		return
	
	var states = camera_responses.keys()
	for state in states:
		await get_tree().create_timer(1.0).timeout
		change_camera_state(state)
		print("🧪 Testing camera for state: ", state)

func get_debug_info() -> Dictionary:
	"""Get debug information"""
	return {
		"enabled": enable_camera_state_machine,
		"external_control_active": is_external_control_active,
		"current_state": current_camera_state,
		"total_responses": camera_responses.size(),
		"response_states": camera_responses.keys(),
		"has_character": character != null,
		"has_camera": camera != null,
		"has_spring_arm": spring_arm != null,
		"has_active_tween": current_tween != null and current_tween.is_valid(),
		"current_fov": camera.fov if camera else 0.0,
		"current_distance": spring_arm.spring_length if spring_arm else 0.0,
		"connected_to_char_sm": is_connected_to_character_state_machine(),
		"char_sm_assigned": character_state_machine != null
	}

func get_camera_response_summary() -> Dictionary:
	"""Get summary of camera responses for debugging"""
	var summary = {}
	for state_name in camera_responses.keys():
		var response_node = camera_responses[state_name]
		summary[state_name] = {
			"node_name": response_node.name,
			"target_state": get_response_property(response_node, "target_state", "not_set"),
			"has_script": response_node.script != null,
			"fov": get_response_property(response_node, "fov", "not_set"),
			"distance": get_response_property(response_node, "distance", "not_set"),
			"duration": get_response_property(response_node, "duration", "not_set")
		}
	return summary
