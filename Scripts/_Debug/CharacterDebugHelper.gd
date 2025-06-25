# CharacterDebugHelper.gd - Debug and testing utilities for character
extends Node
class_name CharacterDebugHelper

@export_group("Debug Settings")
@export var enable_debug_logging = false
@export var reset_position = Vector3(0, 1, 0)

@export_group("Testing")
@export var enable_force_state_commands = false

# Component references
var character: CharacterBody3D

func _ready():
	character = get_parent() as CharacterBody3D
	if not character:
		push_error("CharacterDebugHelper must be child of CharacterBody3D")
		return
	
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
	
	# Reset state machine
	if character.state_machine:
		character.state_machine.change_state("idle")
	
	if enable_debug_logging:
		print("🔄 Character reset by DebugHelper")

# === STATE TESTING ===

func force_state_change(state_name: String):
	"""Force character into specific state (for testing)"""
	if not enable_force_state_commands:
		print("❌ Debug: Force state commands disabled")
		return
	
	if not character.state_machine:
		print("❌ Debug: No state machine found")
		return
	
	if character.state_machine.has_state(state_name):
		character.state_machine.change_state(state_name)
		if enable_debug_logging:
			print("🔧 Debug: Forced state to ", state_name)
	else:
		print("❌ Debug: State not found: ", state_name)

func test_all_states():
	"""Cycle through all states for testing"""
	if not enable_force_state_commands:
		print("❌ Debug: Force state commands disabled")
		return
	
	var states = ["idle", "walking", "running", "jumping", "airborne", "landing"]
	
	print("🧪 Testing all character states...")
	for state in states:
		await character.get_tree().create_timer(1.0).timeout
		force_state_change(state)
		print("🧪 Testing state: ", state)

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
		"physics": get_physics_debug_info()
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

# === VALIDATION HELPERS ===

func validate_character_setup() -> Dictionary:
	"""Validate that character components are properly set up"""
	var validation = {
		"character_valid": character != null,
		"input_manager": character.input_manager != null if character else false,
		"jump_system": character.jump_system != null if character else false,
		"state_machine": character.state_machine != null if character else false,
		"animation_controller": character.animation_controller != null if character else false,
		"camera": character.camera != null if character else false
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

# === DEBUG COMMANDS ===

func enable_debug_mode():
	"""Enable debug logging for all systems"""
	enable_debug_logging = true
	
	if character.jump_system:
		character.jump_system.enable_debug_logging = true
	
	print("🔧 Debug mode enabled")

func disable_debug_mode():
	"""Disable debug logging for all systems"""
	enable_debug_logging = false
	
	if character.jump_system:
		character.jump_system.enable_debug_logging = false
	
	print("🔧 Debug mode disabled")

# === INSPECTOR HELPERS ===

func _get_configuration_warnings() -> PackedStringArray:
	"""Provide warnings in the editor"""
	var warnings = PackedStringArray()
	
	if reset_position == Vector3.ZERO:
		warnings.append("Reset position is at origin (0,0,0) - character may fall through floor")
	
	return warnings
