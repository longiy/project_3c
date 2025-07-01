# DebugUI.gd - Updated for MovementManager
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
	
	# Character info
	if info.has("character"):
		var char_info = info.character
		text += "Speed: " + str(char_info.get("movement_speed", 0.0)).pad_decimals(2) + "\n"
		text += "Grounded: " + str(char_info.get("is_grounded", false)) + "\n"
		text += "Running: " + str(char_info.get("is_running", false)) + "\n"
		text += "Slow Walk: " + str(char_info.get("is_slow_walking", false)) + "\n"
	
	# Movement manager info
	if info.has("movement"):
		var movement_info = info.movement
		if movement_info.has("error"):
			text += "Movement Error: " + str(movement_info.error) + "\n"
		else:
			text += "Movement Active: " + str(movement_info.get("movement_active", false)) + "\n"
			text += "Input Direction: " + str(movement_info.get("input_direction", Vector2.ZERO)) + "\n"
			text += "Target State: " + str(movement_info.get("target_state", "unknown")) + "\n"
	
	text += "\n"
	return text

func build_input_section_from_helper(info: Dictionary) -> String:
	var text = "=== INPUT ===\n"
	if info.has("input"):
		var input_info = info.input
		if input_info.has("error"):
			text += "Error: " + str(input_info.error) + "\n"
		else:
			text += "Movement Active: " + str(input_info.get("movement_active", false)) + "\n"
			text += "Current Input: " + str(input_info.get("current_input", Vector2.ZERO)) + "\n"
			text += "Duration: " + str(input_info.get("movement_duration", 0.0)).pad_decimals(2) + "s\n"
			text += "Camera Mode: " + str(input_info.get("camera_mode", "unknown")) + "\n"
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
			text += "System: " + str(anim_info.get("system_type", "Unknown")) + "\n"
			text += "Movement Active: " + str(anim_info.get("is_movement_active", false)) + "\n"
			text += "Input Direction: " + str(anim_info.get("input_direction", Vector2.ZERO)) + "\n"
			text += "Running: " + str(anim_info.get("is_running", false)) + "\n"
			text += "Slow Walking: " + str(anim_info.get("is_slow_walking", false)) + "\n"
			
			# Show blend values
			if anim_info.has("blend_1d"):
				text += "Blend 1D: " + str(anim_info.blend_1d).pad_decimals(2) + " → " + str(anim_info.get("target_1d", 0.0)).pad_decimals(2) + "\n"
			if anim_info.has("blend_2d"):
				text += "Blend 2D: " + str(anim_info.blend_2d) + " → " + str(anim_info.get("target_2d", Vector2.ZERO)) + "\n"
			
			text += "Connection: " + str(anim_info.get("connection_status", "Unknown")) + "\n"
	text += "\n"
	return text

func build_camera_section() -> String:
	"""Build camera debug information"""
	var text = "=== CAMERA ===\n"
	
	var camera_rig = get_node_or_null("../CAMERARIG")
	if camera_rig and camera_rig.has_method("get_camera_debug_info"):
		var cam_info = camera_rig.get_camera_debug_info()
		text += "Follow Mode: " + str(cam_info.get("follow_mode", "Unknown")) + "\n"
		text += "Following: " + str(cam_info.get("is_following", false)) + "\n"
		text += "Mouse Captured: " + str(cam_info.get("mouse_captured", false)) + "\n"
		text += "Distance: " + str(cam_info.get("current_distance", 0.0)).pad_decimals(1) + "\n"
		text += "External Control: " + str(cam_info.get("external_control", false)) + "\n"
	else:
		text += "No Camera Info Available\n"
	
	text += "\n"
	return text

func build_performance_section_from_helper(info: Dictionary) -> String:
	var text = "=== PERFORMANCE ===\n"
	if character.debug_helper:
		var perf_info = character.debug_helper.get_performance_info()
		text += "FPS: " + str(perf_info.fps) + "\n"
		text += "Frame Time: " + str(perf_info.frame_time_ms).pad_decimals(1) + "ms\n"
		text += "Physics Time: " + str(perf_info.physics_time_ms).pad_decimals(1) + "ms\n"
		text += "Memory: " + str(perf_info.memory_usage_mb).pad_decimals(1) + "MB\n"
	text += "\n"
	return text

# === FALLBACK METHODS (for when no DebugHelper) ===

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
			KEY_F2:
				test_movement_system()

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

func test_movement_system():
	"""Test movement system (F2 key)"""
	if character.debug_helper:
		character.debug_helper.test_movement_modes()

# === DEBUG COMMANDS ===

func force_state(state_name: String):
	"""Force character into specific state (for testing)"""
	if character.state_machine and character.state_machine.has_state(state_name):
		character.state_machine.change_state(state_name)
		print("🔧 Debug: Forced state to ", state_name)
	else:
		print("❌ Debug: State not found: ", state_name)

func get_debug_summary() -> String:
	"""Get a one-line debug summary"""
	var state = character.get_current_state_name()
	var speed = character.get_movement_speed()
	var grounded = character.is_on_floor()
	
	return "%s | %.1f u/s | %s" % [state, speed, "Ground" if grounded else "Air"]
