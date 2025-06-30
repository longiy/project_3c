# StateRunning.gd - Refactored for modular architecture
extends CharacterStateBase
class_name StateRunning

func enter():
	super.enter()
	if physics_module:
		physics_module.update_ground_state()

func update(delta: float):
	super.update(delta)
	
	# Apply physics
	apply_gravity(delta)
	apply_ground_movement(delta)
	perform_move_and_slide()
	
	# Check for state transitions
	if check_for_jump_transition():
		return
	
	if not is_grounded():
		change_state("airborne")
		return
	
	# Check movement and running state
	var speed = get_movement_speed()
	if speed <= 0.1:
		change_state("idle")
	elif movement_manager and not movement_manager.is_running:
		change_state("walking")

func get_debug_info() -> Dictionary:
	var base_info = super.get_debug_info()
	base_info["state_type"] = "running"
	base_info["run_speed"] = get_movement_speed()
	base_info["is_running"] = movement_manager.is_running if movement_manager else false
	return base_info
