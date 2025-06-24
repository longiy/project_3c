# CameraResponder.gd - Modular camera state responder with signal-based communication
extends Node
class_name CameraResponder

# Signals for modular communication
signal cinematic_mode_changed(is_active: bool)
signal camera_response_started(state_name: String)
signal camera_response_completed(state_name: String)

@export_group("References")
@export var camera_controller: Node3D
@export var character: CharacterBody3D
@export var camera: Camera3D
@export var spring_arm: SpringArm3D

@export_group("Component Control")
@export var enable_responder = true
@export var auto_connect_to_character = true
@export var auto_connect_to_camera = true

@export_group("Camera Presets")
@export var default_fov = 75.0
@export var default_distance = 4.0

@export_group("Transition Settings")
@export var transition_speed = 0.3
@export var fast_transition_speed = 0.1

# Current tween reference
var current_tween: Tween

# Cinematic control state
var is_cinematic_mode = false
var stored_camera_state: Dictionary = {}
var auto_exit_timer = 0.0
var auto_exit_duration = 0.0

# Connection tracking
var is_connected_to_character = false
var is_connected_to_camera = false

func _ready():
	setup_connections()

func setup_connections():
	"""Setup connections to camera controller and character"""
	
	# Auto-find camera controller if not assigned
	if not camera_controller and auto_connect_to_camera:
		camera_controller = get_parent()
		if camera_controller:
			print("✅ CameraResponder: Auto-found camera controller")
	
	# Connect to camera controller signals
	if camera_controller and camera_controller.has_signal("camera_state_changed"):
		camera_controller.camera_state_changed.connect(_on_camera_state_changed)
		is_connected_to_camera = true
		print("✅ CameraResponder: Connected to camera controller")
	
	# Auto-find character if not assigned
	if not character and auto_connect_to_character:
		var possible_paths = [
			"../../CHARACTER",
			"../CHARACTER", 
			"/root/Scene/CHARACTER"
		]
		
		for path in possible_paths:
			var found_character = get_node_or_null(path) as CharacterBody3D
			if found_character:
				character = found_character
				print("✅ CameraResponder: Auto-found character at: ", path)
				break
	
	# Auto-find camera and spring arm
	if camera_controller:
		if not camera:
			camera = camera_controller.get_node_or_null("SpringArm3D/Camera3D")
		if not spring_arm:
			spring_arm = camera_controller.get_node_or_null("SpringArm3D")
	
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
		is_connected_to_character = true
		print("✅ CameraResponder: Connected to character state machine")
	else:
		print("❌ CameraResponder: CharacterStateMachine has no state_changed signal")

func _physics_process(delta):
	if not enable_responder:
		return
	
	# Handle auto-exit timer
	if is_cinematic_mode and auto_exit_duration > 0:
		auto_exit_timer -= delta
		if auto_exit_timer <= 0:
			exit_cinematic_mode()

# === MODULAR CONTROL API ===

func set_enabled(enabled: bool):
	"""Enable/disable the camera responder"""
	enable_responder = enabled
	if not enabled:
		print("📹 CameraResponder: Disabled")
		# Release any active cinematic mode
		if is_cinematic_mode:
			exit_cinematic_mode()
	else:
		print("📹 CameraResponder: Enabled")

func is_enabled() -> bool:
	return enable_responder

func get_connection_status() -> Dictionary:
	"""Get connection status for debugging"""
	return {
		"connected_to_character": is_connected_to_character,
		"connected_to_camera": is_connected_to_camera,
		"has_character": character != null,
		"has_camera_controller": camera_controller != null,
		"has_camera": camera != null,
		"has_spring_arm": spring_arm != null,
		"enabled": enable_responder
	}

# === SIGNAL HANDLERS ===

func _on_camera_state_changed(state_data: Dictionary):
	"""React to camera controller state changes"""
	if not enable_responder:
		return
	
	# Could add logic here to respond to camera state changes
	# For now, just track the state
	pass

func _on_character_state_changed(old_state: String, new_state: String):
	"""Respond to character state changes with camera tweening"""
	if not enable_responder:
		return
	
	respond_to_state(new_state)

# === CAMERA RESPONSE LOGIC ===

func respond_to_state(state_name: String):
	"""Main camera response logic"""
	if not enable_responder or is_cinematic_mode:
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
		"idle":
			tween_camera_properties(65.0, 4.0, Vector3.ZERO, transition_speed)
		
		"walking":
			tween_camera_properties(70.0, 4.2, Vector3(0, 0.1, 0), transition_speed)
		
		"running":
			tween_camera_properties(80.0, 4.5, Vector3(0, 0.2, 0), transition_speed, Tween.EASE_OUT)
		
		"jumping":
			tween_camera_properties(85.0, 4.8, Vector3(0, 0.3, 0), fast_transition_speed)
		
		"airborne":
			tween_camera_properties(90.0, 5.0, Vector3(0, 0.4, 0), transition_speed)
		
		"landing":
			tween_camera_properties(75.0, 4.0, Vector3(0, 0.1, 0), fast_transition_speed, Tween.EASE_IN)
		
		_:
			tween_camera_properties(default_fov, default_distance, Vector3.ZERO, transition_speed)
	
	# Emit completion signal when tween finishes
	if current_tween:
		current_tween.finished.connect(func(): camera_response_completed.emit(state_name))

