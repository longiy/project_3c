# CCC_ControlManager.gd - Enhanced with migrated input priority logic
extends Node
class_name CCC_ControlManager

# === WRAPPED COMPONENT ===
@export var input_manager: InputManager

# === CAMERA REFERENCE (Migrated from InputManager) ===
var camera_manager: CCC_CameraManager

# === SIGNALS (Passthrough from InputManager) ===
signal movement_started(direction: Vector2, magnitude: float)
signal movement_updated(direction: Vector2, magnitude: float)
signal movement_stopped()
signal jump_pressed()
signal sprint_started()
signal sprint_stopped()
signal slow_walk_started()
signal slow_walk_stopped()
signal reset_pressed()
signal click_navigation(world_position: Vector3)

# === CCC CONTROL CONFIGURATION ===
enum ControlType {
	DIRECT,        # WASD/Gamepad direct control only
	TARGET_BASED,  # Click-to-move only
	HYBRID,        # Both WASD and click (current implementation)
	GESTURAL       # Pattern-based input (future)
}

var current_control_type: ControlType = ControlType.HYBRID

# === MIGRATED INPUT STATE (from InputManager) ===
var wasd_is_overriding = false
var current_input_priority: String = "none"

func _ready():
	setup_input_manager()
	setup_camera_reference()
	connect_input_signals()
	print("✅ CCC_ControlManager: Initialized with migrated input logic")

func setup_input_manager():
	"""Find and reference InputManager"""
	if not input_manager:
		input_manager = get_node_or_null("InputManager")
	
	if not input_manager:
		# Try finding it as a sibling
		input_manager = get_parent().get_node_or_null("InputManager")
	
	if not input_manager:
		push_error("CCC_ControlManager: No InputManager found!")
		return

func setup_camera_reference():
	"""Setup reference to camera manager for input priority decisions"""
	camera_manager = get_parent().get_node_or_null("CCC_CameraManager")
	if not camera_manager:
		push_warning("CCC_ControlManager: No CCC_CameraManager found - using legacy camera detection")

func connect_input_signals():
	"""Connect InputManager signals but intercept movement for processing"""
	if not input_manager:
		return
	
	# Connect discrete input signals directly (no processing needed)
	input_manager.jump_pressed.connect(_on_jump_pressed)
	input_manager.sprint_started.connect(_on_sprint_started)
	input_manager.sprint_stopped.connect(_on_sprint_stopped)
	input_manager.slow_walk_started.connect(_on_slow_walk_started)
	input_manager.slow_walk_stopped.connect(_on_slow_walk_stopped)
	input_manager.reset_pressed.connect(_on_reset_pressed)
	input_manager.click_navigation.connect(_on_click_navigation)
	
	# MIGRATION: Disable InputManager's movement processing
	input_manager.disable_legacy_movement_processing()
	
	# Take over movement signal generation
	print("🔄 CCC_ControlManager: Taking over movement processing from InputManager")

func _physics_process(delta):
	"""MIGRATED: Handle movement input processing (was in InputManager)"""
	process_movement_input(delta)

# === MIGRATED INPUT PRIORITY LOGIC ===

func process_movement_input(delta: float):
	"""MIGRATED: Main movement input processing from InputManager"""
	if not input_manager:
		return
	
	# Get current input using new priority system
	var new_input = resolve_input_priority()
	var input_magnitude = new_input.length()
	var has_input = input_magnitude > get_input_deadzone()
	
	if not has_input:
		new_input = Vector2.ZERO
	
	var was_moving = input_manager.movement_active
	var is_moving = has_input
	
	# Movement state changes (same logic as InputManager)
	if is_moving and not was_moving:
		input_manager.movement_active = true
		input_manager.movement_start_time = Time.get_ticks_msec() / 1000.0
		input_manager.current_raw_input = new_input
		input_manager.last_sent_input = new_input
		movement_started.emit(new_input, input_magnitude)
		print("🎮 CCC_ControlManager: Movement started via ", current_input_priority)
	
	elif not is_moving and was_moving:
		input_manager.movement_active = false
		input_manager.current_raw_input = Vector2.ZERO
		input_manager.last_sent_input = Vector2.ZERO
		movement_stopped.emit()
		
		# Handle WASD override cleanup
		if wasd_is_overriding:
			cancel_all_input_components()
			wasd_is_overriding = false
		
		print("🎮 CCC_ControlManager: Movement stopped")
	
	elif is_moving and should_update_movement(new_input):
		input_manager.current_raw_input = new_input
		input_manager.last_sent_input = new_input
		movement_updated.emit(new_input, input_magnitude)

func resolve_input_priority() -> Vector2:
	"""MIGRATED: Smart input priority resolution (was InputManager.get_current_movement_input)"""
	match current_control_type:
		ControlType.DIRECT:
			return get_direct_input()
		ControlType.TARGET_BASED:
			return get_target_based_input()
		ControlType.HYBRID:
			return get_hybrid_input()  # Current implementation
		_:
			return Vector2.ZERO

func get_direct_input() -> Vector2:
	"""Direct control only - WASD/gamepad"""
	current_input_priority = "direct"
	wasd_is_overriding = false
	cancel_all_input_components()  # Cancel any click navigation
	return get_raw_wasd_input()

func get_target_based_input() -> Vector2:
	"""Target-based control only - click navigation"""
	current_input_priority = "target_based"
	wasd_is_overriding = false
	return get_click_navigation_input()

