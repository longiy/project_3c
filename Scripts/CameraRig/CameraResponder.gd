# CameraResponder.gd - Automatic camera state responses only
extends Node
class_name CameraResponder


# Signals for communication
signal camera_response_started(state_name: String)
signal camera_response_completed(state_name: String)

@export_group("References")
@export var character: CharacterBody3D
@export var camera: Camera3D
@export var spring_arm: SpringArm3D

@export_group("Component Control")
@export var enable_responder = true

@export_group("Camera Presets")
@export var default_fov = 75.0
@export var default_distance = 4.0

@export_group("Transition Settings")
@export var transition_speed = 0.3
@export var fast_transition_speed = 0.1

# Current tween reference
var current_tween: Tween

# External control tracking
var is_external_control_active = false

func _ready():
	setup_connections()

func setup_connections():
	"""Connect to character state machine"""
	if not character or not enable_responder:
		return
	
	# Connect to character state machine with delay
	call_deferred("connect_to_character_state_machine")

func connect_to_character_state_machine():
	"""Connect to character state machine signals"""
	if not character or not enable_responder:
		return
	
	var state_machine = character.get_node_or_null("CharacterStateMachine")
	if not state_machine:
		print("⚠️ CameraResponder: No CharacterStateMachine found")
		return
	
	if state_machine.has_signal("state_changed"):
		state_machine.state_changed.connect(_on_character_state_changed)
		print("✅ CameraResponder: Connected to character state machine")
	else:
		print("❌ CameraResponder: CharacterStateMachine has no state_changed signal")

# === MODULAR CONTROL API ===

func set_enabled(enabled: bool):
	"""Enable/disable the camera responder"""
	enable_responder = enabled
	print("📹 CameraResponder: ", "Enabled" if enabled else "Disabled")

func is_enabled() -> bool:
	return enable_responder

func set_external_control_active(active: bool):
	"""Called by CameraCinemato pause/resume responses"""
	is_external_control_active = active
	
	if active:
		# Stop any active tween when external control takes over
		if current_tween:
			current_tween.kill()
		print("📹 CameraResponder: Paused due to external control")
	else:
		print("📹 CameraResponder: Resumed after external control")

# === SIGNAL HANDLERS ===

func _on_character_state_changed(_old_state: String, new_state: String):
	"""Respond to character state changes with camera tweening"""
	if not enable_responder or is_external_control_active:
		return
	
	respond_to_state(new_state)

# === CAMERA RESPONSE LOGIC ===

func tween_camera_properties(fov: float = -1, distance: float = -1, offset: Vector3 = Vector3.INF, duration: float = 0.3, tween_ease: Tween.EaseType = Tween.EASE_OUT):
	"""Helper function to tween multiple camera properties"""
	if not current_tween:
		return
	
	if fov > 0 and camera:
		current_tween.tween_property(camera, "fov", fov, duration).set_ease(tween_ease)
	
	if distance > 0 and spring_arm:
		current_tween.tween_property(spring_arm, "spring_length", distance, duration).set_ease(tween_ease)
	
	# Note: Offset handling would need camera controller integration
	# Simplified for this split

func respond_to_state(state_name: String):
	"""Main camera response logic"""
	if not enable_responder or is_external_control_active:
		return
	
	# Stop any existing tween
	if current_tween:
		current_tween.kill()
	
	# Emit signal that response is starting
	camera_response_started.emit(state_name)
	
	# Create new tween
	current_tween = create_tween()
	current_tween.set_parallel(true)
	
	# Define camera responses for each state
	match state_name:
		"idle":tween_camera_properties(50.0, 4.0, Vector3.ZERO, transition_speed)
		
		"walking":tween_camera_properties(60.0, 4.0, Vector3(0, 1, 0), transition_speed)
		
		"running":tween_camera_properties(70.0, 4.0, Vector3(0, 2, 0), transition_speed, Tween.EASE_OUT)
		
		"jumping":tween_camera_properties(85.0, 4.8, Vector3(0, 0.3, 0), fast_transition_speed)
		
		"airborne":tween_camera_properties(90.0, 5.0, Vector3(0, 0.4, 0), transition_speed)
		
		"landing":tween_camera_properties(75.0, 4.0, Vector3(0, 0.1, 0), fast_transition_speed, Tween.EASE_IN)
		
		_:
			tween_camera_properties(default_fov, default_distance, Vector3.ZERO, transition_speed)
	
	# Emit completion signal when tween finishes
	if current_tween:
		current_tween.finished.connect(func(): camera_response_completed.emit(state_name))



# === DEBUG AND TESTING ===

func test_all_states():
	"""Test camera responses for all states"""
	if not enable_responder:
		print("❌ CameraResponder: Cannot test - responder disabled")
		return
	
	var states = ["idle", "walking", "running", "jumping", "airborne", "landing"]
	for state in states:
		await get_tree().create_timer(1.0).timeout
		respond_to_state(state)
		print("🧪 Testing camera for state: ", state)

func get_debug_info() -> Dictionary:
	"""Get debug information"""
	return {
		"enabled": enable_responder,
		"external_control_active": is_external_control_active,
		"has_character": character != null,
		"has_camera": camera != null,
		"has_spring_arm": spring_arm != null,
		"has_active_tween": current_tween != null and current_tween.is_valid(),
		"current_fov": camera.fov if camera else 0.0,
		"current_distance": spring_arm.spring_length if spring_arm else 0.0
	}
