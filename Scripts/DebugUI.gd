# DebugUI.gd - UPDATED to show state machine information
extends Control

@export var debug_label: Label
@export var character: CharacterBody3D

func _process(delta):
	if character and debug_label:
		var debug_text = ""
		
		# === STATE MACHINE INFO ===
		debug_text += "=== CHARACTER STATE ===\n"
		debug_text += "Current State: " + character.get_current_character_state() + "\n"
		debug_text += "Previous State: " + character.get_previous_character_state() + "\n"
		
		# State-specific debug info
		var state_info = character.get_state_debug_info()
		if state_info.has("time_in_state"):
			debug_text += "Time in State: " + str(state_info.time_in_state).pad_decimals(2) + "s\n"
		
		debug_text += "\n=== JUMPING ===\n"
		debug_text += "Jumps Remaining: " + str(character.jumps_remaining) + "/" + str(character.max_jumps) + "\n"
		debug_text += "Coyote Timer: " + str(character.coyote_timer).pad_decimals(2) + "\n"
		
		if state_info.has("can_jump"):
			debug_text += "Can Jump: " + str(state_info.can_jump) + "\n"
		if state_info.has("can_air_jump"):
			debug_text += "Can Air Jump: " + str(state_info.can_air_jump) + "\n"
		
		debug_text += "\n=== MOVEMENT ===\n"
		debug_text += "Velocity: " + str(character.velocity.round()) + "\n"
		debug_text += "Speed: " + str(character.velocity.length()).pad_decimals(2) + "\n"
		debug_text += "Input Duration: " + str(character.get_input_duration()).pad_decimals(2) + "s\n"
		
		# === PHYSICS INFO ===
		debug_text += "\n=== PHYSICS ===\n"
		debug_text += "Is on Floor: " + str(character.is_on_floor()) + "\n"
		debug_text += "Is on Wall: " + str(character.is_on_wall()) + "\n"
		debug_text += "Is on Ceiling: " + str(character.is_on_ceiling()) + "\n"
		
		# Floor properties
		if character.is_on_floor():
			debug_text += "Floor Normal: " + str(character.get_floor_normal().round()) + "\n"
			var floor_angle = rad_to_deg(character.get_floor_normal().angle_to(Vector3.UP))
			debug_text += "Floor Angle: " + str(floor_angle).pad_decimals(1) + "°\n"
		
		# Collision info
		debug_text += "Collision Count: " + str(character.get_slide_collision_count()) + "\n"
		if character.get_slide_collision_count() > 0:
			var collision = character.get_slide_collision(0)
			debug_text += "Colliding with: " + str(collision.get_collider().name) + "\n"
		
		# === STATE HISTORY ===
		if character.state_machine:
			var history = character.state_machine.get_state_history()
			if history.size() > 1:
				debug_text += "\n=== STATE HISTORY ===\n"
				var recent_states = history.slice(-5)  # Last 5 states
				debug_text += "Recent: " + " → ".join(recent_states) + "\n"
		
		# === ANIMATION INFO ===
		if character.animation_controller:
			var anim_info = character.animation_controller.get_debug_info()
			debug_text += "\n=== ANIMATION ===\n"
			debug_text += "Movement Speed: " + str(anim_info.movement_speed).pad_decimals(2) + "\n"
			debug_text += "Blend 1D: " + str(anim_info.blend_1d).pad_decimals(2) + "\n"
			debug_text += "Is 1D Mode: " + str(anim_info.is_1d_mode) + "\n"
		
		# === CAMERA INFO ===
		var camera_rig = get_node("../CAMERARIG")
		if camera_rig:
			var cam_info = camera_rig.get_camera_debug_info()
			debug_text += "\n=== CAMERA ===\n"
			debug_text += "Follow Mode: " + cam_info.follow_mode + "\n"
			debug_text += "Is Following: " + str(cam_info.is_following) + "\n"
			debug_text += "Mouse Captured: " + str(cam_info.mouse_captured) + "\n"
			debug_text += "Distance: " + str(cam_info.current_distance).pad_decimals(1) + "\n"
		
		# === SETTINGS ===
		debug_text += "\n=== SETTINGS ===\n"
		debug_text += "Floor Max Angle: " + str(rad_to_deg(character.floor_max_angle)).pad_decimals(1) + "°\n"
		debug_text += "Floor Snap Length: " + str(character.floor_snap_length) + "\n"
		debug_text += "Min Input Duration: " + str(character.min_input_duration) + "s\n"
		
		debug_label.text = debug_text
