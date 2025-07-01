# CharacterDebugHelper.gd - Updated for modular system
extends Node
class_name CharacterDebugHelper

var character: CharacterBody3D

func _ready():
	character = get_parent() as CharacterBody3D
	if not character:
		push_error("CharacterDebugHelper must be child of CharacterBody3D")

# === COMPREHENSIVE DEBUG INFO (UPDATED FOR MODULES) ===

func get_comprehensive_debug_info() -> Dictionary:
	"""Get comprehensive debug info from all systems"""
	var debug_info = {
		"character": get_character_debug_info(),
		"input": get_input_debug_info(),
		"jump": get_jump_debug_info(),
		"state": get_state_debug_info(),
		"animation": get_animation_debug_info(),
		"physics": get_physics_debug_info(),
		"movement": get_movement_debug_info(),
		"performance": get_performance_info()
	}
	
	return debug_info

func get_character_debug_info() -> Dictionary:
	"""Get core character debug info (UPDATED)"""
	return {
		"position": character.global_position,
		"velocity": get_character_velocity(),
		"movement_speed": get_character_movement_speed(),
		"is_grounded": is_character_grounded(),
		"is_running": get_character_running_state(),
		"is_slow_walking": get_character_slow_walking_state()
	}

func get_input_debug_info() -> Dictionary:
	"""Get input system debug info"""
	if character.input_manager:
		return character.input_manager.get_debug_info()
	else:
		return {"error": "No InputManager"}

func get_jump_debug_info() -> Dictionary:
	"""Get jump system debug info (UPDATED FOR MODULES)"""
	# NEW: Check for actions module first
	var actions_module = character.get_node_or_null("CharacterActions")
	if actions_module:
		return actions_module.get_debug_info()
	elif character.jump_system:
		# Fallback to legacy jump system
		return character.jump_system.get_debug_info()
	else:
		return {"error": "No jump system found"}

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
		return {"error": "No AnimationManager"}

func get_physics_debug_info() -> Dictionary:
	"""Get physics debug info (UPDATED FOR MODULES)"""
	# NEW: Check for physics module first
	var physics_module = character.get_node_or_null("CharacterPhysics")
	if physics_module:
		return physics_module.get_debug_info()
	else:
		# Fallback to basic physics info
		return {
			"on_floor": character.is_on_floor(),
			"on_wall": character.is_on_wall(),
			"on_ceiling": character.is_on_ceiling(),
			"velocity": character.velocity,
			"horizontal_speed": Vector2(character.velocity.x, character.velocity.z).length(),
			"vertical_speed": abs(character.velocity.y),
			"floor_normal": character.get_floor_normal() if character.is_on_floor() else Vector3.ZERO,
			"floor_angle": rad_to_deg(character.get_floor_normal().angle_to(Vector3.UP)) if character.is_on_floor() else 0.0,
			"note": "Using fallback physics info - no CharacterPhysics module"
		}

func get_movement_debug_info() -> Dictionary:
	"""Get movement manager debug info"""
	var movement_manager = character.get_node_or_null("MovementManager")
	if movement_manager:
		return movement_manager.get_debug_info()
	else:
		return {"error": "No MovementManager"}

# === UTILITY FUNCTIONS (UPDATED FOR MODULE COMPATIBILITY) ===

func get_character_velocity() -> Vector3:
	"""Get character velocity (module-compatible)"""
	var physics_module = character.get_node_or_null("CharacterPhysics")
	if physics_module:
		return physics_module.get_velocity()
	else:
		return character.velocity

func get_character_movement_speed() -> float:
	"""Get character movement speed (module-compatible)"""
	var movement_manager = character.get_node_or_null("MovementManager")
	if movement_manager:
		return movement_manager.get_movement_speed()
	else:
		return Vector2(character.velocity.x, character.velocity.z).length()

func is_character_grounded() -> bool:
	"""Check if character is grounded (module-compatible)"""
	var physics_module = character.get_node_or_null("CharacterPhysics")
	if physics_module:
		return physics_module.is_grounded()
	else:
		return character.is_on_floor()

func get_character_running_state() -> bool:
	"""Get character running state (module-compatible)"""
	var movement_manager = character.get_node_or_null("MovementManager")
	if movement_manager:
		return movement_manager.is_running
	else:
		return character.is_running if character.has_method("is_running") else false

func get_character_slow_walking_state() -> bool:
	"""Get character slow walking state (module-compatible)"""
	var movement_manager = character.get_node_or_null("MovementManager")
	if movement_manager:
		return movement_manager.is_slow_walking
	else:
		return character.is_slow_walking if character.has_method("is_slow_walking") else false

# === VALIDATION HELPERS (UPDATED) ===

