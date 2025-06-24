# CameraResponder.gd - Replaces the camera state machine with simple tweening
extends Node
class_name CameraResponder

@export_group("References")
@export var camera_controller: Node3D  # Your CAMERARIG node
@export var character: CharacterBody3D
@export var camera: Camera3D
@export var spring_arm: SpringArm3D

@export_group("Camera Presets")
@export var default_fov = 75.0
@export var default_distance = 4.0

@export_group("Debug Controls")
@export var enable_debug_toggle = true
@export var debug_toggle_key = "ui_accept"  # Use existing Enter key

@export_group("Transition Settings")
@export var transition_speed = 0.3
@export var fast_transition_speed = 0.1

# Current tween reference (to stop previous tweens)
var current_tween: Tween

# Cinematic control state
var is_cinematic_mode = false
var stored_mouse_mode: Input.MouseMode
var stored_follow_mode: int
var auto_exit_timer = 0.0
var auto_exit_duration = 0.0

func _ready():
	# Auto-find references if not assigned
	if not camera_controller:
		camera_controller = get_parent()
	
	if not character:
		# Try multiple possible paths
		var possible_paths = [
			"../../CHARACTER",
			"../CHARACTER", 
			"/root/Scene/CHARACTER",
			"../../../CHARACTER"
		]
		
		for path in possible_paths:
			var found_character = get_node_or_null(path) as CharacterBody3D
			if found_character:
				character = found_character
				print("✅ CameraResponder: Found character at: ", path)
				break
		
		if not character:
			print("❌ CameraResponder: Could not find CHARACTER node. Tried paths: ", possible_paths)
			return
	
	if not camera:
		camera = camera_controller.get_node_or_null("SpringArm3D/Camera3D")
		if not camera:
			print("❌ CameraResponder: Could not find Camera3D")
			return
	
	if not spring_arm:
		spring_arm = camera_controller.get_node_or_null("SpringArm3D")
		if not spring_arm:
			print("❌ CameraResponder: Could not find SpringArm3D")
			return
	
	# Connect to character state changes with delay to ensure state machine is ready
	call_deferred("connect_to_state_machine")

func _physics_process(delta):
	# Handle auto-exit timer
	if is_cinematic_mode and auto_exit_duration > 0:
		auto_exit_timer -= delta
		if auto_exit_timer <= 0:
			exit_cinematic_mode()

func _input(event):
	# Debug toggle for testing
	if enable_debug_toggle and event.is_action_pressed(debug_toggle_key):
		toggle_cinematic_mode()
		print("🎮 Debug: Toggled cinematic mode - now ", "ON" if is_cinematic_mode else "OFF")
	
	# Emergency exit from cinematic mode
	if is_cinematic_mode and event.is_action_pressed("ui_cancel"):
		print("🎬 Emergency exit from cinematic mode")
		exit_cinematic_mode()

func connect_to_state_machine():
	"""Connect to state machine after everything is initialized"""
	if not character:
		print("❌ CameraResponder: No character to connect to")
		return
		
	var state_machine = character.get_node_or_null("CharacterStateMachine")
	if not state_machine:
		print("❌ CameraResponder: Could not find CharacterStateMachine node")
		return
	
	if state_machine.has_signal("state_changed"):
		state_machine.state_changed.connect(_on_character_state_changed)
		print("✅ CameraResponder: Connected to character state machine")
	else:
		print("❌ CameraResponder: CharacterStateMachine has no state_changed signal")

func _on_character_state_changed(old_state: String, new_state: String):
	"""Respond to character state changes with camera tweening"""
	respond_to_state(new_state)

func respond_to_state(state_name: String):
	"""Main camera response logic - customize this for your needs"""
	
	# Stop any existing tween
	if current_tween:
		current_tween.kill()
	
	# Create new tween
	current_tween = create_tween()
	current_tween.set_parallel(true)  # Allow multiple properties to tween simultaneously
	
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
			# Default/fallback
			tween_camera_properties(default_fov, default_distance, Vector3.ZERO, transition_speed)

func tween_camera_properties(fov: float = -1, distance: float = -1, offset: Vector3 = Vector3.INF, duration: float = 0.3, ease: Tween.EaseType = Tween.EASE_OUT):
	"""Helper function to tween multiple camera properties"""
	
	if fov > 0:
		current_tween.tween_property(camera, "fov", fov, duration).set_ease(ease)
	
	if distance > 0:
		current_tween.tween_property(spring_arm, "spring_length", distance, duration).set_ease(ease)
	
	if offset != Vector3.INF:
		current_tween.tween_property(camera_controller, "camera_offset", offset, duration).set_ease(ease)

# === CINEMATIC CONTROL FUNCTIONS ===

func enter_cinematic_mode(auto_exit_after: float = 0.0):
	"""Take full control of camera - disable mouse look and following"""
	if is_cinematic_mode:
		return  # Already in cinematic mode
	
	print("🎬 CameraResponder: Entering cinematic mode")
	is_cinematic_mode = true
	
	# Store current camera controller state
	stored_mouse_mode = Input.mouse_mode
	stored_follow_mode = camera_controller.follow_mode
	
	# Force disable mouse look and following in camera controller
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	camera_controller.follow_mode = 2  # Manual mode (no following)
	camera_controller.is_mouse_captured = false  # Force disable mouse capture flag
	
	# Set up auto-exit timer if specified
	if auto_exit_after > 0:
		auto_exit_duration = auto_exit_after
		auto_exit_timer = auto_exit_after
		print("🎬 Auto-exit set for ", auto_exit_after, " seconds")
	else:
		auto_exit_duration = 0.0
	
	# Optionally emit signal for other systems
	if camera_controller.has_signal("cinematic_mode_entered"):
		camera_controller.cinematic_mode_entered.emit()