func get_hybrid_input() -> Vector2:
	"""MIGRATED: Hybrid control with WASD override (current system)"""
	# Check if we're in click navigation camera mode
	if is_in_click_navigation_camera_mode():
		# In click navigation mode - check WASD first (override priority)
		var wasd_input = get_raw_wasd_input()
		if wasd_input.length() > get_input_deadzone():
			# WASD is active - this overrides click navigation
			wasd_is_overriding = true
			current_input_priority = "wasd_override"
			return wasd_input
		else:
			# No WASD input - check click navigation
			wasd_is_overriding = false
			current_input_priority = "click_navigation"
			return get_click_navigation_input()
	else:
		# In orbit mode - WASD only
		wasd_is_overriding = false
		current_input_priority = "wasd_orbit"
		var wasd_input = get_raw_wasd_input()
		if wasd_input.length() > get_input_deadzone():
			cancel_all_input_components()  # Cancel click nav when switching to orbit
			return wasd_input
	
	current_input_priority = "none"
	return Vector2.ZERO

# === RAW INPUT DETECTION (Simplified from InputManager) ===

func get_raw_wasd_input() -> Vector2:
	"""Get raw WASD input without any processing"""
	return Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

func get_click_navigation_input() -> Vector2:
	"""Get input from click navigation components"""
	if not input_manager:
		return Vector2.ZERO
	
	for component in input_manager.input_components:
		if is_component_active(component):
			var component_input = component.get_movement_input()
			if component_input and component_input.length() > get_input_deadzone():
				return component_input
	
	return Vector2.ZERO

# === CAMERA MODE DETECTION ===

func is_in_click_navigation_camera_mode() -> bool:
	"""Detect if camera is in click navigation mode"""
	# Try CCC camera manager first
	if camera_manager:
		return camera_manager.is_in_click_navigation_mode()
	
	# Fallback to legacy detection
	if input_manager and input_manager.camera_rig:
		return input_manager.camera_rig.is_in_click_navigation_mode()
	
	return false

# === UTILITY METHODS ===

func get_input_deadzone() -> float:
	"""Get input deadzone from InputManager"""
	if input_manager:
		return input_manager.input_deadzone
	return 0.05

func should_update_movement(new_input: Vector2) -> bool:
	"""Check if movement should be updated"""
	if not input_manager:
		return false
	
	input_manager.movement_update_timer += get_physics_process_delta_time()
	
	if input_manager.movement_update_timer >= input_manager.movement_update_interval:
		if new_input.distance_to(input_manager.last_sent_input) > 0.1:
			input_manager.movement_update_timer = 0.0
			return true
	
	return false

func is_component_active(component: Node) -> bool:
	"""Check if input component is active"""
	return is_instance_valid(component) and component.has_method("is_active") and component.is_active()

func cancel_all_input_components():
	"""Cancel all input components"""
	if input_manager:
		input_manager.cancel_all_input_components()

# === DIRECT PASSTHROUGH HANDLERS (Unchanged) ===

func _on_jump_pressed():
	jump_pressed.emit()

func _on_sprint_started():
	sprint_started.emit()

func _on_sprint_stopped():
	sprint_stopped.emit()

func _on_slow_walk_started():
	slow_walk_started.emit()

func _on_slow_walk_stopped():
	slow_walk_stopped.emit()

func _on_reset_pressed():
	reset_pressed.emit()

func _on_click_navigation(world_position: Vector3):
	click_navigation.emit(world_position)

# === PASSTHROUGH METHODS (Some now delegated to new logic) ===

func get_current_input_direction() -> Vector2:
	"""Get current input direction"""
	if input_manager:
		return input_manager.get_current_input_direction()
	return Vector2.ZERO

func is_movement_active() -> bool:
	"""Check if movement is currently active"""
	if input_manager:
		return input_manager.is_movement_active()
	return false

func get_movement_duration() -> float:
	"""Get how long movement has been active"""
	if input_manager:
		return input_manager.get_movement_duration()
	return 0.0

# === CCC CONTROL INTERFACE (Enhanced) ===

func configure_control_type(control_type: ControlType):
	"""Configure the control scheme"""
	var old_type = current_control_type
	current_control_type = control_type
	
	print("🎮 CCC_ControlManager: Control type changed from ", ControlType.keys()[old_type], " to ", ControlType.keys()[control_type])
	
	# Apply immediate changes based on control type
	match control_type:
		ControlType.DIRECT:
			cancel_all_input_components()
			print("   → Direct control: WASD/gamepad only")
		ControlType.TARGET_BASED:
			print("   → Target-based control: Click navigation only")
		ControlType.HYBRID:
			print("   → Hybrid control: WASD overrides click navigation")

func set_control_sensitivity(sensitivity: float):
	"""Set control sensitivity (future implementation)"""
	# TODO: Implement when adding advanced control configuration
	pass

func enable_input_buffering(enabled: bool):
	"""Enable/disable input buffering (future implementation)"""
	# TODO: Implement when adding advanced control features
	pass

# === DEBUG INFO (Enhanced) ===

func get_debug_info() -> Dictionary:
	"""Get enhanced debug information"""
	var debug_data = {
		"control_type": ControlType.keys()[current_control_type],
		"current_priority": current_input_priority,
		"wasd_overriding": wasd_is_overriding,
		"camera_mode": "click_nav" if is_in_click_navigation_camera_mode() else "orbit",
		"migration_status": "input_priority_migrated"
	}
	
	if input_manager:
		debug_data.merge({
			"raw_wasd": get_raw_wasd_input(),
			"click_input": get_click_navigation_input(),
			"resolved_input": resolve_input_priority(),
			"movement_active": is_movement_active(),
			"input_deadzone": get_input_deadzone()
		})
	else:
		debug_data["input_manager"] = "missing"
	
	return debug_data
