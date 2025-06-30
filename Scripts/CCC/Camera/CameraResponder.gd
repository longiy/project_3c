# CameraResponder.gd - Character state response module
extends Node
class_name CameraResponder

# === EXPORTS ===
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

@export_group("Response Settings")
@export var enable_state_responses = true

# === CONTROLLER REFERENCE ===
var controller: CameraController
var character_state_machine: CharacterStateMachine

# === INTERNAL STATE ===
var current_state_tween: Tween

func setup_controller_reference(camera_controller: CameraController):
	controller = camera_controller
	connect_to_state_machine()

func _ready():
	# Delay connection to ensure character system is ready
	if not character_state_machine:
		call_deferred("connect_to_state_machine")

# === CHARACTER STATE MACHINE CONNECTION ===

func connect_to_state_machine():
	"""Find and connect to character state machine"""
	if character_state_machine:
		return
		
	# Try to find automatically
	character_state_machine = get_node_or_null("../../CHARACTER/CharacterStateMachine") as CharacterStateMachine
	
	if character_state_machine:
		character_state_machine.state_changed_for_camera.connect(_on_character_state_changed)
		print("✅ CameraResponder: Connected to CharacterStateMachine")
	else:
		print("⚠️ CameraResponder: CharacterStateMachine not found")

func _on_character_state_changed(state_name: String):
	"""Respond to character state changes"""
	if not enable_state_responses or not controller:
		return
		
	var camera_data = get_camera_data_for_state(state_name)
	respond_to_character_state(state_name, camera_data.fov, camera_data.distance, camera_data.transition_time)

# === STATE RESPONSE LOGIC ===

func respond_to_character_state(state_name: String, fov: float, distance: float, transition_time: float):
	"""Apply camera response to character state change"""
	if not controller:
		return
	
	print("📹 CameraResponder: Responding to state '", state_name, "' - FOV: ", fov, " Distance: ", distance)
	
	# Cancel existing tween
	if current_state_tween and current_state_tween.is_valid():
		current_state_tween.kill()
	
	if transition_time <= 0:
		# Immediate change
		controller.set_camera_fov(fov, 0)
		controller.set_camera_distance(distance, 0)
	else:
		# Tween change
		current_state_tween = create_tween()
		current_state_tween.set_parallel(true)
		
		# Tween FOV
		current_state_tween.tween_method(
			controller.set_camera_fov.bind(0),
			controller.current_fov,
			fov,
			transition_time
		)
		
		# Tween distance
		current_state_tween.tween_method(
			controller.set_camera_distance.bind(0),
			controller.current_distance,
			distance,
			transition_time
		)

func get_camera_data_for_state(state_name: String) -> Dictionary:
	"""Get camera response data for a state"""
	match state_name:
		"idle":
			return {
				"fov": idle_fov,
				"distance": idle_distance,
				"transition_time": 0.3
			}
		"walking":
			return {
				"fov": walking_fov,
				"distance": walking_distance,
				"transition_time": 0.2
			}
		"running":
			return {
				"fov": running_fov,
				"distance": running_distance,
				"transition_time": 0.25
			}
		"jumping":
			return {
				"fov": jumping_fov,
				"distance": jumping_distance,
				"transition_time": 0.1
			}
		"airborne":
			return {
				"fov": airborne_fov,
				"distance": airborne_distance,
				"transition_time": 0.15
			}
		"landing":
			return {
				"fov": landing_fov,
				"distance": landing_distance,
				"transition_time": 0.2
			}
		_:
			return {
				"fov": controller.default_fov,
				"distance": controller.default_distance,
				"transition_time": 0.3
			}

# === SPECIAL EFFECTS API ===

func trigger_impact_effect(intensity: float = 1.0):
	"""Trigger camera impact effect (for future use)"""
	if not controller:
		return
	
	var impact_fov = controller.current_fov + (10.0 * intensity)
	var impact_distance = controller.current_distance + (0.5 * intensity)
	
	if current_state_tween and current_state_tween.is_valid():
		current_state_tween.kill()
	
	current_state_tween = create_tween()
	current_state_tween.set_parallel(true)
	
	# Quick impact, then return
	current_state_tween.tween_method(
		controller.set_camera_fov.bind(0),
		controller.current_fov,
		impact_fov,
		0.05
	)
	current_state_tween.tween_method(
		controller.set_camera_fov.bind(0),
		impact_fov,
		controller.target_fov,
		0.2
	).set_delay(0.05)

func trigger_focus_effect(target_fov: float, duration: float = 1.0):
	"""Trigger focused camera effect (for future use)"""
	if not controller:
		return
	
	if current_state_tween and current_state_tween.is_valid():
		current_state_tween.kill()
	
	current_state_tween = create_tween()
	current_state_tween.tween_method(
		controller.set_camera_fov.bind(0),
		controller.current_fov,
		target_fov,
		duration
	)
