# CCC_CharacterController.gd - CCC Architecture Coordinator (Renamed from ControllerCharacter)
extends CharacterBody3D
class_name CCC_CharacterController

# === CCC MANAGERS ===
@export_group("CCC Managers")
@export var control_manager: CCC_ControlManager
@export var character_manager: CCC_CharacterManager
@export var camera_manager: CCC_CameraManager

# === EXISTING COMPONENTS (Backward compatibility) ===
@export_group("Legacy Components")
@export var animation_controller: AnimationManager
@export var input_manager: InputManager  # Still accessible for migration
@export var jump_system: JumpSystem
@export var debug_helper: CharacterDebugHelper

# === PHYSICS ===
@export_group("Physics")
@export var gravity_multiplier = 1.0

# === SIGNALS (Keep existing for backward compatibility) ===
signal ground_state_changed(is_grounded: bool)
signal jump_performed(jump_force: float, is_air_jump: bool)

# === INTERNAL COMPONENTS (Keep existing functionality) ===
var state_machine: CharacterStateMachine
var movement_manager: MovementManager  # Referenced by character_manager

# === STATE ===
var last_emitted_grounded: bool = true
var base_gravity: float

# === CCC STATUS ===
var ccc_architecture_active: bool = false

func _ready():
	setup_character()
	setup_CCC_managers()
	setup_legacy_components()
	connect_signals()
	print("✅ CCC_CharacterController: CCC Architecture initialized")

 # Add validation
	call_deferred("validate_and_debug")

func validate_and_debug():
	print("\n=== CCC VALIDATION ===")
	print("3C Active: ", is_ccc_architecture_active())
	validate_ccc_setup()
	print("\n=== DEBUG INFO ===")
	var debug_info = get_debug_info()
	for key in debug_info:
		print(key, ": ", debug_info[key])
		print("========================\n")

func setup_character():
	"""Setup basic character properties"""
	base_gravity = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	if base_gravity <= 0:
		base_gravity = 9.8
	
	last_emitted_grounded = is_on_floor()

func setup_CCC_managers():
	"""Setup and validate CCC managers"""
	var managers_found = 0
	
	# Find or create CCC managers
	if not control_manager:
		control_manager = get_node_or_null("CCC_ControlManager")
	if control_manager:
		managers_found += 1
	
	if not character_manager:
		character_manager = get_node_or_null("CCC_CharacterManager")
	if character_manager:
		managers_found += 1
	
	if not camera_manager:
		camera_manager = get_node_or_null("CCC_CameraManager")
	if camera_manager:
		managers_found += 1
	
	# Check if CCC architecture is active
	if managers_found == 3:
		ccc_architecture_active = true
		print("🎯 CCC_CharacterController: Full CCC architecture active")
	elif managers_found > 0:
		ccc_architecture_active = false
		print("⚠️ CCC_CharacterController: Partial CCC setup - ", managers_found, "/3 managers found")
	else:
		ccc_architecture_active = false
		print("📦 CCC_CharacterController: Legacy mode - no CCC managers found")

func setup_legacy_components():
	"""Setup existing components (backward compatibility)"""
	# Get required components
	state_machine = get_node("CharacterStateMachine") as CharacterStateMachine
	if not state_machine:
		push_error("No CharacterStateMachine found!")
		return
	
	# Create or get movement manager
	movement_manager = get_node_or_null("MovementManager")
	if not movement_manager:
		movement_manager = MovementManager.new()
		movement_manager.name = "MovementManager"
		add_child(movement_manager)
	
	# Setup camera reference for movement calculations
	var camera = get_camera_reference()
	if camera and movement_manager:
		movement_manager.setup_camera_reference(camera)

func connect_signals():
	"""Connect signals - use CCC managers if available, fallback to legacy"""
	if ccc_architecture_active:
		connect_CCC_signals()
	else:
		connect_legacy_signals()

func connect_CCC_signals():
	"""Connect signals through CCC managers"""
	print("🔗 CCC_CharacterController: Connecting CCC signals")
	
	# Connect control manager signals
	if control_manager:
		control_manager.movement_started.connect(_on_movement_started)
		control_manager.movement_updated.connect(_on_movement_updated)
		control_manager.movement_stopped.connect(_on_movement_stopped)
		control_manager.jump_pressed.connect(_on_jump_pressed)
		control_manager.sprint_started.connect(_on_sprint_started)
		control_manager.sprint_stopped.connect(_on_sprint_stopped)
		control_manager.slow_walk_started.connect(_on_slow_walk_started)
		control_manager.slow_walk_stopped.connect(_on_slow_walk_stopped)
		control_manager.reset_pressed.connect(_on_reset_pressed)
	
	# Connect character manager to animation controller
	if character_manager and animation_controller:
		character_manager.movement_changed.connect(animation_controller._on_movement_changed)
		character_manager.mode_changed.connect(animation_controller._on_mode_changed)

