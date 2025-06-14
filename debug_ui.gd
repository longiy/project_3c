extends Control

@export var debug_label: Label
@export var character: CharacterBody3D

func _process(delta):
	if character and debug_label:
		var debug_text = ""
		
		debug_text += "Jumps Remaining: " + str(character.jumps_remaining) + "/" + str(character.max_jumps) + "\n"
		debug_text += "Coyote Timer: " + str(character.coyote_timer).pad_decimals(2) + "\n"
		
		# Basic properties
		debug_text += "Velocity: " + str(character.velocity.round()) + "\n"
		debug_text += "Speed: " + str(character.velocity.length()).pad_decimals(2) + "\n"
		debug_text += "Up Direction: " + str(character.up_direction) + "\n\n"
		
		# Floor detection
		debug_text += "Is on Floor: " + str(character.is_on_floor()) + "\n"
		debug_text += "Is on Wall: " + str(character.is_on_wall()) + "\n"
		debug_text += "Is on Ceiling: " + str(character.is_on_ceiling()) + "\n\n"
		
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
		
		# Character settings
		debug_text += "\n--- Settings ---\n"
		debug_text += "Floor Max Angle: " + str(rad_to_deg(character.floor_max_angle)).pad_decimals(1) + "°\n"
		debug_text += "Floor Snap Length: " + str(character.floor_snap_length) + "\n"
		
		debug_label.text = debug_text
