# CameraStateMachine.gd - Fixed logging spam and redundant state switches
extends Node
class_name CameraStateMachine

@export_group("References")
@export var target_character: CharacterBody3D
@export var camera_controller: Node3D
@export var camera_states: Array[CameraState] = []

@export_group("Movement Delays")
@export var enter_move_delay = 0.3
@export var exit_move_delay = 0.1
var last_state_switch_time = 0.0

@export_group("Fallback Values")
@export var default_fov = 75.0
@export var default_distance = 4.0
@export var default_height_offset = 0.0

@export_group("Debug Settings")
@export var enable_debug_logging = false  # NEW: Toggle debug logging

# Internal references
var animation_controller: AnimationController
var state_machine: AnimationNodeStateMachinePlayback
var camera: Camera3D

# State tracking
var current_state: CameraState
var previous_animation_state = ""
var previous_blend_position = 0.0
var state_lookup: Dictionary = {}

# Transition state
var is_transitioning = false
var transition_timer = 0.0
var transition_duration = 0.0
var start_fov = 0.0
var target_fov = 0.0
var start_distance = 0.0
var target_distance = 0.0
var start_offset = Vector3.ZERO
var target_offset = Vector3.ZERO

# NEW: Prevent redundant switches
var blend_change_threshold = 0.01  # Ignore tiny blend changes
var last_logged_state = ""

func _ready():
	# Get references
	if not camera_controller:
		camera_controller = get_parent() 
	
	if not target_character:
		push_error("CameraStateMachine: target_character not assigned")
		return
	
	# Get animation controller
	animation_controller = target_character.get_node("AnimationController")
	if not animation_controller or not animation_controller.animation_tree:
		push_error("CameraStateMachine: AnimationController or AnimationTree not found")
		return
	
	# Get state machine
	state_machine = animation_controller.animation_tree.get("parameters/playback")
	if not state_machine:
		push_error("CameraStateMachine: StateMachine not found in AnimationTree")
		return
	
	# Get camera directly from scene tree
	camera = camera_controller.get_node("SpringArm3D/Camera3D")
	if not camera:
		push_error("CameraStateMachine: Camera not found at SpringArm3D/Camera3D")
		return
	
	# Build state lookup dictionary
	build_state_lookup()
	
	# Initialize with current state
	var current_anim_state = state_machine.get_current_node()
	switch_to_state(current_anim_state)
	
	if enable_debug_logging:
		print("✅ CameraStateMachine initialized with ", camera_states.size(), " states")

func _physics_process(delta):
	if not state_machine:
		return
	
	# Check for animation state changes
	var current_anim_state = state_machine.get_current_node()
	var state_changed = current_anim_state != previous_animation_state
	
	# Check for blend position changes (with threshold)
	var current_blend = animation_controller.animation_tree.get("parameters/Move/blend_position")
	var blend_changed = abs(current_blend - previous_blend_position) > blend_change_threshold
	
	# Get current time for duration tracking
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Movement duration check - separate delays for entering vs leaving
	var duration_ok = true
	if current_anim_state == "Move" or previous_animation_state == "Move":
		if current_anim_state == "Move":
			# Entering Move state - check input duration
			duration_ok = target_character.is_input_sustained(enter_move_delay)
			var input_duration = target_character.get_input_duration()
			if enable_debug_logging:
				print("🔒 Entering Move: input=", "%.3f" % input_duration, "s, required=", enter_move_delay, "s, ok=", duration_ok)
		else:
			# Leaving Move state - check time in Move state
			var time_in_move = current_time - last_state_switch_time
			duration_ok = time_in_move > exit_move_delay
			if enable_debug_logging:
				print("🔒 Leaving Move: time_in_move=", "%.3f" % time_in_move, "s, required=", exit_move_delay, "s, ok=", duration_ok)
	
	# Switch if state/blend changed AND duration requirement met
	var should_switch = (state_changed or blend_changed) and duration_ok
	
	# FIXED: Only log if debug enabled AND there's actually a meaningful change
	if (state_changed or blend_changed) and enable_debug_logging:
		print("🎬 Change detected: state=", state_changed, ", blend=", blend_changed, ", duration_ok=", duration_ok, ", will_switch=", should_switch)
	
	if should_switch:
		# NEW: Check if we're actually switching to a different state
		var target_state_name = get_target_state_name(current_anim_state)
		if target_state_name != last_logged_state:
			var input_duration = target_character.get_input_duration()
			if enable_debug_logging:
				print("📹 Camera state switch: ", last_logged_state, " → ", target_state_name, 
					  " | Blend: ", "%.2f" % current_blend, 
					  " | Input duration: ", "%.2f" % input_duration, "s")
			last_logged_state = target_state_name
		
		switch_to_state(current_anim_state)
		previous_animation_state = current_anim_state
		previous_blend_position = current_blend
		last_state_switch_time = current_time
	
	# Handle camera transitions
	if is_transitioning:
		update_transition(delta)

