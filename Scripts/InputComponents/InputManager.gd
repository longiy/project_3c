# InputManager.gd - SIMPLIFIED: Raw input detection only (logic migrated to CCC_ControlManager)
extends Node
class_name InputManager

# === SIGNALS ===
signal movement_started(direction: Vector2, magnitude: float)  # DEPRECATED: Use CCC_ControlManager
signal movement_updated(direction: Vector2, magnitude: float)  # DEPRECATED: Use CCC_ControlManager  
signal movement_stopped()  # DEPRECATED: Use CCC_ControlManager
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

# === LEGACY STATE (Used by CCC_ControlManager) ===
var character: CharacterBody3D
var camera_rig: CameraController

var current_raw_input = Vector2.ZERO
var last_sent_input = Vector2.ZERO
var movement_active = false
var movement_start_time = 0.0

var input_components: Array[Node] = []
var movement_update_timer = 0.0
var movement_update_interval: float

# MIGRATION STATUS
var input_logic_migrated = false

func _ready():
	character = get_parent() as CharacterBody3D
	if not character:
		push_error("InputManager must be child of CharacterBody3D")
		return
	
	movement_update_interval = 1.0 / movement_update_frequency
	
	camera_rig = get_node_or_null("../../CAMERARIG") as CameraController
	if not camera_rig:
		push_warning("No CameraController found - click navigation may not work")
	
	call_deferred("find_input_components")
	call_deferred("check_migration_status")

func check_migration_status():
	"""Check if input logic has been migrated to CCC_ControlManager"""
	var control_manager = get_parent().get_node_or_null("CCC_ControlManager")
	if control_manager:
		input_logic_migrated = true
		print("🔄 InputManager: Logic migrated to CCC_ControlManager - operating in legacy mode")
	else:
		input_logic_migrated = false
		print("📦 InputManager: No CCC_ControlManager found - operating in legacy mode")

func _input(event):
	# Handle discrete inputs (always active)
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

func _physics_process(delta):
	# Only handle movement input if logic hasn't been migrated
	if not input_logic_migrated:
		handle_movement_input_legacy(delta)

# === LEGACY MOVEMENT INPUT (Only active if not migrated) ===

func handle_movement_input_legacy(delta: float):
	"""Legacy movement input handling (used when CCC not active)"""
	movement_update_timer += delta
	
	var new_input = get_current_movement_input_legacy()
	var input_magnitude = new_input.length()
	var has_input = input_magnitude > input_deadzone
	
	if not has_input:
		new_input = Vector2.ZERO
	
	var was_moving = movement_active
	var is_moving = has_input
	
	# Movement state changes
	if is_moving and not was_moving:
		movement_active = true
		movement_start_time = Time.get_ticks_msec() / 1000.0
		current_raw_input = new_input
		last_sent_input = new_input
		movement_started.emit(new_input, input_magnitude)
	
	elif not is_moving and was_moving:
		movement_active = false
		current_raw_input = Vector2.ZERO
		last_sent_input = Vector2.ZERO
		movement_stopped.emit()
	
	elif is_moving and movement_update_timer >= movement_update_interval:
		if new_input.distance_to(last_sent_input) > 0.1:
			current_raw_input = new_input
			last_sent_input = new_input
			movement_updated.emit(new_input, input_magnitude)
		movement_update_timer = 0.0

func get_current_movement_input_legacy() -> Vector2:
	"""LEGACY: Complex input priority logic (kept for backward compatibility)"""
	# NOTE: This is the old logic - use CCC_ControlManager.resolve_input_priority() instead
	
	# Check camera mode first
	if camera_rig and camera_rig.is_in_click_navigation_mode():
		# In click navigation mode - check WASD first (override priority)
		var wasd_input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		if wasd_input.length() > input_deadzone:
			# WASD is active - this overrides click navigation
			return wasd_input
		else:
			# No WASD input - check click navigation
			for component in input_components:
				if is_component_active(component):
					var component_input = component.get_movement_input()
					if component_input and component_input.length() > input_deadzone:
						return component_input
	else:
		# In orbit mode - WASD only
		var wasd_input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		if wasd_input.length() > input_deadzone:
			cancel_all_input_components()  # Cancel click nav when switching to orbit
			return wasd_input
	
	return Vector2.ZERO

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
	for component in input_components:
		if component and component.has_method("cancel_input"):
			component.cancel_input()

func find_input_components():
	input_components.clear()
	for child in character.get_children():
		if child != self and child.has_method("get_movement_input"):
			input_components.append(child)
	
	if input_components.size() > 0:
		print("📋 InputManager: Found ", input_components.size(), " input components")

func is_component_active(component: Node) -> bool:
	return is_instance_valid(component) and component.has_method("is_active") and component.is_active()

# === STATE QUERIES ===

func get_movement_duration() -> float:
	if movement_active:
		return (Time.get_ticks_msec() / 1000.0) - movement_start_time
	return 0.0

func is_movement_active() -> bool:
	return movement_active

func get_current_input_direction() -> Vector2:
	return current_raw_input

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	var debug_data = {
		"migration_status": "migrated" if input_logic_migrated else "legacy",
		"movement_active": movement_active,
		"current_input": current_raw_input,
		"movement_duration": get_movement_duration(),
		"component_count": input_components.size(),
		"raw_wasd": get_raw_wasd_input(),
		"raw_click": get_raw_click_input()
	}
	
	if camera_rig:
		debug_data["camera_mode"] = camera_rig.get_mode_name(camera_rig.get_current_mode())
	else:
		debug_data["camera_mode"] = "unknown"
	
	return debug_data

# === MIGRATION HELPERS ===

func disable_legacy_movement_processing():
	"""Called by CCC_ControlManager to disable legacy processing"""
	input_logic_migrated = true
	print("🔄 InputManager: Legacy movement processing disabled")

func enable_legacy_movement_processing():
	"""Re-enable legacy processing if CCC is disabled"""
	input_logic_migrated = false
	print("📦 InputManager: Legacy movement processing enabled")