func connect_legacy_signals():
	"""Connect signals directly to legacy components"""
	print("🔗 CCC_CharacterController: Connecting legacy signals")
	
	if not input_manager or not movement_manager:
		return
	
	# Connect input signals to movement manager (legacy path)
	input_manager.movement_started.connect(_on_movement_started)
	input_manager.movement_updated.connect(_on_movement_updated)
	input_manager.movement_stopped.connect(_on_movement_stopped)
	input_manager.sprint_started.connect(_on_sprint_started)
	input_manager.sprint_stopped.connect(_on_sprint_stopped)
	input_manager.slow_walk_started.connect(_on_slow_walk_started)
	input_manager.slow_walk_stopped.connect(_on_slow_walk_stopped)
	input_manager.jump_pressed.connect(_on_jump_pressed)
	input_manager.reset_pressed.connect(_on_reset_pressed)
	
	# Connect movement manager to animation controller
	if animation_controller:
		movement_manager.movement_changed.connect(animation_controller._on_movement_changed)
		movement_manager.mode_changed.connect(animation_controller._on_mode_changed)

func _physics_process(delta):
	if state_machine:
		state_machine.update(delta)
	
	emit_ground_state_changes()

# === SIGNAL HANDLERS (Work with both CCC and legacy) ===

func _on_movement_started(direction: Vector2, magnitude: float):
	if ccc_architecture_active and character_manager:
		character_manager.handle_movement_action("move_start", {"direction": direction, "magnitude": magnitude})
	elif movement_manager:
		movement_manager.handle_movement_action("move_start", {"direction": direction, "magnitude": magnitude})

func _on_movement_updated(direction: Vector2, magnitude: float):
	if ccc_architecture_active and character_manager:
		character_manager.handle_movement_action("move_update", {"direction": direction, "magnitude": magnitude})
	elif movement_manager:
		movement_manager.handle_movement_action("move_update", {"direction": direction, "magnitude": magnitude})

func _on_movement_stopped():
	if ccc_architecture_active and character_manager:
		character_manager.handle_movement_action("move_end")
	elif movement_manager:
		movement_manager.handle_movement_action("move_end")

func _on_sprint_started():
	if ccc_architecture_active and character_manager:
		character_manager.handle_mode_action("sprint_start")
	elif movement_manager:
		movement_manager.handle_mode_action("sprint_start")

func _on_sprint_stopped():
	if ccc_architecture_active and character_manager:
		character_manager.handle_mode_action("sprint_end")
	elif movement_manager:
		movement_manager.handle_mode_action("sprint_end")

func _on_slow_walk_started():
	if ccc_architecture_active and character_manager:
		character_manager.handle_mode_action("slow_walk_start")
	elif movement_manager:
		movement_manager.handle_mode_action("slow_walk_start")

func _on_slow_walk_stopped():
	if ccc_architecture_active and character_manager:
		character_manager.handle_mode_action("slow_walk_end")
	elif movement_manager:
		movement_manager.handle_mode_action("slow_walk_end")

func _on_jump_pressed():
	"""Handle jump input (works with both CCC and legacy)"""
	if not jump_system:
		return
	
	# Let JumpSystem decide what type of jump to perform
	if jump_system.can_jump_at_all():
		# JumpSystem will automatically determine jump type and force
		jump_system.perform_jump()
		
		# Transition to jumping state
		if state_machine:
			state_machine.change_state("jumping")
		
		# Debug logging (optional)
		if jump_system.enable_debug_logging:
			var jump_type = "ground/coyote" if jump_system.can_jump() else "air"
			print("🎮 Performed ", jump_type, " jump")
	else:
		# Debug logging (optional)
		if jump_system.enable_debug_logging:
			print("❌ No jumps available - Ground: ", jump_system.has_ground_jump, 
				  " Air: ", jump_system.air_jumps_remaining, 
				  " Coyote: ", jump_system.coyote_timer)

func _on_reset_pressed():
	reset_character()

# === MOVEMENT INTERFACE (Supports both CCC and legacy) ===

func apply_ground_movement(delta: float):
	if ccc_architecture_active and character_manager:
		character_manager.apply_ground_movement(delta)
	elif movement_manager:
		movement_manager.apply_ground_movement(delta)

func apply_air_movement(delta: float):
	if ccc_architecture_active and character_manager:
		character_manager.apply_air_movement(delta)
	elif movement_manager:
		movement_manager.apply_air_movement(delta)

func get_movement_speed() -> float:
	if ccc_architecture_active and character_manager:
		return character_manager.get_movement_speed()
	elif movement_manager:
		return movement_manager.get_movement_speed()
	return 0.0

func get_target_speed() -> float:
	if ccc_architecture_active and character_manager:
		return character_manager.get_target_speed()
	elif movement_manager:
		return movement_manager.get_target_speed()
	return 0.0

# === MOVEMENT MODE PROPERTIES ===

var is_running: bool:
	get:
		if ccc_architecture_active and character_manager:
			return character_manager.is_running()
		elif movement_manager:
			return movement_manager.is_running
		return false

var is_slow_walking: bool:
	get:
		if ccc_architecture_active and character_manager:
			return character_manager.is_slow_walking()
		elif movement_manager:
			return movement_manager.is_slow_walking
		return false

# === PHYSICS ===