func get_target_state_name(animation_state_name: String) -> String:
	"""Get the name of the state we would switch to"""
	for state in camera_states:
		if state and state.animation_state_name == animation_state_name:
			if state.blend_parameter_path != "":
				var blend_value = animation_controller.animation_tree.get(state.blend_parameter_path)
				if blend_value >= state.blend_position_min and blend_value <= state.blend_position_max:
					return state.animation_state_name + "_" + str(int(blend_value * 100))
			else:
				return state.animation_state_name
	return "default"

func build_state_lookup():
	"""Build dictionary for fast state lookup by animation name"""
	state_lookup.clear()
	
	for state in camera_states:
		if state and state.animation_state_name != "":
			state_lookup[state.animation_state_name] = state
			if enable_debug_logging:
				print("📋 Registered state: ", state.animation_state_name)

func switch_to_state(animation_state_name: String):
	"""Switch to a new camera state based on animation state and blend position"""
	if animation_state_name == "":
		return
	
	# Find matching state by animation name AND blend position range
	var new_state: CameraState = null
	for state in camera_states:
		if state and state.animation_state_name == animation_state_name:
			# Check if this state uses blend position filtering
			if state.blend_parameter_path != "":
				var blend_value = animation_controller.animation_tree.get(state.blend_parameter_path)
				if blend_value >= state.blend_position_min and blend_value <= state.blend_position_max:
					new_state = state
					break
			else:
				# No blend filtering - use this state directly
				new_state = state
				break
	
	if new_state == current_state:
		return  # Already in this state
	
	if new_state:
		var blend_info = ""
		if new_state.blend_parameter_path != "" and enable_debug_logging:
			var blend_value = animation_controller.animation_tree.get(new_state.blend_parameter_path)
			blend_info = " (blend: " + "%.2f" % blend_value + ")"
		if enable_debug_logging:
			print("🔄 Switching to state: ", new_state.animation_state_name, blend_info)
		start_transition_to_state(new_state)
	else:
		# No matching state found - use defaults
		if enable_debug_logging:
			print("⚠️ No state found for animation: ", animation_state_name)
		start_transition_to_defaults()

func apply_defaults_immediately():
	"""Apply default values instantly"""
	if camera:
		camera.fov = default_fov
	
	if camera_controller:
		camera_controller.target_distance = default_distance
		camera_controller.camera_offset = Vector3.ZERO
	
	is_transitioning = false

func apply_state_immediately(state: CameraState):
	"""Apply state changes instantly without lerping"""
	if camera:
		camera.fov = state.camera_fov
	
	if camera_controller:
		camera_controller.target_distance = state.camera_distance
		camera_controller.camera_offset = state.camera_offset
	
	is_transitioning = false

