# CameraStateResponder.gd - Responds to character state changes with camera adjustments
extends Node
class_name CameraStateResponder

signal response_started(state_name: String)
signal response_completed(state_name: String)

@export var character_state_machine_node: NodePath = ""  # Set in inspector

@export_group("State Response Settings")
@export var enable_state_responses = true
@export var default_transition_time = 0.3
@export var fast_transition_time = 0.1

@export_group("State Response Values")
@export var idle_fov = 50.0
@export var idle_distance = 4.0

@export var walking_fov = 60.0
@export var walking_distance = 4.0

@export var running_fov = 70.0
@export var running_distance = 4.5

@export var jumping_fov = 85.0
@export var jumping_distance = 4.8

@export var airborne_fov = 90.0
@export var airborne_distance = 5.0

@export var landing_fov = 75.0
@export var landing_distance = 4.0

var camera_rig: CameraRig
var character_state_machine: Node
var current_tween: Tween

# State tracking
var current_character_state = ""
var response_active = false

func _ready():
	camera_rig = get_parent() as CameraRig
	if not camera_rig:
		push_error("CameraStateResponder must be child of CameraRig")
		return
	
	# Find and connect to character state machine
	find_and_connect_character()
	
	print("📹 CameraStateResponder: Initialized")

func connect_to_state_machine():
	"""Connect to state machine"""
	if character_state_machine and character_state_machine.has_signal("character_state_changed"):
		character_state_machine.character_state_changed.connect(_on_character_state_changed)
		print("✅ CameraStateResponder: Connected to CharacterStateMachine at ", character_state_machine.get_path())
	else:
		print("❌ CameraStateResponder: CharacterStateMachine missing character_state_changed signal")

func find_and_connect_character():
	"""Use explicit path instead of scene searching"""
	if not enable_state_responses:
		print("📹 CameraStateResponder: State responses disabled")
		return
	
	# EXPLICIT connection via NodePath
	if not character_state_machine_node.is_empty():
		character_state_machine = get_node_or_null(character_state_machine_node)
		if character_state_machine:
			connect_to_state_machine()
			return
	
	# FALLBACK: Only search immediate scene children (no deep search)
	var scene_root = get_tree().current_scene
	if scene_root:
		for child in scene_root.get_children():
			if child is CharacterBody3D:
				var state_machine = child.get_node_or_null("CharacterStateMachine")
				if state_machine:
					character_state_machine = state_machine
					connect_to_state_machine()
					return
	
	print("⚠️ CameraStateResponder: No CharacterStateMachine found - set character_state_machine_node path")

func find_character_in_scene() -> Node:
	"""Find character node in scene"""
	var scene_root = get_tree().current_scene
	if not scene_root:
		return null
	
	# Look for CharacterBody3D
	for child in scene_root.get_children():
		if child is CharacterBody3D:
			return child
	
	return null

# === SIGNAL HANDLERS ===

func _on_character_state_changed(old_state: String, new_state: String):
	"""Respond to character state changes"""
	if not enable_state_responses or not camera_rig:
		return
	
	current_character_state = new_state
	respond_to_state(new_state)

# === STATE RESPONSE LOGIC ===

func respond_to_state(state_name: String):
	"""Execute camera response for character state"""
	if response_active:
		# Cancel current response
		if current_tween:
			current_tween.kill()
	
	response_active = true
	response_started.emit(state_name)
	
	# Get response values for state
	var response_data = get_state_response_data(state_name)
	
	# Create tween for smooth transition
	current_tween = create_tween()
	current_tween.set_parallel(true)
	
	# Tween FOV
	var fov_tween = current_tween.tween_method(
		camera_rig.set_camera_fov,
		camera_rig.current_fov,
		response_data.fov,
		response_data.transition_time
	)
	fov_tween.set_ease(response_data.ease_type)
	
	# Tween distance
	var distance_tween = current_tween.tween_method(
		camera_rig.set_camera_distance,
		camera_rig.current_distance,
		response_data.distance,
		response_data.transition_time
	)
	distance_tween.set_ease(response_data.ease_type)
	
	# Connect completion signal
	current_tween.finished.connect(func(): _on_response_completed(state_name))
	
	print("📹 CameraStateResponder: Responding to state '", state_name, "' - FOV:", response_data.fov, " Distance:", response_data.distance)