func tween_camera_properties(fov: float = -1, distance: float = -1, offset: Vector3 = Vector3.INF, duration: float = 0.3, ease: Tween.EaseType = Tween.EASE_OUT):
	"""Helper function to tween multiple camera properties"""
	if not current_tween:
		return
	
	if fov > 0 and camera:
		current_tween.tween_property(camera, "fov", fov, duration).set_ease(ease)
	
	if distance > 0 and spring_arm:
		current_tween.tween_property(spring_arm, "spring_length", distance, duration).set_ease(ease)
	
	if offset != Vector3.INF and camera_controller and camera_controller.has_method("set_camera_offset"):
		# Use camera controller's offset system if available
		camera_controller.set_camera_offset(offset)

# === CINEMATIC CONTROL FUNCTIONS ===

func enter_cinematic_mode(auto_exit_after: float = 0.0):
	"""Take full control of camera"""
	if is_cinematic_mode:
		return
	
	print("🎬 CameraResponder: Entering cinematic mode")
	is_cinematic_mode = true
	
	# Store current camera controller state
	if camera_controller:
		stored_camera_state = camera_controller.get_control_status()
		camera_controller.set_external_control(true, "full")
	
	# Set up auto-exit timer
	if auto_exit_after > 0:
		auto_exit_duration = auto_exit_after
		auto_exit_timer = auto_exit_after
		print("🎬 Auto-exit set for ", auto_exit_after, " seconds")
	else:
		auto_exit_duration = 0.0
	
	# Emit signal for other components
	cinematic_mode_changed.emit(true)

func exit_cinematic_mode():
	"""Return control to camera controller"""
	if not is_cinematic_mode:
		return
	
	print("🎬 CameraResponder: Exiting cinematic mode")
	is_cinematic_mode = false
	auto_exit_duration = 0.0
	
	# Restore camera controller state
	if camera_controller:
		camera_controller.set_external_control(false, "full")
	
	# Emit signal
	cinematic_mode_changed.emit(false)

func toggle_cinematic_mode():
	"""Toggle between cinematic and normal mode"""
	if is_cinematic_mode:
		exit_cinematic_mode()
	else:
		enter_cinematic_mode()

# === CINEMATIC CAMERA MOVEMENTS ===

func cinematic_move_to_position(target_position: Vector3, duration: float = 2.0, ease: Tween.EaseType = Tween.EASE_IN_OUT):
	"""Move camera to specific world position (cinematic mode)"""
	if not is_cinematic_mode:
		enter_cinematic_mode()
	
	if not camera_controller:
		return
	
	if current_tween:
		current_tween.kill()
	
	current_tween = create_tween()
	current_tween.tween_property(camera_controller, "global_position", target_position, duration).set_ease(ease)

func cinematic_look_at_target(target: Node3D, duration: float = 1.5, ease: Tween.EaseType = Tween.EASE_IN_OUT):
	"""Point camera at specific target (cinematic mode)"""
	if not is_cinematic_mode:
		enter_cinematic_mode()
	
	if not camera_controller:
		return
	
	if current_tween:
		current_tween.kill()
	
	var look_transform = camera_controller.global_transform.looking_at(target.global_position)
	var target_rotation = look_transform.basis.get_euler()
	
	current_tween = create_tween()
	current_tween.tween_property(camera_controller, "rotation", target_rotation, duration).set_ease(ease)

func camera_dramatic_zoom(target_fov: float, hold_duration: float = 0.5, return_duration: float = 0.3):
	"""Dramatic zoom effect for special moves/impacts"""
	if not camera:
		return
	
	if current_tween:
		current_tween.kill()
	
	var original_fov = camera.fov
	current_tween = create_tween()
	
	# Quick zoom
	current_tween.tween_property(camera, "fov", target_fov, 0.1)
	# Hold
	current_tween.tween_delay(hold_duration)
	# Return
	current_tween.tween_property(camera, "fov", original_fov, return_duration).set_ease(Tween.EASE_OUT)

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
	var connection_status = get_connection_status()
	
	var debug_info = {
		"current_fov": camera.fov if camera else 0.0,
		"current_distance": spring_arm.spring_length if spring_arm else 0.0,
		"has_active_tween": current_tween != null and current_tween.is_valid(),
		"cinematic_mode": is_cinematic_mode,
		"auto_exit_timer": auto_exit_timer
	}
	
	debug_info.merge(connection_status)
	return debug_info