func validate_character_setup() -> Dictionary:
	"""Validate that character components are properly set up (UPDATED)"""
	var validation = {
		"character_valid": character != null,
		"input_manager": character.input_manager != null if character else false,
		"state_machine": character.state_machine != null if character else false,
		"animation_controller": character.animation_controller != null if character else false,
		"camera": character.camera != null if character else false,
		"movement_manager": character.get_node_or_null("MovementManager") != null
	}
	
	# NEW: Check for modular components
	validation["physics_module"] = character.get_node_or_null("CharacterPhysics") != null
	validation["actions_module"] = character.get_node_or_null("CharacterActions") != null
	
	# Legacy components (optional after refactor)
	validation["legacy_jump_system"] = character.jump_system != null if character else false
	
	var missing_components = []
	var optional_components = ["legacy_jump_system"]  # These are optional after refactor
	
	for component in validation:
		if not validation[component] and component not in optional_components:
			missing_components.append(component)
	
	validation["all_valid"] = missing_components.size() == 0
	validation["missing_components"] = missing_components
	validation["module_status"] = get_module_status()
	
	return validation

func get_module_status() -> Dictionary:
	"""Get status of new modular components"""
	return {
		"physics_module_active": character.get_node_or_null("CharacterPhysics") != null,
		"actions_module_active": character.get_node_or_null("CharacterActions") != null,
		"using_legacy_jump": character.jump_system != null,
		"migration_complete": character.get_node_or_null("CharacterPhysics") != null and character.get_node_or_null("CharacterActions") != null
	}

func print_validation_report():
	"""Print a validation report to console (UPDATED)"""
	var validation = validate_character_setup()
	
	print("=== CHARACTER VALIDATION REPORT ===")
	
	if validation.all_valid:
		print("✅ All required components properly configured")
	else:
		print("❌ Missing components: ", validation.missing_components)
	
	print("📋 Component Status:")
	for component in validation:
		if component != "all_valid" and component != "missing_components" and component != "module_status":
			var status = "✅" if validation[component] else "❌"
			print("  ", status, " ", component)
	
	# NEW: Module status report
	print("🔧 Module Status:")
	var module_status = validation.module_status
	for module in module_status:
		var status = "✅" if module_status[module] else "❌"
		print("  ", status, " ", module)

# === PERFORMANCE MONITORING ===

func get_performance_info() -> Dictionary:
	"""Get performance information"""
	return {
		"fps": Engine.get_frames_per_second(),
		"frame_time_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000,
		"physics_time_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000,
		"memory_usage_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1024.0 / 1024.0
	}

# === TESTING HELPERS (UPDATED) ===

func force_state(state_name: String):
	"""Force character into specific state (for testing)"""
	if character.state_machine and character.state_machine.has_state(state_name):
		character.state_machine.change_state(state_name)
		print("🔧 Debug: Forced state to ", state_name)
	else:
		print("❌ Debug: State not found: ", state_name)

func test_movement_modes():
	"""Test different movement modes"""
	var movement_manager = character.get_node_or_null("MovementManager")
	if not movement_manager:
		print("❌ No MovementManager found")
		return
	
	print("🧪 Testing movement modes...")
	
	# Test running
	movement_manager.handle_mode_action("sprint_start")
	await get_tree().create_timer(1.0).timeout
	movement_manager.handle_mode_action("sprint_end")
	
	# Test slow walking
	movement_manager.handle_mode_action("slow_walk_start")
	await get_tree().create_timer(1.0).timeout
	movement_manager.handle_mode_action("slow_walk_end")
	
	print("🧪 Movement mode test complete")

func test_jump_system():
	"""Test jump system (UPDATED FOR MODULES)"""
	print("🧪 Testing jump system...")
	
	# NEW: Test with actions module if available
	var actions_module = character.get_node_or_null("CharacterActions")
	if actions_module:
		print("Testing modular jump system...")
		if actions_module.can_jump_at_all():
			actions_module.perform_jump()
			print("✅ Jump performed via actions module")
		else:
			print("❌ No jumps available via actions module")
	elif character.jump_system:
		print("Testing legacy jump system...")
		if character.jump_system.can_jump_at_all():
			character.jump_system.perform_jump()
			print("✅ Jump performed via legacy system")
		else:
			print("❌ No jumps available via legacy system")
	else:
		print("❌ No jump system found")

func reset_character():
	"""Reset character to initial state (UPDATED FOR MODULES)"""
	print("🔄 Resetting character...")
	
	# Reset modular components if they exist
	var physics_module = character.get_node_or_null("CharacterPhysics")
	if physics_module:
		physics_module.reset_physics()
	
	var actions_module = character.get_node_or_null("CharacterActions")
	if actions_module:
		actions_module.reset_all_actions()
	
	# Reset legacy components
	var movement_manager = character.get_node_or_null("MovementManager")
	if movement_manager:
		movement_manager.reset_movement_state()
	
	if character.jump_system:
		character.jump_system.reset_jump_state()
	
	print("✅ Character reset complete")

func print_movement_summary():
	"""Print summary of movement system"""
	print("=== MOVEMENT SYSTEM SUMMARY ===")
	var movement_info = get_movement_debug_info()
	
	if movement_info.has("error"):
		print("❌ Movement Error: ", movement_info.error)
		return
	
	print("Movement Active: ", movement_info.get("movement_active", false))
	print("Input Direction: ", movement_info.get("input_direction", Vector2.ZERO))
	print("Running: ", movement_info.get("is_running", false))
	print("Slow Walking: ", movement_info.get("is_slow_walking", false))
	print("Current Speed: ", movement_info.get("current_speed", 0.0))
	print("Target State: ", movement_info.get("target_state", "unknown"))
