# StunnedState.gd - Template for status effect state
extends StateBaseMovement
class_name StateStunned

var stun_duration = 2.0
var stun_timer = 0.0

func enter():
	super.enter()
	stun_timer = 0.0
	
	# Stop all movement
	character.velocity.x = 0
	character.velocity.z = 0
	
	# Play stun animation
	if character.animation_controller:
		character.animation_controller.play_stun()
	
	print("  😵 Character stunned for ", stun_duration, "s")

func update(delta: float):
	super.update(delta)
	stun_timer += delta
	
	# Apply gravity but no movement control
	apply_gravity(delta)
	character.move_and_slide()
	
	# Recover from stun
	if stun_timer >= stun_duration:
		if character.is_on_floor():
			change_to("grounded")
		else:
			change_to("airborne")

func handle_input(event: InputEvent):
	# Ignore all input while stunned
	pass

func exit():
	super.exit()
	print("  😵 Recovered from stun")
