# CameraStateComponent.gd - Manages camera properties based on animation states
extends Node
class_name CameraStateComponent

@export_group("References")
@export var target_character: CharacterBody3D
@export var camera_controller: Node3D
@export var camera_states: Array[CameraState] = []

@export_group("Fallback Values")
@export var default_fov = 75.0
@export var default_distance = 4.0
@export var default_height_offset = 0.0

# Internal references
var animation_controller: AnimationController
var state_machine: AnimationNodeStateMachinePlayback
var camera: Camera3D

# State tracking
var current_state: CameraState
var previous_animation_state = ""
var previous_blend_position = 0.0  # ADD THIS
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

# Hysteresis settings
var blend_change_threshold = 0.15  # Minimum change to trigger state switch
var state_switch_cooldown = 0.5    # Minimum time between state switches
var last_state_switch_time = 1

func _ready():
	# Get references
	if not camera_controller:
		camera_controller = get_parent() 
	
	if not target_character:
		push_error("CameraStateComponent: target_character not assigned")
		return
	
	# Get animation controller
	animation_controller = target_character.get_node("AnimationController")
	if not animation_controller or not animation_controller.animation_tree:
		push_error("CameraStateComponent: AnimationController or AnimationTree not found")
		return
	
	# Get state machine
	state_machine = animation_controller.animation_tree.get("parameters/playback")
	if not state_machine:
		push_error("CameraStateComponent: StateMachine not found in AnimationTree")
		return
	
	# Get camera directly from scene tree
	camera = camera_controller.get_node("SpringArm3D/Camera3D")
	if not camera:
		push_error("CameraStateComponent: Camera not found at SpringArm3D/Camera3D")
		return
	
	# Build state lookup dictionary
	build_state_lookup()
	
	# Initialize with current state
	var current_anim_state = state_machine.get_current_node()
	switch_to_state(current_anim_state)
	
	print("✅ CameraStateComponent initialized with ", camera_states.size(), " states")

func _physics_process(delta):
	if not state_machine:
		return
	
	# Check for animation state changes
	var current_anim_state = state_machine.get_current_node()
	var state_changed = current_anim_state != previous_animation_state
	
	# Check for significant blend position changes with hysteresis
	var current_blend = animation_controller.animation_tree.get("parameters/Move/blend_position")
	var blend_changed = abs(current_blend - previous_blend_position) > blend_change_threshold
	
	# Add cooldown to prevent rapid switching
	var current_time = Time.get_ticks_msec() / 1000.0  # Convert to seconds
	var time_since_last_switch = current_time - last_state_switch_time
	var cooldown_expired = time_since_last_switch > state_switch_cooldown
	
	if state_changed or (blend_changed and cooldown_expired):
		if state_changed:
			print("🎬 Animation state changed: ", previous_animation_state, " → ", current_anim_state)
		if blend_changed and cooldown_expired:
			print("🎚️ Blend position changed: ", previous_blend_position, " → ", current_blend)
		
		switch_to_state(current_anim_state)
		previous_animation_state = current_anim_state
		previous_blend_position = current_blend
		last_state_switch_time = Time.get_ticks_msec() / 1000.0
	
	# Handle transitions
	if is_transitioning:
		update_transition(delta)

func build_state_lookup():
	"""Build dictionary for fast state lookup by animation name"""
	state_lookup.clear()
	
	for state in camera_states:
		if state and state.animation_state_name != "":
			state_lookup[state.animation_state_name] = state
			print("📋 Registered state: ", state.animation_state_name)

func switch_to_state(animation_state_name: String):
	"""Switch to a new camera state based on animation state and blend position"""
	if animation_state_name == "":
		return
	# DEBUG: Check current blend value
	var current_blend_value = animation_controller.animation_tree.get("parameters/Move/blend_position")
	print("🔍 Current blend value: ", current_blend_value)
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
		if new_state.blend_parameter_path != "":
			var blend_value = animation_controller.animation_tree.get(new_state.blend_parameter_path)
			blend_info = " (blend: " + str(blend_value) + ")"
		print("🔄 Switching to state: ", new_state.animation_state_name, blend_info)
		start_transition_to_state(new_state)
	else:
		# No matching state found - use defaults
		print("⚠️ No state found for animation: ", animation_state_name)
		start_transition_to_defaults()

func start_transition_to_state(new_state: CameraState):
	"""Start smooth transition to new state"""
	current_state = new_state
	
	# Store current values as start points
	start_fov = camera.fov if camera else default_fov
	start_distance = camera_controller.current_distance if camera_controller else default_distance
	start_offset = camera_controller.camera_offset if camera_controller else Vector3.ZERO
	
	# Set target values
	target_fov = new_state.camera_fov
	target_distance = new_state.camera_distance
	target_offset = new_state.camera_offset
	
	# Start transition with custom speed from the state
	transition_duration = new_state.transition_speed
	transition_timer = 0.0
	is_transitioning = true

func start_transition_to_defaults():
	"""Transition back to default values when no state matches"""
	current_state = null
	
	# Store current values
	start_fov = camera.fov if camera else default_fov
	start_distance = camera_controller.current_distance if camera_controller else default_distance
	start_offset = camera_controller.camera_offset if camera_controller else Vector3.ZERO
	
	# Set target to defaults
	target_fov = default_fov
	target_distance = default_distance
	target_offset = Vector3.ZERO
	
	# Start transition
	transition_duration = 2.0  # Default transition speed
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
		print("➕ Added runtime state: ", state.animation_state_name)

func remove_camera_state(animation_state_name: String):
	"""Remove a camera state at runtime"""
	if state_lookup.has(animation_state_name):
		var state = state_lookup[animation_state_name]
		camera_states.erase(state)
		state_lookup.erase(animation_state_name)
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
