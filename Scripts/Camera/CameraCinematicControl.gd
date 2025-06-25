# CameraCinemaController.gd - Cinematic camera control and effects
extends Node
class_name CameraCinemaController

signal cinematic_mode_changed(active: bool)
signal cinematic_effect_started(effect_name: String)
signal cinematic_effect_completed(effect_name: String)

@export_group("Cinematic Settings")
@export var enable_cinematic_controller = true
@export var cinematic_move_speed = 2.0
@export var dramatic_zoom_speed = 0.1

@export_group("Auto Exit")
@export var auto_exit_on_input = true
@export var input_exit_actions = ["move_start", "jump"]

# Component references
var camera_rig: CameraRig
var action_system: ActionSystem

# Cinematic state
var is_cinematic_active = false
var stored_camera_state: Dictionary = {}
var auto_exit_timer = 0.0
var auto_exit_duration = 0.0

# Cinematic control flags
var following_disabled = false
var mouse_look_disabled = false

# Effect management  
var current_effect_tween: Tween
var stored_mouse_mode: Input.MouseMode

func disable_camera_following():
	"""Disable camera following target"""
	following_disabled = true
	# Camera stays at current position, doesn't follow character
	camera_rig.set_camera_position_override(camera_rig.global_position)

func restore_camera_following():
	"""Restore camera following target"""
	following_disabled = false
	camera_rig.clear_position_override()

func disable_mouse_look():
	"""Disable mouse look rotation"""
	mouse_look_disabled = true
	# Camera rotation frozen at current angles

func restore_mouse_look():
	"""Restore mouse look rotation"""
	mouse_look_disabled = false

func _ready():
	camera_rig = get_parent() as CameraRig
	if not camera_rig:
		push_error("CameraCinemaController must be child of CameraRig")
		return
	
	# Find action system for auto-exit functionality
	find_action_system()
	
	print("📹 CameraCinemaController: Initialized")

func _input(event):
	"""Handle cinematic mode toggle"""
	if not enable_cinematic_controller:
		return
	
	if event.is_action_pressed("CinematicMode"):
		toggle_cinematic_mode()

func _physics_process(delta):
	"""Handle auto-exit timer"""
	if is_cinematic_active and auto_exit_duration > 0:
		auto_exit_timer -= delta
		if auto_exit_timer <= 0:
			exit_cinematic_mode()

func find_action_system():
	"""Find action system for auto-exit monitoring"""
	var character = find_character_in_scene()
	if character:
		action_system = character.get_node_or_null("ActionSystem")
		if action_system and action_system.has_signal("action_executed"):
			action_system.action_executed.connect(_on_action_executed)
			print("✅ CameraCinemaController: Connected to ActionSystem for auto-exit")

func find_character_in_scene() -> Node:
	"""Find character node in scene"""
	var scene_root = get_tree().current_scene
	if not scene_root:
		return null
	
	for child in scene_root.get_children():
		if child is CharacterBody3D:
			return child
	
	return null

# === CINEMATIC MODE CONTROL ===

func enter_cinematic_mode(auto_exit_after: float = 0.0):
	"""Enter cinematic mode - take camera control"""
	if is_cinematic_active or not enable_cinematic_controller:
		return
	
	print("🎬 CameraCinemaController: Entering cinematic mode")
	is_cinematic_active = true
	
	# Store current camera state
	store_camera_state()
	
	# Take partial control - only disable following and mouse look
	# Character can still move normally
	disable_camera_following()
	disable_mouse_look()
	
	# Store and release mouse for free cursor
	stored_mouse_mode = Input.mouse_mode
	camera_rig.force_mouse_mode(false)
	
	# Setup auto-exit timer
	if auto_exit_after > 0:
		auto_exit_duration = auto_exit_after
		auto_exit_timer = auto_exit_after
		print("🎬 Auto-exit set for ", auto_exit_after, " seconds")
	else:
		auto_exit_duration = 0.0
	
	cinematic_mode_changed.emit(true)
	print("🎬 Cinematic mode: Camera frozen, mouse free, character can move")

