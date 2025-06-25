# StateIdle.gd - Action-based idle state
class_name StateIdle
extends CharacterStateBase

func enter():
	super.enter()
	character.update_ground_state()

func update(delta: float):
	super.update(delta)
	
	character.apply_gravity(delta)
	
	# Apply deceleration if no movement action is active
	if not is_movement_active:
		character.apply_deceleration(delta)
	
	character.move_and_slide()
	check_transitions()

# === MOVEMENT ACTION OVERRIDES ===

func on_movement_started(direction: Vector2, magnitude: float):
	"""When movement starts in idle, transition to appropriate movement state"""
	print("💤 Movement started in idle: ", direction, " - transitioning to walking")
	change_to("walking")

func on_movement_updated(direction: Vector2, magnitude: float):
	"""Movement updates in idle should trigger transition"""
	check_movement_transition()

func on_movement_ended():
	"""Movement ended - stay in idle"""
	pass

func check_movement_transition():
	"""Check if we should transition to a movement state"""
	if is_movement_active and current_movement_vector.length() > 0:
		var target_speed = character.get_target_speed()
		
		if character.is_running:
			change_to("running")
		elif target_speed <= character.slow_walk_speed:
			change_to("walking")
		else:
			change_to("walking")

func check_transitions():
	"""Check for state transitions"""
	if not character.is_on_floor():
		change_to("airborne")

# === ACTION SYSTEM INTERFACE ===

func can_execute_action(action: Action) -> bool:
	"""Define what actions can be executed while idle"""
	match action.name:
		"jump":
			return character.can_jump()
		"move_start", "move_update":
			return true  # Can start movement from idle
		"move_end":
			return true  # Can end movement (though shouldn't happen)
		"sprint_start", "sprint_end", "slow_walk_start", "slow_walk_end":
			return true  # Movement modes always available
		"look_delta":
			return true  # Can look around while idle
		"reset":
			return true
		_:
			return super.can_execute_action(action)

func execute_action(action: Action):
	"""Execute actions while idle"""
	match action.name:
		"jump":
			character.perform_jump(character.jump_system.get_jump_force())
			change_to("jumping")
		
		"move_start", "move_update":
			# Use the helper to transition and forward the action
			transition_and_forward_action("walking", action)
		
		"move_end":
			super.execute_action(action)
			# Stay in idle when movement ends
		
		_:
			super.execute_action(action)
