# StateIdle.gd - Fully refactored for modular architecture
extends CharacterStateBase
class_name StateIdle

func enter():
	super.enter()
	# Ensure character is properly grounded when entering idle
	if physics_module:
		physics_module.update_ground_state()

func update(delta: float):
	super.update(delta)
	
	# Apply physics using modules
	if physics_module:
		physics_module.apply_gravity(delta)
	
	if movement_manager:
		movement_manager.apply_ground_movement(delta)
	
	if physics_module:
		physics_module.perform_move_and_slide()
	
	# Check for state transitions
	if check_for_jump_transition():
		return
	
	if check_for_movement_transitions():
		return

func get_debug_info() -> Dictionary:
	var base_info = super.get_debug_info()
	base_info["state_type"] = "idle"
	base_info["waiting_for_input"] = true
	return base_info