func exit_cinematic_mode():
	"""Exit cinematic mode - return camera control"""
	if not is_cinematic_active:
		return
	
	print("🎬 CameraCinemaController: Exiting cinematic mode")
	is_cinematic_active = false
	auto_exit_duration = 0.0
	
	# Stop any active effects
	if current_effect_tween:
		current_effect_tween.kill()
	
	# Restore camera systems
	restore_camera_following()
	restore_mouse_look()
	
	# Restore mouse mode
	Input.mouse_mode = stored_mouse_mode
	camera_rig.mouse_captured = (stored_mouse_mode == Input.MOUSE_MODE_CAPTURED)
	camera_rig.mouse_mode_changed.emit(camera_rig.mouse_captured)
	
	# Clear stored state
	stored_camera_state.clear()
	
	cinematic_mode_changed.emit(false)
	print("🎬 Cinematic mode exit: Camera following/mouse look restored")

func toggle_cinematic_mode():
	"""Toggle cinematic mode"""
	if is_cinematic_active:
		exit_cinematic_mode()
	else:
		enter_cinematic_mode()

func store_camera_state():
	"""Store current camera state for restoration"""
	stored_camera_state = {
		"position": camera_rig.global_position,
		"rotation_x": camera_rig.camera_rotation_x,
		"rotation_y": camera_rig.camera_rotation_y,
		"fov": camera_rig.current_fov,
		"distance": camera_rig.current_distance,
		"mouse_captured": camera_rig.mouse_captured
	}

# === AUTO-EXIT HANDLING ===

func _on_action_executed(action: Action):
	"""Monitor actions for auto-exit"""
	if not is_cinematic_active or not auto_exit_on_input:
		return
	
	if action.name in input_exit_actions:
		print("🎬 Auto-exit triggered by action: ", action.name)
		exit_cinematic_mode()

# === CINEMATIC EFFECTS ===

func move_camera_to_position(target_position: Vector3, duration: float = 2.0, ease_type: Tween.EaseType = Tween.EASE_IN_OUT):
	"""Move camera to specific world position"""
	if not is_cinematic_active:
		enter_cinematic_mode()
	
	cinematic_effect_started.emit("move_to_position")
	
	if current_effect_tween:
		current_effect_tween.kill()
	
	# Use position override for smooth movement
	current_effect_tween = create_tween()
	current_effect_tween.tween_method(
		camera_rig.set_camera_position_override,
		camera_rig.global_position,
		target_position,
		duration
	).set_ease(ease_type)
	
	current_effect_tween.finished.connect(func(): cinematic_effect_completed.emit("move_to_position"))

func look_at_target(target: Node3D, duration: float = 1.5, ease_type: Tween.EaseType = Tween.EASE_IN_OUT):
	"""Point camera at specific target"""
	if not is_cinematic_active:
		enter_cinematic_mode()
	
	if not target:
		print("❌ CameraCinemaController: No target for look_at")
		return
	
	cinematic_effect_started.emit("look_at_target")
	
	# Calculate target rotation
	var look_direction = (target.global_position - camera_rig.global_position).normalized()
	var target_yaw = atan2(look_direction.x, look_direction.z)
	var target_pitch = asin(-look_direction.y)
	
	if current_effect_tween:
		current_effect_tween.kill()
	
	current_effect_tween = create_tween()
	current_effect_tween.set_parallel(true)
	
	# Tween yaw
	current_effect_tween.tween_method(
		func(val): camera_rig.camera_rotation_y = val,
		camera_rig.camera_rotation_y,
		target_yaw,
		duration
	).set_ease(ease_type)
	
	# Tween pitch
	current_effect_tween.tween_method(
		func(val): camera_rig.camera_rotation_x = val,
		camera_rig.camera_rotation_x,
		target_pitch,
		duration
	).set_ease(ease_type)
	
	current_effect_tween.finished.connect(func(): cinematic_effect_completed.emit("look_at_target"))

