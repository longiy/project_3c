# CharacterDebugHelper.gd - Updated for action system
extends Node
class_name CharacterDebugHelper

@export_group("Debug Settings")
@export var enable_debug_logging = false
@export var reset_position = Vector3(0, 1, 0)

@export_group("Testing")
@export var enable_force_state_commands = false

# Component references
var character: CharacterBody3D
var action_system: ActionSystem

func _ready():
	character = get_parent() as CharacterBody3D
	if not character:
		push_error("CharacterDebugHelper must be child of CharacterBody3D")
		return
	
	# Get action system
	action_system = character.get_node_or_null("ActionSystem")
	
	if enable_debug_logging:
		print("✅ CharacterDebugHelper: Initialized")

func _input(event):
	"""Handle debug input for testing"""
	if event.is_action_pressed("reset"):
		reset_character()

# === RESET FUNCTIONALITY ===

func reset_character():
	"""Reset character to initial state"""
	if not character:
		return
	
	character.global_position = reset_position
	character.velocity = Vector3.ZERO
	
	# Reset input manager
	if character.input_manager:
		character.input_manager.cancel_all_input_components()
	
	# Reset jump system
	if character.jump_system:
		character.jump_system.reset_jump_state()
	
	# Reset action system
	if action_system:
		action_system.cancel_all_actions()
	
	# Reset state machine
	if character.state_machine:
		character.state_machine.change_state("idle")
	
	if enable_debug_logging:
		print("🔄 Character reset by DebugHelper")

# === DEBUG INFO COMPILATION ===

func get_comprehensive_debug_info() -> Dictionary:
	"""Get comprehensive debug information from all systems"""
	if not character:
		return {"error": "No character reference"}
	
	var debug_info = {
		"character": get_character_debug_info(),
		"input": get_input_debug_info(),
		"jump": get_jump_debug_info(),
		"state": get_state_debug_info(),
		"animation": get_animation_debug_info(),
		"physics": get_physics_debug_info(),
		"actions": get_action_debug_info()  # NEW
	}
	
	return debug_info

func get_character_debug_info() -> Dictionary:
	"""Get core character debug info"""
	return {
		"position": character.global_position,
		"velocity": character.velocity,
		"movement_speed": character.get_movement_speed(),
		"is_grounded": character.is_on_floor(),
		"is_running": character.is_running,
		"is_slow_walking": character.is_slow_walking
	}

func get_input_debug_info() -> Dictionary:
	"""Get input system debug info"""
	if character.input_manager:
		return character.input_manager.get_debug_info()
	else:
		return {"error": "No InputManager"}

func get_jump_debug_info() -> Dictionary:
	"""Get jump system debug info"""
	if character.jump_system:
		return character.jump_system.get_debug_info()
	else:
		return {"error": "No JumpSystem"}

func get_state_debug_info() -> Dictionary:
	"""Get state machine debug info"""
	if character.state_machine:
		return character.state_machine.get_state_transition_summary()
	else:
		return {"error": "No StateMachine"}

func get_animation_debug_info() -> Dictionary:
	"""Get animation system debug info"""
	if character.animation_controller:
		return character.animation_controller.get_debug_info()
	else:
		return {"error": "No AnimationController"}

func get_physics_debug_info() -> Dictionary:
	"""Get physics debug info"""
	return {
		"on_floor": character.is_on_floor(),
		"on_wall": character.is_on_wall(),
		"on_ceiling": character.is_on_ceiling(),
		"floor_normal": character.get_floor_normal() if character.is_on_floor() else Vector3.ZERO,
		"floor_angle": rad_to_deg(character.get_floor_normal().angle_to(Vector3.UP)) if character.is_on_floor() else 0.0
	}

func get_action_debug_info() -> Dictionary:
	"""Get action system debug info"""
	if action_system:
		return action_system.get_debug_info()
	else:
		return {"error": "No ActionSystem"}

# === VALIDATION HELPERS ===

func validate_character_setup() -> Dictionary:
	"""Validate that character components are properly set up"""
	var validation = {
		"character_valid": character != null,
		"input_manager": character.input_manager != null if character else false,
		"jump_system": character.jump_system != null if character else false,
		"state_machine": character.state_machine != null if character else false,
		"animation_controller": character.animation_controller != null if character else false,
		"camera": character.camera != null if character else false,
		"action_system": action_system != null  # NEW
	}
	
	var missing_components = []
	for component in validation:
		if not validation[component]:
			missing_components.append(component)
	
	validation["all_valid"] = missing_components.size() == 0
	validation["missing_components"] = missing_components
	
	return validation

func print_validation_report():
	"""Print a validation report to console"""
	var validation = validate_character_setup()
	
	print("=== CHARACTER VALIDATION REPORT ===")
	
	if validation.all_valid:
		print("✅ All components properly configured")
	else:
		print("❌ Missing components: ", validation.missing_components)
	
	print("📋 Component Status:")
	for component in validation:
		if component != "all_valid" and component != "missing_components":
			var status = "✅" if validation[component] else "❌"
			print("  ", status, " ", component)

# === PERFORMANCE MONITORING ===

func get_performance_info() -> Dictionary:
	"""Get performance information"""
	return {
		"fps": Engine.get_frames_per_second(),
		"frame_time_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000,
		"physics_time_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000,
		"memory_usage_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1024.0 / 1024.0
	}

# === ACTION SYSTEM TESTING ===

func test_action_system():
	"""Test action system with various actions"""
	if not action_system:
		print("❌ No action system to test")
		return
	
	print("🧪 Testing action system...")
	
	# Test jump action
	action_system.request_action("jump")
	await get_tree().create_timer(0.5).timeout
	
	# Test movement mode actions
	action_system.request_action("sprint_start")
	await get_tree().create_timer(1.0).timeout
	action_system.request_action("sprint_end")
	
	print("🧪 Action system test complete")

func force_action(action_name: String, context: Dictionary = {}):
	"""Force an action for testing"""
	if action_system:
		action_system.request_action(action_name, context)
		print("🔧 Debug: Forced action: ", action_name)
	else:
		print("❌ Debug: No action system found")

# Rest of the methods remain the same...
