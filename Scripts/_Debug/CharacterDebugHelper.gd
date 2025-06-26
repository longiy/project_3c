# CharacterDebugHelper.gd - Fixed for pure signal-driven animation system
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
		"actions": get_action_debug_info()
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
	"""Get PURE signal-driven animation system debug info"""
	if character.animation_controller:
		var anim_debug = character.animation_controller.get_debug_info()
		
		# Add signal-based specific information
		anim_debug["system_type"] = "Pure Signal-Driven"
		anim_debug["sync_status"] = get_animation_sync_status()
		
		return anim_debug
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
		var action_info = action_system.get_debug_info()
		
		# Add action tracking
		action_info["recent_movement_actions"] = get_recent_movement_actions()
		action_info["recent_camera_actions"] = get_recent_camera_actions()
		action_info["input_to_signal_delay"] = measure_input_signal_delay()
		
		return action_info
	else:
		return {"error": "No ActionSystem"}

# === SIGNAL-DRIVEN ANIMATION HELPERS ===

func get_animation_sync_status() -> String:
	"""Check if animation system is in sync with character state"""
	if not character.animation_controller or not character.state_machine:
		return "Unknown - Missing Components"
	
	var anim_info = character.animation_controller.get_debug_info()
	var state_info = character.state_machine.get_state_transition_summary()
	
	var anim_active = anim_info.get("is_movement_active", false)
	var char_moving = character.get_movement_speed() > 0.1
	var current_state = state_info.get("current_state", "unknown")
	var is_movement_state = current_state in ["walking", "running"]
	
	if anim_active == is_movement_state:
		return "✅ Synced"
	else:
		return "❌ Desync - Anim:" + str(anim_active) + " State:" + str(is_movement_state)

func get_recent_movement_actions() -> Array[String]:
	"""Get recent movement actions"""
	if not action_system:
		return []
	
	var movement_actions: Array[String] = []
	var recent_actions = action_system.executed_actions.slice(-5)
	
	for action in recent_actions:
		if action.is_movement_action():
			movement_actions.append(action.name + "(" + str(action.get_age()).pad_decimals(2) + "s ago)")
	
	return movement_actions

func get_recent_camera_actions() -> Array[String]:
	"""Get recent camera actions"""
	if not action_system:
		return []
	
	var camera_actions: Array[String] = []
	var recent_actions = action_system.executed_actions.slice(-5)
	
	for action in recent_actions:
		if action.is_camera_action():
			camera_actions.append(action.name + "(" + str(action.get_age()).pad_decimals(2) + "s ago)")
	
	return camera_actions

func measure_input_signal_delay() -> String:
	"""Measure delay between input and signal response"""
	if not action_system or action_system.executed_actions.size() < 2:
		return "No data"
	
	var recent_actions = action_system.executed_actions.slice(-10)
	var last_movement_action = null
	
	# Find the most recent movement action
	for i in range(recent_actions.size() - 1, -1, -1):
		var action = recent_actions[i]
		if action.is_movement_action() and last_movement_action == null:
			last_movement_action = action
			break
	
	if last_movement_action:
		var delay = last_movement_action.get_age()
		if delay < 0.001:
			return "✅ Same frame"
		elif delay < 0.02:
			return "⚡ " + str(delay * 1000).pad_decimals(1) + "ms"
		else:
			return "⚠️ " + str(delay * 1000).pad_decimals(1) + "ms"
	
	return "No recent data"

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
		"action_system": action_system != null
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

# === SIGNAL TESTING ===

func test_signal_sync():
	"""Test signal synchronization"""
	print("🧪 Testing signal sync...")
	
	# Test immediate response
	if character.has_signal("movement_state_changed"):
		character.movement_state_changed.emit(true, Vector2(1, 0), 1.0)
		await get_tree().process_frame
		
		var sync_status = get_animation_sync_status()
		print("🎬 Signal sync test: ", sync_status)
	else:
		print("❌ Character missing movement_state_changed signal")

func print_signal_summary():
	"""Print summary of signal-animation relationship"""
	print("=== SIGNAL-ANIMATION SUMMARY ===")
	print("Recent Movement Actions: ", get_recent_movement_actions())
	print("Recent Camera Actions: ", get_recent_camera_actions())
	print("Input→Signal Delay: ", measure_input_signal_delay())
	print("Sync Status: ", get_animation_sync_status())
