# CCC_CharacterController.gd - Phase 1: Main Character Controller
extends CharacterBody3D

@export_group("Physics")
@export var gravity_multiplier = 1.0

@export_group("Components")
@export var animation_controller: AnimationManager
@export var camera: Camera3D
@export var debug_helper: CharacterDebugHelper

# === CCC MANAGERS ===
var control_manager: CCC_ControlManager
var character_manager: CCC_CharacterManager
var camera_manager: CCC_CameraManager

# === LEGACY COMPONENTS (for fallback) ===
var input_manager: InputManager
var movement_manager: MovementManager

# === CORE COMPONENTS ===
var state_machine: CharacterStateMachine
var jump_system: JumpSystem

# === SIGNALS ===
signal ground_state_changed(is_grounded: bool)
signal jump_performed(jump_force: float, is_air_jump: bool)

# === STATE ===
var last_emitted_grounded: bool = true
var base_gravity: float
var using_ccc_architecture: bool = false

func _ready():
	setup_character()
	detect_ccc_architecture()
	setup_components()
	connect_signals()

func setup_character():
	"""Setup basic character properties"""
	base_gravity = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	if base_gravity <= 0:
		base_gravity = 9.8
	
	last_emitted_grounded = is_on_floor()

func detect_ccc_architecture():
	"""Detect if CCC managers are present"""
	control_manager = get_node_or_null("CCC_ControlManager")
	character_manager = get_node_or_null("CCC_CharacterManager")
	camera_manager = get_node_or_null("CCC_CameraManager")
	
	using_ccc_architecture = (control_manager != null and character_manager != null)
	
	if using_ccc_architecture:
		print("✅ CCC_CharacterController: Using CCC Architecture")
	else:
		print("⚠️ CCC_CharacterController: Falling back to legacy architecture")

func setup_components():
	"""Setup component references"""
	# Get required components
	state_machine = get_node("CharacterStateMachine") as CharacterStateMachine
	jump_system = get_node_or_null("JumpSystem") as JumpSystem
	
	if not state_machine:
		push_error("No CharacterStateMachine found!")
		return
	
	if using_ccc_architecture:
		setup_ccc_components()
	else:
		setup_legacy_components()

func setup_ccc_components():
	"""Setup CCC architecture components"""
	print("🔗 CCC_CharacterController: Setting up CCC components")
	
	# Character manager handles movement now
	# No need to create separate MovementManager
	
	# Setup camera reference for movement calculations
	var camera_ref = get_camera_reference()
	if camera_ref and character_manager and character_manager.movement_system:
		character_manager.movement_system.setup_camera_reference(camera_ref)

func setup_legacy_components():
	"""Setup legacy architecture components"""
	print("🔗 CCC_CharacterController: Setting up legacy components")
	
	# Get or create movement manager
	movement_manager = get_node_or_null("MovementManager")
	if not movement_manager:
		movement_manager = MovementManager.new()
		movement_manager.name = "MovementManager"
		add_child(movement_manager)
	
	# Get input manager
	input_manager = get_node_or_null("InputManager")
	
	# Setup camera reference
	var camera_ref = get_camera_reference()
	if camera_ref and movement_manager:
		movement_manager.setup_camera_reference(camera_ref)

func connect_signals():
	"""Connect signals based on architecture"""
	if using_ccc_architecture:
		connect_ccc_signals()
	else:
		connect_legacy_signals()

func connect_ccc_signals():
	"""Connect signals through CCC managers"""
	print("🔗 CCC_CharacterController: Connecting CCC signals")
	
	# Connect control manager to character manager
	if control_manager and character_manager:
		control_manager.movement_command.connect(character_manager.handle_movement_command)
		control_manager.jump_command.connect(character_manager.handle_jump_command)
		control_manager.sprint_command.connect(character_manager.handle_sprint_command)
	
	# Connect character manager to animation controller
	if character_manager and animation_controller:
		# MovementSystem signals get connected automatically by CCC_CharacterManager
		pass
	
	# Connect jump system if present (check for signal existence first)
	if jump_system and jump_system.has_signal("jump_performed"):
		jump_system.jump_performed.connect(_on_jump_performed)
	elif jump_system:
		print("⚠️ CCC_CharacterController: JumpSystem found but missing jump_performed signal")

func connect_legacy_signals():
	"""Connect legacy signals"""
	print("🔗 CCC_CharacterController: Connecting legacy signals")
	
	if not input_manager or not movement_manager:
		return
	
	# Connect input signals to movement manager
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
	"""Physics processing"""
	if state_machine:
		state_machine.update(delta)
	
	emit_ground_state_changes()

func get_camera_reference() -> Camera3D:
	"""Get camera reference"""
	if camera:
		return camera
	
	# Try to find camera in typical locations
	var camera_rig = get_node_or_null("../CAMERARIG")
	if camera_rig:
		var spring_arm = camera_rig.get_node_or_null("SpringArm3D")
		if spring_arm:
			return spring_arm.get_node_or_null("Camera3D") as Camera3D
	
	return null

# === CCC SIGNAL HANDLERS ===