func start_transition_to_state(new_state: CameraState):
	current_state = new_state
	
	# Store current values as start points
	start_fov = camera.fov if camera else default_fov
	start_distance = camera_controller.current_distance if camera_controller else default_distance
	start_offset = camera_controller.camera_offset if camera_controller else Vector3.ZERO
	
	# Set target values
	target_fov = new_state.camera_fov
	target_distance = new_state.camera_distance
	target_offset = new_state.camera_offset
	
	# Handle transition type
	match new_state.transition_type:
		0: # Smooth
			transition_duration = new_state.enter_transition_speed
			transition_timer = 0.0
			is_transitioning = true
			if enable_debug_logging:
				print("🎬 Starting SMOOTH transition TO ", new_state.animation_state_name, " (speed: ", transition_duration, ")")
		1: # Instant
			apply_state_immediately(new_state)
			if enable_debug_logging:
				print("⚡ INSTANT transition TO ", new_state.animation_state_name)
		2: # Custom
			transition_duration = new_state.enter_transition_speed
			transition_timer = 0.0
			is_transitioning = true
			if enable_debug_logging:
				print("🎨 Starting CUSTOM transition TO ", new_state.animation_state_name, " (speed: ", transition_duration, ")")

func start_transition_to_defaults():
	var leaving_state = current_state
	current_state = null
	
	# Store current values
	start_fov = camera.fov if camera else default_fov
	start_distance = camera_controller.current_distance if camera_controller else default_distance
	start_offset = camera_controller.camera_offset if camera_controller else Vector3.ZERO
	
	# Set target to defaults
	target_fov = default_fov
	target_distance = default_distance
	target_offset = Vector3.ZERO
	
	# Handle exit transition type
	if leaving_state:
		match leaving_state.transition_type:
			0: # Smooth
				transition_duration = leaving_state.exit_transition_speed
				transition_timer = 0.0
				is_transitioning = true
				if enable_debug_logging:
					print("🎬 Starting SMOOTH transition FROM ", leaving_state.animation_state_name, " (speed: ", transition_duration, ")")
			1: # Instant
				apply_defaults_immediately()
				if enable_debug_logging:
					print("⚡ INSTANT transition FROM ", leaving_state.animation_state_name)
			2: # Custom
				transition_duration = leaving_state.exit_transition_speed
				transition_timer = 0.0
				is_transitioning = true
				if enable_debug_logging:
					print("🎨 Starting CUSTOM transition FROM ", leaving_state.animation_state_name, " (speed: ", transition_duration, ")")
	else:
		# Fallback to smooth transition
		transition_duration = 2.0
		transition_timer = 0.0
		is_transitioning = true

func update_transition(delta):
	"""Handle smooth transitions between states"""
	transition_timer += delta
	var progress = transition_timer / transition_duration
	
	if progress >= 1.0:
		# Transition complete
		progress = 1.0
		is_transitioning = false
	
	# Apply smooth interpolation
	if camera:
		camera.fov = lerp(start_fov, target_fov, progress)
	
	if camera_controller:
		camera_controller.target_distance = lerp(start_distance, target_distance, progress)
		camera_controller.camera_offset = start_offset.lerp(target_offset, progress)

# === PUBLIC API ===

func add_camera_state(state: CameraState):
	"""Add a new camera state at runtime"""
	if state and state.animation_state_name != "":
		camera_states.append(state)
		state_lookup[state.animation_state_name] = state
		if enable_debug_logging:
			print("➕ Added runtime state: ", state.animation_state_name)

func remove_camera_state(animation_state_name: String):
	"""Remove a camera state at runtime"""
	if state_lookup.has(animation_state_name):
		var state = state_lookup[animation_state_name]
		camera_states.erase(state)
		state_lookup.erase(animation_state_name)
		if enable_debug_logging:
			print("➖ Removed state: ", animation_state_name)

func get_current_state() -> CameraState:
	"""Get currently active camera state"""
	return current_state

func force_state_refresh():
	"""Force a state refresh (useful for debugging)"""
	previous_animation_state = ""

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	return {
		"current_state": current_state.animation_state_name if current_state else "None",
		"animation_state": state_machine.get_current_node() if state_machine else "None",
		"is_transitioning": is_transitioning,
		"states_loaded": camera_states.size(),
		"current_fov": camera.fov if camera else 0.0,
		"target_distance": camera_controller.target_distance if camera_controller else 0.0,
		"current_offset": camera_controller.camera_offset if camera_controller else Vector3.ZERO
	}