func get_state_response_data(state_name: String) -> Dictionary:
	"""Get camera response data for character state"""
	match state_name:
		"idle":
			return {
				"fov": idle_fov,
				"distance": idle_distance,
				"transition_time": default_transition_time,
				"ease_type": Tween.EASE_OUT
			}
		
		"walking":
			return {
				"fov": walking_fov,
				"distance": walking_distance,
				"transition_time": default_transition_time,
				"ease_type": Tween.EASE_OUT
			}
		
		"running":
			return {
				"fov": running_fov,
				"distance": running_distance,
				"transition_time": default_transition_time,
				"ease_type": Tween.EASE_OUT
			}
		
		"jumping":
			return {
				"fov": jumping_fov,
				"distance": jumping_distance,
				"transition_time": fast_transition_time,
				"ease_type": Tween.EASE_OUT
			}
		
		"airborne":
			return {
				"fov": airborne_fov,
				"distance": airborne_distance,
				"transition_time": default_transition_time,
				"ease_type": Tween.EASE_OUT
			}
		
		"landing":
			return {
				"fov": landing_fov,
				"distance": landing_distance,
				"transition_time": fast_transition_time,
				"ease_type": Tween.EASE_IN
			}
		
		_:
			# Default fallback
			return {
				"fov": camera_rig.default_fov,
				"distance": camera_rig.default_distance,
				"transition_time": default_transition_time,
				"ease_type": Tween.EASE_OUT
			}

func _on_response_completed(state_name: String):
	"""Handle response completion"""
	response_active = false
	response_completed.emit(state_name)

# === MANUAL CONTROL ===

func force_response(state_name: String):
	"""Force camera response for testing"""
	respond_to_state(state_name)

func set_state_response(state_name: String, fov: float, distance: float):
	"""Set custom response values for a state"""
	match state_name:
		"idle":
			idle_fov = fov
			idle_distance = distance
		"walking":
			walking_fov = fov
			walking_distance = distance
		"running":
			running_fov = fov
			running_distance = distance
		"jumping":
			jumping_fov = fov
			jumping_distance = distance
		"airborne":
			airborne_fov = fov
			airborne_distance = distance
		"landing":
			landing_fov = fov
			landing_distance = distance

# === CONTROL API ===

func set_enabled(enabled: bool):
	"""Enable/disable state responses"""
	enable_state_responses = enabled
	
	if not enabled and current_tween:
		current_tween.kill()
		response_active = false
	
	print("📹 CameraStateResponder: ", "Enabled" if enabled else "Disabled")

func is_connected_to_character() -> bool:
	"""Check if connected to character state machine"""
	return character_state_machine != null

# === TESTING ===

func test_all_states():
	"""Test camera responses for all states"""
	if not enable_state_responses:
		print("❌ CameraStateResponder: Cannot test - responses disabled")
		return
	
	var states = ["idle", "walking", "running", "jumping", "airborne", "landing"]
	for state in states:
		await get_tree().create_timer(1.5).timeout
		force_response(state)
		print("🧪 Testing camera response for state: ", state)

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get debug information"""
	return {
		"enabled": enable_state_responses,
		"character_connected": character_state_machine != null,
		"current_character_state": current_character_state,
		"response_active": response_active,
		"has_active_tween": current_tween != null and current_tween.is_valid(),
		"character_path": character_state_machine.get_path() if character_state_machine else "None",
		"state_values": {
			"idle": {"fov": idle_fov, "distance": idle_distance},
			"walking": {"fov": walking_fov, "distance": walking_distance},
			"running": {"fov": running_fov, "distance": running_distance},
			"jumping": {"fov": jumping_fov, "distance": jumping_distance},
			"airborne": {"fov": airborne_fov, "distance": airborne_distance},
			"landing": {"fov": landing_fov, "distance": landing_distance}
		}
	}
