# DebugUI.gd - Streamlined debug interface for focused character system
extends Control

@export var debug_label: Label
@export var character: CharacterBody3D

@export_group("Debug Options")
@export var show_state_info = true
@export var show_movement_info = true
@export var show_input_info = true
@export var show_physics_info = true
@export var show_animation_info = true
@export var show_camera_info = true
@export var show_performance_info = false

func _process(_delta):
	if character and debug_label:
		update_debug_display()

func update_debug_display():
	"""Update the debug display with organized information"""
	var debug_text = ""
	
	# Use DebugHelper if available for comprehensive info
	if character.debug_helper:
		var comprehensive_info = character.debug_helper.get_comprehensive_debug_info()
		
		if show_state_info:
			debug_text += build_state_section_from_helper(comprehensive_info)
		
		if show_movement_info:
			debug_text += build_movement_section_from_helper(comprehensive_info)
		
		if show_input_info:
			debug_text += build_input_section_from_helper(comprehensive_info)
		
		if show_physics_info:
			debug_text += build_physics_section_from_helper(comprehensive_info)
		
		if show_animation_info:
			debug_text += build_animation_section_from_helper(comprehensive_info)
		
		if show_camera_info:
			debug_text += build_camera_section()
		
		if show_performance_info:
			debug_text += build_performance_section_from_helper(comprehensive_info)
	else:
		# Fallback to original methods if no DebugHelper
		debug_text += "⚠️ No DebugHelper - Limited info available\n\n"
		
		if show_state_info:
			debug_text += build_state_section()
		
		if show_movement_info:
			debug_text += build_movement_section()
	
	debug_label.text = debug_text

func build_state_section_from_helper(info: Dictionary) -> String:
	var text = "=== CHARACTER STATE ===\n"
	if info.has("state"):
		var state_info = info.state
		text += "Current: " + str(state_info.get("current_state", "unknown")) + "\n"
		text += "Previous: " + str(state_info.get("previous_state", "unknown")) + "\n"
		text += "Transitions: " + str(state_info.get("total_transitions", 0)) + "\n"
		text += "Time in State: " + str(state_info.get("time_in_current", 0.0)).pad_decimals(2) + "s\n"
	text += "\n"
	return text

func build_movement_section_from_helper(info: Dictionary) -> String:
	var text = "=== MOVEMENT ===\n"
	if info.has("character"):
		var char_info = info.character
		text += "Speed: " + str(char_info.get("movement_speed", 0.0)).pad_decimals(2) + "\n"
		text += "Grounded: " + str(char_info.get("is_grounded", false)) + "\n"
		text += "Running: " + str(char_info.get("is_running", false)) + "\n"
		text += "Slow Walk: " + str(char_info.get("is_slow_walking", false)) + "\n"
	text += "\n"
	return text

func build_input_section_from_helper(info: Dictionary) -> String:
	var text = "=== INPUT ===\n"
	if info.has("input"):
		var input_info = info.input
		if input_info.has("error"):
			text += "Error: " + str(input_info.error) + "\n"
		else:
			text += "Raw: " + str(input_info.get("raw_input", Vector2.ZERO).round()) + "\n"
			text += "Smoothed: " + str(input_info.get("smoothed_input", Vector2.ZERO).round()) + "\n"
			text += "Duration: " + str(input_info.get("input_duration", 0.0)).pad_decimals(2) + "s\n"
			text += "Active: " + str(input_info.get("is_active", false)) + "\n"
	text += "\n"
	return text

func build_physics_section_from_helper(info: Dictionary) -> String:
	var text = "=== PHYSICS ===\n"
	
	# Physics info
	if info.has("physics"):
		var physics_info = info.physics
		text += "On Floor: " + str(physics_info.get("on_floor", false)) + "\n"
		text += "On Wall: " + str(physics_info.get("on_wall", false)) + "\n"
		text += "On Ceiling: " + str(physics_info.get("on_ceiling", false)) + "\n"
	
	# Jump info
	if info.has("jump"):
		var jump_info = info.jump
		if jump_info.has("error"):
			text += "Jump Error: " + str(jump_info.error) + "\n"
		else:
			text += "Jumps Left: " + str(jump_info.get("jumps_remaining", 0)) + "\n"
			text += "Can Jump: " + str(jump_info.get("can_jump", false)) + "\n"
			text += "Coyote Timer: " + str(jump_info.get("coyote_timer", 0.0)).pad_decimals(2) + "\n"
	
	text += "\n"
	return text

