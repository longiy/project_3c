# AttackingState.gd - Template for future combat system
extends BaseMovementState
class_name AttackingState

var attack_duration = 0.6
var attack_timer = 0.0

func enter():
	super.enter()
	attack_timer = 0.0
	
	# Disable movement during attack
	character.velocity.x = 0
	character.velocity.z = 0
	
	# Play attack animation
	if character.animation_controller:
		character.animation_controller.play_attack()
	
	print("  ⚔️ Started attack")

func update(delta: float):
	super.update(delta)
	attack_timer += delta
	
	# Apply gravity but no movement
	apply_gravity(delta)
	
	# End attack after duration
	if attack_timer >= attack_duration:
		if character.is_on_floor():
			change_to("grounded")
		else:
			change_to("airborne")

func handle_input(event: InputEvent):
	# Ignore movement input during attack
	pass

func exit():
	super.exit()
	print("  ⚔️ Attack finished")