func apply_gravity(delta: float):
	if not is_on_floor():
		velocity.y -= (base_gravity * gravity_multiplier) * delta

# === JUMP SYSTEM ===

func perform_jump(jump_force: float):
	if jump_system:
		var was_grounded = is_on_floor()
		jump_system.perform_jump(jump_force)
		jump_performed.emit(jump_force, not was_grounded)

func update_ground_state():
	if jump_system:
		jump_system.update_ground_state()

func can_jump() -> bool:
	return jump_system.can_jump() if jump_system else false

func can_air_jump() -> bool:
	return jump_system.can_air_jump() if jump_system else false

# === SIGNAL EMISSION ===

func emit_ground_state_changes():
	var current_grounded = is_on_floor()
	if current_grounded != last_emitted_grounded:
		last_emitted_grounded = current_grounded
		ground_state_changed.emit(current_grounded)

# === STATE QUERIES ===

func should_transition_to_state(current_state: String) -> String:
	if movement_manager:
		return movement_manager.should_transition_to_state(current_state)
	return ""

func get_current_state_name() -> String:
	return state_machine.get_current_state_name() if state_machine else "none"

func get_previous_state_name() -> String:
	return state_machine.get_previous_state_name() if state_machine else "none"

# === CCC CONFIGURATION INTERFACE (Future implementation) ===

func configure_CCC_setup(control_type: String, character_type: String, camera_type: String):
	"""Configure CCC setup (future implementation)"""
	if not ccc_architecture_active:
		print("⚠️ CCC_CharacterController: CCC configuration requested but managers not available")
		return
	
	print("🎯 CCC_CharacterController: Configuring CCC setup...")
	
	# TODO: Implement when adding CCC configuration system
	if control_manager:
		# control_manager.configure_control_type(control_type)
		pass
	
	if character_manager:
		# character_manager.configure_character_type(character_type)
		pass
	
	if camera_manager:
		# camera_manager.configure_camera_type(camera_type)
		pass

func switch_to_preset(preset_name: String):
	"""Switch to a CCC preset configuration (future implementation)"""
	# TODO: Implement preset system
	print("🎮 CCC_CharacterController: Switching to preset: ", preset_name)

# === UTILITY ===

func reset_character():
	if debug_helper:
		debug_helper.reset_character()

func get_camera_reference() -> Camera3D:
	"""Get camera reference from various possible sources"""
	# Try camera manager first
	if camera_manager and camera_manager.camera_controller and camera_manager.camera_controller.camera:
		return camera_manager.camera_controller.camera
	
	# Try finding CAMERARIG
	var camera_rig = get_node_or_null("../CAMERARIG") as CameraController
	if camera_rig and camera_rig.camera:
		return camera_rig.camera
	
	# Try finding camera as a direct child or sibling
	var camera_node = get_node_or_null("Camera3D")
	if camera_node:
		return camera_node as Camera3D
	
	return null

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get comprehensive debug information"""
	var debug_data = {
		"architecture": "CCC (CCC)",
		"ccc_active": ccc_architecture_active,
		"current_state": get_current_state_name(),
		"is_grounded": is_on_floor(),
		"velocity": velocity,
		"position": global_position
	}
	
	# Add CCC manager debug info
	if ccc_architecture_active:
		if control_manager:
			debug_data["control"] = control_manager.get_debug_info()
		if character_manager:
			debug_data["character"] = character_manager.get_debug_info()
		if camera_manager:
			debug_data["camera"] = camera_manager.get_debug_info()
	else:
		# Legacy debug info
		if debug_helper:
			debug_data.merge(debug_helper.get_comprehensive_debug_info())
		else:
			debug_data.merge({
				"movement_speed": get_movement_speed(),
				"is_running": is_running,
				"is_slow_walking": is_slow_walking
			})
	
	return debug_data

# === MIGRATION HELPERS ===

func is_ccc_architecture_active() -> bool:
	"""Check if CCC architecture is active"""
	return ccc_architecture_active

func get_ccc_managers() -> Dictionary:
	"""Get all CCC managers for external access"""
	return {
		"control": control_manager,
		"character": character_manager,
		"camera": camera_manager
	}

func validate_ccc_setup() -> bool:
	"""Validate that CCC setup is complete and working"""
	if not ccc_architecture_active:
		return false
	
	var issues = []
	
	if not control_manager:
		issues.append("Missing CCC_ControlManager")
	elif not control_manager.input_manager:
		issues.append("CCC_ControlManager missing InputManager reference")
	
	if not character_manager:
		issues.append("Missing CCC_CharacterManager")
	elif not character_manager.movement_manager:
		issues.append("CCC_CharacterManager missing MovementManager reference")
	
	if not camera_manager:
		issues.append("Missing CCC_CameraManager")
	elif not camera_manager.camera_controller:
		issues.append("CCC_CameraManager missing CameraController reference")
	
	if issues.size() > 0:
		print("❌ CCC_CharacterController: CCC validation failed:")
		for issue in issues:
			print("  - ", issue)
		return false
	
	print("✅ CCC_CharacterController: CCC validation passed")
	return true