func build_animation_section_from_helper(info: Dictionary) -> String:
	var text = "=== ANIMATION ===\n"
	if info.has("animation"):
		var anim_info = info.animation
		if anim_info.has("error"):
			text += "Error: " + str(anim_info.error) + "\n"
		else:
			text += "Movement Speed: " + str(anim_info.get("movement_speed", 0.0)).pad_decimals(2) + "\n"
			if anim_info.has("blend_1d"):
				text += "Blend 1D: " + str(anim_info.blend_1d).pad_decimals(2) + "\n"
	text += "\n"
	return text

func build_performance_section_from_helper(_info: Dictionary) -> String:
	var text = "=== PERFORMANCE ===\n"
	if character.debug_helper:
		var perf_info = character.debug_helper.get_performance_info()
		text += "FPS: " + str(perf_info.fps) + "\n"
		text += "Frame Time: " + str(perf_info.frame_time_ms).pad_decimals(1) + "ms\n"
		text += "Physics Time: " + str(perf_info.physics_time_ms).pad_decimals(1) + "ms\n"
		text += "Memory: " + str(perf_info.memory_usage_mb).pad_decimals(1) + "MB\n"
	text += "\n"
	return text

func build_state_section() -> String:
	"""Build state machine debug information"""
	var text = "=== CHARACTER STATE ===\n"
	
	var current_state = character.get_current_state_name()
	var previous_state = character.get_previous_state_name()
	
	text += "Current: " + current_state + "\n"
	text += "Previous: " + previous_state + "\n"
	
	# Get state machine specific info
	if character.state_machine:
		var state_info = character.state_machine.get_state_transition_summary()
		text += "Transitions: " + str(state_info.total_transitions) + "\n"
		text += "Time in State: " + str(state_info.time_in_current).pad_decimals(2) + "s\n"
		
		if state_info.recent_history.size() > 1:
			var recent = state_info.recent_history.slice(-4)  # Last 4 states
			text += "Recent: " + " → ".join(recent) + "\n"
	
	text += "\n"
	return text

func build_movement_section() -> String:
	"""Build movement debug information"""
	var text = "=== MOVEMENT ===\n"
	
	var speed = character.get_movement_speed()
	text += "Speed: " + str(speed).pad_decimals(2) + "\n"
	text += "Target Speed: " + str(character.get_target_speed()).pad_decimals(1) + "\n"
	
	# Movement modes
	var modes = []
	if character.is_slow_walking:
		modes.append("Slow Walk")
	if character.is_running:
		modes.append("Running")
	if modes.size() == 0:
		modes.append("Normal")
	
	text += "Mode: " + ", ".join(modes) + "\n"
	text += "Velocity: " + str(character.velocity.round()) + "\n"
	
	text += "\n"
	return text

func build_input_section() -> String:
	"""Build input debug information"""
	var text = "=== INPUT ===\n"
	
	# Get input info from InputManager if available
	if character.input_manager:
		var input_info = character.input_manager.get_debug_info()
		text += "Raw: " + str(input_info.raw_input.round()) + "\n"
		text += "Smoothed: " + str(input_info.smoothed_input.round()) + "\n"
		text += "Duration: " + str(input_info.input_duration).pad_decimals(2) + "s\n"
		text += "Sustained: " + str(input_info.sustained) + "\n"
		
		# Active components
		if input_info.active_components.size() > 0:
			text += "Active: " + ", ".join(input_info.active_components) + "\n"
		else:
			text += "Active: WASD\n"
	else:
		# Fallback if no InputManager
		text += "No InputManager found\n"
	
	text += "\n"
	return text

func build_physics_section() -> String:
	"""Build physics debug information"""
	var text = "=== PHYSICS ===\n"
	
	text += "On Floor: " + str(character.is_on_floor()) + "\n"
	text += "On Wall: " + str(character.is_on_wall()) + "\n"
	text += "On Ceiling: " + str(character.is_on_ceiling()) + "\n"
	
	# Jump information from JumpSystem
	if character.jump_system:
		var jump_info = character.jump_system.get_debug_info()
		text += "Jumps Left: " + str(jump_info.jumps_remaining) + "/" + str(jump_info.max_air_jumps + 1) + "\n"
		text += "Coyote Timer: " + str(jump_info.coyote_timer).pad_decimals(2) + "\n"
		text += "Jump Buffer: " + str(jump_info.jump_buffer_timer).pad_decimals(2) + "\n"
		text += "Can Jump: " + str(jump_info.can_jump) + "\n"
		text += "Can Air Jump: " + str(jump_info.can_air_jump) + "\n"
	else:
		text += "No JumpSystem found\n"
	
	# Floor properties
	if character.is_on_floor():
		text += "Floor Normal: " + str(character.get_floor_normal().round()) + "\n"
		var floor_angle = rad_to_deg(character.get_floor_normal().angle_to(Vector3.UP))
		text += "Floor Angle: " + str(floor_angle).pad_decimals(1) + "°\n"
	
	text += "\n"
	return text

