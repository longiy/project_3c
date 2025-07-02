# InputManager.gd - Phase 1A: DISABLED for CCC (Raw input detection only)
extends Node
class_name InputManager

# === SIGNALS (Discrete inputs only) ===
signal jump_pressed()
signal sprint_started()
signal sprint_stopped()
signal slow_walk_started()
signal slow_walk_stopped()
signal reset_pressed()
signal click_navigation(world_position: Vector3)

# === SETTINGS ===
@export_group("Input Settings")
@export var input_deadzone = 0.05
@export var movement_update_frequency = 60

# === STATE (Used by CCC_ControlManager) ===
var character: CharacterBody3D
var camera_rig: CameraController

var current_raw_input = Vector2.ZERO
var last_sent_input = Vector2.ZERO
var movement_active = false
var movement_start_time = 0.0

var input_components: Array[Node] = []
var movement_update_timer = 0.0
var movement_update_interval: float

# === CCC INTEGRATION ===
var ccc_control_manager: CCC_ControlManager
var legacy_movement_processing_disabled = false

func _ready():
	character = get_parent() as CharacterBody3D
	if not character:
		push_error("InputManager must be child of CharacterBody3D")
		return
	
	movement_update_interval = 1.0 / movement_update_frequency
	
	camera_rig = get_node_or_null("../../CAMERARIG") as CameraController
	if not camera_rig:
		push_warning("No CameraController found - click navigation may not work")
	
	# Detect CCC architecture
	ccc_control_manager = get_parent().get_node_or_null("CCC_ControlManager")
	
	call_deferred("find_input_components")
	call_deferred("configure_for_ccc")
	
	print("✅ InputManager: Initialized")

func configure_for_ccc():
	"""Configure InputManager for CCC architecture"""
	if ccc_control_manager:
		print("🔄 InputManager: CCC detected - disabling legacy movement processing")
		disable_legacy_movement_processing()
	else:
		print("⚠️ InputManager: No CCC detected - using legacy mode")

func disable_legacy_movement_processing():
	"""Disable legacy movement signal generation"""
	legacy_movement_processing_disabled = true
	print("🚫 InputManager: Legacy movement processing disabled")

func _input(event):
	"""Handle discrete inputs only (movement handled by CCC_ControlManager)"""
	# Handle discrete inputs only
	if event.is_action_pressed("jump"):
		jump_pressed.emit()
	elif event.is_action_pressed("reset"):
		reset_pressed.emit()
	elif event.is_action_pressed("sprint"):
		sprint_started.emit()
	elif event.is_action_released("sprint"):
		sprint_stopped.emit()
	elif event.is_action_pressed("walk"):
		slow_walk_started.emit()
	elif event.is_action_released("walk"):
		slow_walk_stopped.emit()
	
	# Legacy movement processing (disabled when CCC is active)
	if not legacy_movement_processing_disabled:
		handle_legacy_mouse_input(event)

func handle_legacy_mouse_input(event):
	"""Legacy mouse input handling (when CCC is not available)"""
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			handle_legacy_click_navigation(event.position)

func handle_legacy_click_navigation(screen_position: Vector2):
	"""Legacy click navigation handling"""
	if camera_rig:
		var world_position = camera_rig.screen_to_world_position(screen_position)
		if world_position != Vector3.ZERO:
			click_navigation.emit(world_position)

# === RAW INPUT DETECTION (Used by CCC_ControlManager) ===

func get_raw_wasd_input() -> Vector2:
	"""Get raw WASD input without any processing"""
	return Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

func get_raw_click_input() -> Vector2:
	"""Get raw click navigation input without processing"""
	for component in input_components:
		if is_component_active(component):
			var component_input = component.get_movement_input()
			if component_input and component_input.length() > input_deadzone:
				return component_input
	return Vector2.ZERO

# === INPUT COMPONENT MANAGEMENT ===

func cancel_all_input_components():
	"""Cancel all input components"""
	for component in input_components:
		if component and component.has_method("cancel_input"):
			component.cancel_input()

func find_input_components():
	"""Find and register input components"""
	input_components.clear()
	for child in character.get_children():
		if child != self and child.has_method("get_movement_input"):
			input_components.append(child)
	
	if input_components.size() > 0:
		print("📋 InputManager: Found ", input_components.size(), " input components")

func is_component_active(component: Node) -> bool:
	"""Check if input component is active"""
	return is_instance_valid(component) and component.has_method("is_active") and component.is_active()

# === LEGACY COMPATIBILITY METHODS ===

func get_current_input_direction() -> Vector2:
	"""Legacy compatibility: Get current input direction"""
	if ccc_control_manager:
		return ccc_control_manager.get_current_input_direction()
	return current_raw_input

func is_movement_active() -> bool:
	"""Legacy compatibility: Check if movement is active"""
	if ccc_control_manager:
		return ccc_control_manager.is_movement_active()
	return movement_active

func get_movement_duration() -> float:
	"""Legacy compatibility: Get movement duration"""
	if movement_active:
		return (Time.get_ticks_msec() / 1000.0) - movement_start_time
	return 0.0

# === PHYSICS PROCESS (Legacy support) ===

func _physics_process(delta):
	"""Legacy movement processing (disabled when CCC is active)"""
	if legacy_movement_processing_disabled:
		return
	
	# Legacy movement processing code would go here
	# This is disabled when CCC_ControlManager is present

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get debug information"""
	var debug_data = {
		"ccc_detected": ccc_control_manager != null,
		"legacy_disabled": legacy_movement_processing_disabled,
		"input_components": input_components.size(),
		"raw_wasd": get_raw_wasd_input(),
		"raw_click": get_raw_click_input(),
		"movement_active": movement_active,
		"movement_duration": get_movement_duration()
	}
	
	if ccc_control_manager:
		debug_data["ccc_control_info"] = ccc_control_manager.get_debug_info()
	
	return debug_data