func dramatic_zoom(target_fov: float, hold_duration: float = 0.5, return_duration: float = 0.3):
	"""Dramatic zoom effect for special moments"""
	if not camera_rig.camera:
		print("❌ CameraCinemaController: No camera for dramatic zoom")
		return
	
	cinematic_effect_started.emit("dramatic_zoom")
	
	var original_fov = camera_rig.current_fov
	
	if current_effect_tween:
		current_effect_tween.kill()
	
	current_effect_tween = create_tween()
	
	# Quick zoom in
	current_effect_tween.tween_method(
		camera_rig.set_camera_fov,
		original_fov,
		target_fov,
		dramatic_zoom_speed
	)
	
	# Hold
	current_effect_tween.tween_delay(hold_duration)
	
	# Return to original
	current_effect_tween.tween_method(
		camera_rig.set_camera_fov,
		target_fov,
		original_fov,
		return_duration
	).set_ease(Tween.EASE_OUT)
	
	current_effect_tween.finished.connect(func(): cinematic_effect_completed.emit("dramatic_zoom"))

func smooth_zoom_to_fov(target_fov: float, duration: float = 1.0, ease_type: Tween.EaseType = Tween.EASE_IN_OUT):
	"""Smooth zoom transition to target FOV"""
	cinematic_effect_started.emit("smooth_zoom")
	
	if current_effect_tween:
		current_effect_tween.kill()
	
	current_effect_tween = create_tween()
	current_effect_tween.tween_method(
		camera_rig.set_camera_fov,
		camera_rig.current_fov,
		target_fov,
		duration
	).set_ease(ease_type)
	
	current_effect_tween.finished.connect(func(): cinematic_effect_completed.emit("smooth_zoom"))

func orbit_around_target(target: Node3D, radius: float, angle_degrees: float, duration: float = 3.0):
	"""Orbit camera around target"""
	if not target:
		print("❌ CameraCinemaController: No target for orbit")
		return
	
	if not is_cinematic_active:
		enter_cinematic_mode()
	
	cinematic_effect_started.emit("orbit_target")
	
	var start_angle = atan2(
		camera_rig.global_position.x - target.global_position.x,
		camera_rig.global_position.z - target.global_position.z
	)
	var end_angle = start_angle + deg_to_rad(angle_degrees)
	
	if current_effect_tween:
		current_effect_tween.kill()
	
	current_effect_tween = create_tween()
	current_effect_tween.tween_method(
		func(angle):
			var orbit_pos = target.global_position + Vector3(
				sin(angle) * radius,
				camera_rig.global_position.y - target.global_position.y,
				cos(angle) * radius
			)
			camera_rig.set_camera_position_override(orbit_pos),
		start_angle,
		end_angle,
		duration
	).set_ease(Tween.EASE_IN_OUT)
	
	current_effect_tween.finished.connect(func(): cinematic_effect_completed.emit("orbit_target"))

# === CONTROL API ===

func set_enabled(enabled: bool):
	"""Enable/disable cinematic controller"""
	enable_cinematic_controller = enabled
	if not enabled and is_cinematic_active:
		exit_cinematic_mode()
	print("🎬 CameraCinemaController: ", "Enabled" if enabled else "Disabled")

func is_in_cinematic_mode() -> bool:
	"""Check if currently in cinematic mode"""
	return is_cinematic_active

func cancel_current_effect():
	"""Cancel any active cinematic effect"""
	if current_effect_tween:
		current_effect_tween.kill()
		print("🎬 Current cinematic effect cancelled")

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get debug information"""
	return {
		"enabled": enable_cinematic_controller,
		"cinematic_active": is_cinematic_active,
		"auto_exit_timer": auto_exit_timer,
		"auto_exit_on_input": auto_exit_on_input,
		"has_active_effect": current_effect_tween != null and current_effect_tween.is_valid(),
		"action_system_connected": action_system != null,
		"stored_state_keys": stored_camera_state.keys()
	}