func build_animation_section() -> String:
	"""Build animation debug information"""
	var text = "=== ANIMATION ===\n"
	
	if character.animation_controller:
		var anim_info = character.animation_controller.get_debug_info()
		text += "Movement Speed: " + str(anim_info.movement_speed).pad_decimals(2) + "\n"
		
		if anim_info.has("blend_1d"):
			text += "Blend 1D: " + str(anim_info.blend_1d).pad_decimals(2) + "\n"
		if anim_info.has("blend_2d"):
			text += "Blend 2D: " + str(anim_info.blend_2d) + "\n"
		
		text += "Mode: " + ("1D" if anim_info.is_1d_mode else "2D") + "\n"
	else:
		text += "No AnimationController\n"
	
	text += "\n"
	return text

func build_camera_section() -> String:
	"""Build camera debug information"""
	var text = "=== CAMERA ===\n"
	
	var camera_rig = get_node_or_null("../CAMERARIG")
	if camera_rig and camera_rig.has_method("get_camera_debug_info"):
		var cam_info = camera_rig.get_camera_debug_info()
		text += "Follow Mode: " + cam_info.follow_mode + "\n"
		text += "Following: " + str(cam_info.is_following) + "\n"
		text += "Mouse Captured: " + str(cam_info.mouse_captured) + "\n"
		text += "Distance: " + str(cam_info.current_distance).pad_decimals(1) + "\n"
		text += "Rotation: " + str(cam_info.camera_rotation_x).pad_decimals(1) + "°, " + str(cam_info.camera_rotation_y).pad_decimals(1) + "°\n"
	else:
		text += "No Camera Info Available\n"
	
	text += "\n"
	return text

func build_performance_section() -> String:
	"""Build performance debug information"""
	var text = "=== PERFORMANCE ===\n"
	
	text += "FPS: " + str(Engine.get_frames_per_second()) + "\n"
	text += "Frame Time: " + str(get_process_delta_time() * 1000).pad_decimals(1) + "ms\n"
	
	# State machine performance
	if character.state_machine:
		var state_count = character.state_machine.states.size()
		var transition_count = character.state_machine.transition_count
		text += "States: " + str(state_count) + "\n"
		text += "Total Transitions: " + str(transition_count) + "\n"
	
	text += "\n"
	return text

# === DEBUG CONTROLS ===

func _input(event):
	"""Handle debug input for testing"""
	if event.is_action_pressed("reset"):
		character.reset_character()
	
	# Toggle debug sections with number keys
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				show_state_info = !show_state_info
			KEY_2:
				show_movement_info = !show_movement_info
			KEY_3:
				show_input_info = !show_input_info
			KEY_4:
				show_physics_info = !show_physics_info
			KEY_5:
				show_animation_info = !show_animation_info
			KEY_6:
				show_camera_info = !show_camera_info
			KEY_7:
				show_performance_info = !show_performance_info
			KEY_F1:
				toggle_all_debug_sections()

func toggle_all_debug_sections():
	"""Toggle all debug sections on/off"""
	var new_state = not (show_state_info and show_movement_info and show_input_info)
	
	show_state_info = new_state
	show_movement_info = new_state
	show_input_info = new_state
	show_physics_info = new_state
	show_animation_info = new_state
	show_camera_info = new_state
	show_performance_info = new_state

# === DEBUG COMMANDS ===

func force_state(state_name: String):
	"""Force character into specific state (for testing)"""
	if character.state_machine and character.state_machine.has_state(state_name):
		character.force_state_change(state_name)
		print("🔧 Debug: Forced state to ", state_name)
	else:
		print("❌ Debug: State not found: ", state_name)

func test_all_states():
	"""Cycle through all states for testing"""
	var states = ["idle", "walking", "running", "jumping", "airborne", "landing"]
	for state in states:
		await get_tree().create_timer(1.0).timeout
		force_state(state)
		print("🧪 Testing state: ", state)

func get_debug_summary() -> String:
	"""Get a one-line debug summary"""
	var state = character.get_current_state_name()
	var speed = character.get_movement_speed()
	var grounded = character.is_on_floor()
	
	return "%s | %.1f u/s | %s" % [state, speed, "Ground" if grounded else "Air"]