func exit_cinematic_mode():
	"""Return control to camera controller"""
	if not is_cinematic_mode:
		return  # Not in cinematic mode
	
	print("🎬 CameraResponder: Exiting cinematic mode")
	is_cinematic_mode = false
	auto_exit_duration = 0.0  # Clear auto-exit timer
	
	# Restore camera controller state
	Input.mouse_mode = stored_mouse_mode
	camera_controller.follow_mode = stored_follow_mode
	camera_controller.is_mouse_captured = (stored_mouse_mode == Input.MOUSE_MODE_CAPTURED)
	
	# Optionally emit signal
	if camera_controller.has_signal("cinematic_mode_exited"):
		camera_controller.cinematic_mode_exited.emit()

func toggle_cinematic_mode():
	"""Toggle between cinematic and normal mode"""
	if is_cinematic_mode:
		exit_cinematic_mode()
	else:
		enter_cinematic_mode()

func cinematic_move_to_position(target_position: Vector3, duration: float = 2.0, ease: Tween.EaseType = Tween.EASE_IN_OUT):
	"""Move camera to specific world position (cinematic mode)"""
	if not is_cinematic_mode:
		enter_cinematic_mode()
	
	if current_tween:
		current_tween.kill()
	
	current_tween = create_tween()
	current_tween.tween_property(camera_controller, "global_position", target_position, duration).set_ease(ease)

func cinematic_look_at_target(target: Node3D, duration: float = 1.5, ease: Tween.EaseType = Tween.EASE_IN_OUT):
	"""Point camera at specific target (cinematic mode)"""
	if not is_cinematic_mode:
		enter_cinematic_mode()
	
	if current_tween:
		current_tween.kill()
	
	# Calculate rotation to look at target
	var look_transform = camera_controller.global_transform.looking_at(target.global_position)
	var target_rotation = look_transform.basis.get_euler()
	
	current_tween = create_tween()
	current_tween.tween_property(camera_controller, "rotation", target_rotation, duration).set_ease(ease)

func cinematic_orbit_around_target(target: Node3D, radius: float, height: float, orbit_duration: float, revolutions: float = 1.0):
	"""Orbit camera around a target (cinematic mode)"""
	if not is_cinematic_mode:
		enter_cinematic_mode()
	
	if current_tween:
		current_tween.kill()
	
	current_tween = create_tween()
	
	# Create orbital motion
	var steps = 60  # Smooth orbit
	var angle_step = (2 * PI * revolutions) / steps
	var time_step = orbit_duration / steps
	
	for i in steps:
		var angle = angle_step * i
		var orbit_pos = target.global_position + Vector3(
			cos(angle) * radius,
			height,
			sin(angle) * radius
		)
		
		current_tween.tween_property(camera_controller, "global_position", orbit_pos, time_step)
		current_tween.parallel().tween_method(
			func(pos): camera_controller.look_at(target.global_position),
			0, 1, time_step
		)

func cinematic_sequence(sequence_data: Array):
	"""Execute a sequence of cinematic moves"""
	if not is_cinematic_mode:
		enter_cinematic_mode()
	
	if current_tween:
		current_tween.kill()
	
	current_tween = create_tween()
	
	for step in sequence_data:
		match step.type:
			"move":
				current_tween.tween_property(camera_controller, "global_position", step.position, step.duration)
			"look_at":
				var target_rot = camera_controller.global_transform.looking_at(step.target.global_position).basis.get_euler()
				current_tween.parallel().tween_property(camera_controller, "rotation", target_rot, step.duration)
			"fov":
				current_tween.parallel().tween_property(camera, "fov", step.fov, step.duration)
			"wait":
				current_tween.tween_delay(step.duration)
			"callback":
				current_tween.tween_callback(step.function)
	
	# Auto-exit cinematic mode when sequence ends (optional)
	if sequence_data.back().get("auto_exit", true):
		current_tween.tween_callback(exit_cinematic_mode)

func camera_dramatic_zoom(target_fov: float, hold_duration: float = 0.5, return_duration: float = 0.3):
	"""Dramatic zoom effect for special moves/impacts"""
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

func camera_impact_shake(intensity: float = 0.5, duration: float = 0.2):
	"""Screen shake for impacts - can be called directly from character states"""
	# Implementation depends on your shake system
	# This is a placeholder
	print("📹 Camera shake: intensity=", intensity, " duration=", duration)

func camera_follow_projectile(projectile: Node3D, return_speed: float = 1.0):
	"""Follow a projectile then return to character"""
	if current_tween:
		current_tween.kill()
	
	current_tween = create_tween()
	# This would need more complex logic to actually follow the projectile
	# Placeholder for the concept
	print("📹 Following projectile")

# === SPECIAL CAMERA EFFECTS (for fighting game moments) ===

func test_all_states():
	"""Test camera responses for all states"""
	var states = ["idle", "walking", "running", "jumping", "airborne", "landing"]
	for state in states:
		await get_tree().create_timer(1.0).timeout
		respond_to_state(state)
		print("🧪 Testing camera for state: ", state)

func get_debug_info() -> Dictionary:
	"""Get debug information"""
	return {
		"current_fov": camera.fov if camera else 0.0,
		"current_distance": spring_arm.spring_length if spring_arm else 0.0,
		"current_offset": camera_controller.camera_offset if camera_controller else Vector3.ZERO,
		"has_active_tween": current_tween != null and current_tween.is_valid()
	}
