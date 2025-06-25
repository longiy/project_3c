# CameraCinema.gd - Updated for new camera system integration
extends Node
class_name CameraCinema

# Signals for communication
signal cinematic_mode_changed(is_active: bool)
signal cinematic_effect_started(effect_name: String)
signal cinematic_effect_completed(effect_name: String)

@export_group("References")
@export var camera_manager: CameraManager
@export var camera: Camera3D
@export var spring_arm: SpringArm3D

@export_group("Component Control")
@export var enable_cinematic_controller = true

@export_group("Cinematic Settings")
@export var cinematic_transition_speed = 2.0
@export var dramatic_zoom_speed = 0.1

# Cinematic state
var is_cinematic_mode = false
var stored_camera_state: Dictionary = {}
var auto_exit_timer = 0.0
var auto_exit_duration = 0.0

# Current effect tween
var current_effect_tween: Tween

func _ready():
	setup_connections()

func _input(event):
	"""Handle cinematic mode toggle"""
	if not enable_cinematic_controller:
		return
	
	if event.is_action_pressed("CinematicMode"):
		print("🎬 CinematicController: F1 pressed - current mode: ", is_cinematic_mode)
		toggle_cinematic_mode()

func _physics_process(delta):
	if not enable_cinematic_controller:
		return
	
	# Handle auto-exit timer
	if is_cinematic_mode and auto_exit_duration > 0:
		auto_exit_timer -= delta
		if auto_exit_timer <= 0:
			exit_cinematic_mode()

func setup_connections():
	"""Setup connections to camera manager"""
	if not camera_manager:
		print("⚠️ CinematicController: No CameraManager assigned")

# === MODULAR CONTROL API ===

func set_enabled(enabled: bool):
	"""Enable/disable the cinematic controller"""
	enable_cinematic_controller = enabled
	if not enabled and is_cinematic_mode:
		exit_cinematic_mode()
	print("🎬 CinematicController: ", "Enabled" if enabled else "Disabled")

func is_enabled() -> bool:
	return enable_cinematic_controller

# === CINEMATIC MODE CONTROL ===

func enter_cinematic_mode(auto_exit_after: float = 0.0):
	"""Take full control of camera"""
	if is_cinematic_mode or not enable_cinematic_controller:
		return
	
	print("🎬 CinematicController: Entering cinematic mode")
	is_cinematic_mode = true
	
	# Store current camera manager state
	if camera_manager:
		stored_camera_state = camera_manager.get_debug_info()
		stored_camera_state["mouse_mode"] = Input.mouse_mode
		stored_camera_state["mouse_captured"] = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		print("🎬 Stored state: ", stored_camera_state)
		
		# Tell camera manager we're taking control
		camera_manager.set_external_control(true, "CameraCinema")
	
	# Release mouse for cinematic control
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("🎬 Mouse set to visible")
	
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
	"""Return control to camera manager"""
	if not is_cinematic_mode:
		return
	
	print("🎬 CinematicController: Exiting cinematic mode")
	print("🎬 Restoring from stored state: ", stored_camera_state)
	
	is_cinematic_mode = false
	auto_exit_duration = 0.0
	
	# Restore the original mouse mode FIRST
	if stored_camera_state.has("mouse_mode"):
		Input.mouse_mode = stored_camera_state["mouse_mode"]
		print("🎬 Restored mouse mode to: ", stored_camera_state["mouse_mode"])
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		print("🎬 No stored mouse mode, defaulting to captured")
	
	# Wait a frame for input processing
	await get_tree().process_frame
	
	# Return control to camera manager
	if camera_manager:
		camera_manager.set_external_control(false, "CameraCinema")
	
	# Clear stored state
	stored_camera_state.clear()
	
	# Emit signal AFTER everything is restored
	cinematic_mode_changed.emit(false)
	print("🎬 Cinematic mode exit complete")

func toggle_cinematic_mode():
	"""Toggle between cinematic and normal mode"""
	if is_cinematic_mode:
		exit_cinematic_mode()
	else:
		enter_cinematic_mode()

# === CINEMATIC CAMERA EFFECTS ===