# CCC signals are connected directly between managers
# Character controller just needs to handle ground state and jump events

# === LEGACY SIGNAL HANDLERS ===

func _on_movement_started(direction: Vector2, magnitude: float):
	"""Legacy: Handle movement started"""
	if movement_manager:
		movement_manager.handle_movement_action("move_start", {"direction": direction, "magnitude": magnitude})

func _on_movement_updated(direction: Vector2, magnitude: float):
	"""Legacy: Handle movement updated"""
	if movement_manager:
		movement_manager.handle_movement_action("move_update", {"direction": direction, "magnitude": magnitude})

func _on_movement_stopped():
	"""Legacy: Handle movement stopped"""
	if movement_manager:
		movement_manager.handle_movement_action("move_end")

func _on_sprint_started():
	"""Legacy: Handle sprint started"""
	if movement_manager:
		movement_manager.handle_mode_action("sprint_start")

func _on_sprint_stopped():
	"""Legacy: Handle sprint stopped"""
	if movement_manager:
		movement_manager.handle_mode_action("sprint_end")

func _on_slow_walk_started():
	"""Legacy: Handle slow walk started"""
	if movement_manager:
		movement_manager.handle_mode_action("slow_walk_start")

func _on_slow_walk_stopped():
	"""Legacy: Handle slow walk stopped"""
	if movement_manager:
		movement_manager.handle_mode_action("slow_walk_end")

func _on_jump_pressed():
	"""Handle jump pressed (both CCC and legacy)"""
	if jump_system:
		jump_system.attempt_jump()

func _on_reset_pressed():
	"""Handle reset pressed"""
	global_position = Vector3.ZERO
	velocity = Vector3.ZERO

func _on_jump_performed(jump_force: float, is_air_jump: bool):
	"""Handle jump performed"""
	jump_performed.emit(jump_force, is_air_jump)

# === UTILITY METHODS ===

func emit_ground_state_changes():
	"""Emit ground state changes"""
	var current_grounded = is_on_floor()
	if current_grounded != last_emitted_grounded:
		last_emitted_grounded = current_grounded
		ground_state_changed.emit(current_grounded)
		
		# Update jump system
		if jump_system:
			jump_system.update_ground_state()

# === LEGACY COMPATIBILITY METHODS ===

func update_ground_state():
	"""Legacy compatibility: Update ground state (delegates to jump system)"""
	if jump_system:
		jump_system.update_ground_state()

func apply_gravity(delta: float):
	"""Legacy compatibility: Apply gravity"""
	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity", 9.8) * gravity_multiplier * delta

func apply_ground_movement(delta: float):
	"""Legacy compatibility: Apply ground movement"""
	if using_ccc_architecture and character_manager and character_manager.movement_system:
		character_manager.movement_system.apply_movement_physics(delta)
	elif movement_manager:
		movement_manager.apply_ground_movement(delta)

func apply_air_movement(delta: float):
	"""Legacy compatibility: Apply air movement"""
	if using_ccc_architecture and character_manager and character_manager.movement_system:
		character_manager.movement_system.apply_movement_physics(delta)
	elif movement_manager:
		movement_manager.apply_air_movement(delta)

func can_jump() -> bool:
	"""Legacy compatibility: Check if can jump"""
	if jump_system:
		return jump_system.can_jump()
	return false

func can_air_jump() -> bool:
	"""Legacy compatibility: Check if can air jump"""
	if jump_system:
		return jump_system.can_air_jump()
	return false

func is_movement_active() -> bool:
	"""Check if movement is currently active"""
	if using_ccc_architecture and character_manager:
		return character_manager.is_movement_active()
	elif movement_manager:
		return movement_manager.is_movement_active
	return false

func is_running() -> bool:
	"""Check if character is running"""
	if using_ccc_architecture and character_manager:
		return character_manager.is_running()
	elif movement_manager:
		return movement_manager.is_running
	return false

func get_movement_speed() -> float:
	"""Get current movement speed"""
	if using_ccc_architecture and character_manager:
		return character_manager.get_movement_speed()
	elif movement_manager:
		return movement_manager.get_movement_speed()
	return 0.0

func get_current_input_direction() -> Vector2:
	"""Get current input direction"""
	if using_ccc_architecture and character_manager:
		return character_manager.get_current_input_direction()
	elif movement_manager:
		return movement_manager.current_input_direction
	return Vector2.ZERO

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get comprehensive debug information"""
	var debug_data = {
		"architecture": "CCC" if using_ccc_architecture else "Legacy",
		"is_grounded": is_on_floor(),
		"velocity": velocity,
		"gravity_multiplier": gravity_multiplier
	}
	
	if using_ccc_architecture:
		if control_manager:
			debug_data["control_manager"] = control_manager.get_debug_info()
		if character_manager:
			debug_data["character_manager"] = character_manager.get_debug_info()
	else:
		debug_data["movement_active"] = is_movement_active()
		debug_data["is_running"] = is_running()
		debug_data["movement_speed"] = get_movement_speed()
		debug_data["input_direction"] = get_current_input_direction()
	
	return debug_data