func cinematic_move_to_position(target_position: Vector3, duration: float = 2.0, ease_type: Tween.EaseType = Tween.EASE_IN_OUT):
	"""Move camera to specific world position"""
	if not is_cinematic_mode:
		enter_cinematic_mode()
	
	if not camera_manager:
		print("❌ CinematicController: No camera manager for movement")
		return
	
	cinematic_effect_started.emit("move_to_position")
	
	if current_effect_tween:
		current_effect_tween.kill()
	
	current_effect_tween = create_tween()
	var tween_property = current_effect_tween.tween_property(camera_manager, "global_position", target_position, duration)
	tween_property.set_ease(ease_type)
	current_effect_tween.finished.connect(func(): cinematic_effect_completed.emit("move_to_position"))

func cinematic_look_at_target(target: Node3D, duration: float = 1.5, ease_type: Tween.EaseType = Tween.EASE_IN_OUT):
	"""Point camera at specific target"""
	if not is_cinematic_mode:
		enter_cinematic_mode()
	
	if not camera_manager or not target:
		print("❌ CinematicController: Missing camera manager or target")
		return
	
	cinematic_effect_started.emit("look_at_target")
	
	if current_effect_tween:
		current_effect_tween.kill()
	
	var look_transform = camera_manager.global_transform.looking_at(target.global_position)
	var target_rotation = look_transform.basis.get_euler()
	
	current_effect_tween = create_tween()
	var tween_property = current_effect_tween.tween_property(camera_manager, "rotation", target_rotation, duration)
	tween_property.set_ease(ease_type)
	current_effect_tween.finished.connect(func(): cinematic_effect_completed.emit("look_at_target"))

func camera_dramatic_zoom(target_fov: float, hold_duration: float = 0.5, return_duration: float = 0.3):
	"""Dramatic zoom effect for special moves/impacts"""
	if not camera:
		print("❌ CinematicController: No camera for dramatic zoom")
		return
	
	cinematic_effect_started.emit("dramatic_zoom")
	
	if current_effect_tween:
		current_effect_tween.kill()
	
	var original_fov = camera.fov
	current_effect_tween = create_tween()
	
	# Quick zoom in
	current_effect_tween.tween_property(camera, "fov", target_fov, dramatic_zoom_speed)
	# Hold
	current_effect_tween.tween_delay(hold_duration)
	# Return to original
	current_effect_tween.tween_property(camera, "fov", original_fov, return_duration).set_ease(Tween.EASE_OUT)
	current_effect_tween.finished.connect(func(): cinematic_effect_completed.emit("dramatic_zoom"))

func smooth_zoom_to_fov(target_fov: float, duration: float = 1.0, ease_type: Tween.EaseType = Tween.EASE_IN_OUT):
	"""Smooth zoom transition to target FOV"""
	if not camera:
		return
	
	cinematic_effect_started.emit("smooth_zoom")
	
	if current_effect_tween:
		current_effect_tween.kill()
	
	current_effect_tween = create_tween()
	var tween_property = current_effect_tween.tween_property(camera, "fov", target_fov, duration)
	tween_property.set_ease(ease_type)
	current_effect_tween.finished.connect(func(): cinematic_effect_completed.emit("smooth_zoom"))

# === UTILITY METHODS ===

func is_in_cinematic_mode() -> bool:
	return is_cinematic_mode

func get_connection_status() -> Dictionary:
	"""Get connection status for debugging"""
	return {
		"has_camera_manager": camera_manager != null,
		"has_camera": camera != null,
		"has_spring_arm": spring_arm != null,
		"enabled": enable_cinematic_controller
	}

func get_debug_info() -> Dictionary:
	"""Get debug information"""
	var connection_status = get_connection_status()
	
	var debug_info = {
		"cinematic_mode": is_cinematic_mode,
		"auto_exit_timer": auto_exit_timer,
		"has_active_effect": current_effect_tween != null and current_effect_tween.is_valid(),
		"stored_state_keys": stored_camera_state.keys()
	}
	
	debug_info.merge(connection_status)
	return debug_info
