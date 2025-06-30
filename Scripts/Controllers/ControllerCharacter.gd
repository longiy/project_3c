# ControllerCharacter.gd - UPDATED: Bridge new Control system with existing Character modules
extends CharacterBody3D

@export_group("Physics")
@export var gravity_multiplier = 1.0

@export_group("Components")
@export var animation_controller: AnimationManager
@export var camera: Camera3D
@export var input_controller: InputController  # UPDATED: Changed from input_manager
@export var jump_system: JumpSystem
@export var debug_helper: CharacterDebugHelper

# === SIGNALS ===
signal ground_state_changed(is_grounded: bool)
signal jump_performed(jump_force: float, is_air_jump: bool)

# === COMPONENTS ===
var state_machine: CharacterStateMachine
var movement_manager: MovementManager

# === STATE ===
var last_emitted_grounded: bool = true
var base_gravity: float

func _ready():
	setup_character()
	setup_components()
	connect_signals()

func setup_character():
	base_gravity = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	if base_gravity <= 0:
		base_gravity = 9.8
	
	last_emitted_grounded = is_on_floor()

func setup_components():
	# Get required components
	state_machine = get_node("CharacterStateMachine") as CharacterStateMachine
	if not state_machine:
		push_error("No CharacterStateMachine found!")
		return
	
	# Get or create movement manager
	movement_manager = get_node_or_null("MovementManager")
	if not movement_manager:
		movement_manager = MovementManager.new()
		movement_manager.name = "MovementManager"
		add_child(movement_manager)
	
	# UPDATED: Get InputController instead of InputManager
	if not input_controller:
		input_controller = get_node_or_null("InputController") as InputController
		if not input_controller:
			push_error("No InputController found!")
			return
	
	# Setup camera reference for movement
	if camera and movement_manager:
		movement_manager.setup_camera_reference(camera)

func connect_signals():
	"""UPDATED: Connect new InputController signals to existing systems"""
	if not input_controller or not movement_manager:
		push_error("Missing InputController or MovementManager for signal connections")
		return
	
	# Connect InputController signals to movement manager
	input_controller.movement_started.connect(_on_movement_started)
	input_controller.movement_updated.connect(_on_movement_updated)
	input_controller.movement_stopped.connect(_on_movement_stopped)
	input_controller.sprint_started.connect(_on_sprint_started)
	input_controller.sprint_stopped.connect(_on_sprint_stopped)
	input_controller.slow_walk_started.connect(_on_slow_walk_started)
	input_controller.slow_walk_stopped.connect(_on_slow_walk_stopped)
	input_controller.jump_pressed.connect(_on_jump_pressed)
	input_controller.reset_pressed.connect(_on_reset_pressed)
	
	# Connect movement manager to animation controller
	if animation_controller and movement_manager:
		movement_manager.movement_changed.connect(animation_controller._on_movement_changed)
		movement_manager.mode_changed.connect(animation_controller._on_mode_changed)
		print("✅ ControllerCharacter: Connected movement to animation")
	
	print("✅ ControllerCharacter: All signal connections established")

func _physics_process(delta):
	if state_machine:
		state_machine.update(delta)
	
	emit_ground_state_changes()

# === SIGNAL HANDLERS (Updated for new InputController) ===

func _on_movement_started(direction: Vector2, magnitude: float):
	"""Handle movement start from InputController"""
	if movement_manager:
		movement_manager.handle_movement_action("move_start", {"direction": direction, "magnitude": magnitude})

func _on_movement_updated(direction: Vector2, magnitude: float):
	"""Handle movement update from InputController"""
	if movement_manager:
		movement_manager.handle_movement_action("move_update", {"direction": direction, "magnitude": magnitude})

func _on_movement_stopped():
	"""Handle movement stop from InputController"""
	if movement_manager:
		movement_manager.handle_movement_action("move_end")

func _on_sprint_started():
	"""Handle sprint start from InputController"""
	if movement_manager:
		movement_manager.handle_mode_action("sprint_start")

func _on_sprint_stopped():
	"""Handle sprint stop from InputController"""
	if movement_manager:
		movement_manager.handle_mode_action("sprint_end")

func _on_slow_walk_started():
	"""Handle slow walk start from InputController"""
	if movement_manager:
		movement_manager.handle_mode_action("slow_walk_start")

func _on_slow_walk_stopped():
	"""Handle slow walk stop from InputController"""
	if movement_manager:
		movement_manager.handle_mode_action("slow_walk_end")

func _on_jump_pressed():
	"""Handle jump input from InputController"""
	if not jump_system:
		return
	
	# Let JumpSystem decide what type of jump to perform
	if jump_system.can_jump_at_all():
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
	"""Handle reset input from InputController"""
	reset_character()

# === MOVEMENT INTERFACE (Unchanged) ===

func apply_ground_movement(delta: float):
	if movement_manager:
		movement_manager.apply_ground_movement(delta)

func apply_air_movement(delta: float):
	if movement_manager:
		movement_manager.apply_air_movement(delta)

func get_movement_speed() -> float:
	return movement_manager.get_movement_speed() if movement_manager else 0.0

func get_target_state() -> String:
	return movement_manager.get_target_state() if movement_manager else "idle"

func apply_gravity(delta: float):
	if not is_on_floor():
		velocity.y -= base_gravity * gravity_multiplier * delta

# === GROUND STATE DETECTION (Unchanged) ===

func emit_ground_state_changes():
	"""Emit ground state changes for JumpSystem"""
	var current_grounded = is_on_floor()
	if current_grounded != last_emitted_grounded:
		last_emitted_grounded = current_grounded
		ground_state_changed.emit(current_grounded)

func update_ground_state():
	"""Manual ground state update for compatibility"""
	if jump_system:
		jump_system.update_ground_state()

# === JUMP INTERFACE (Unchanged) ===

func can_jump() -> bool:
	return jump_system.can_jump() if jump_system else false

func can_air_jump() -> bool:
	return jump_system.can_air_jump() if jump_system else false

# === CHARACTER MANAGEMENT (Unchanged) ===

func reset_character():
	"""Reset character to spawn position"""
	global_position = Vector3.ZERO
	velocity = Vector3.ZERO
	
	if jump_system:
		jump_system.reset_jump_state()
	
	if state_machine:
		state_machine.change_state("idle")
	
	print("🔄 Character reset")

# === DEBUG INFO (Updated for InputController) ===

func get_debug_info() -> Dictionary:
	"""Get character debug information"""
	var info = {
		"character": {
			"position": global_position,
			"velocity": velocity,
			"is_grounded": is_on_floor(),
			"movement_speed": get_movement_speed(),
			"target_state": get_target_state(),
			"is_running": movement_manager.is_running if movement_manager else false,
			"is_slow_walking": movement_manager.is_slow_walking if movement_manager else false
		}
	}
	
	# Add component debug info
	if input_controller:
		info["input"] = input_controller.get_debug_info()
	
	if movement_manager:
		info["movement"] = movement_manager.get_debug_info() if movement_manager.has_method("get_debug_info") else {"error": "No debug method"}
	
	if jump_system:
		info["jump"] = jump_system.get_debug_info()
	
	if state_machine:
		info["state"] = {
			"current_state": state_machine.current_state.state_name if state_machine.current_state else "none",
			"previous_state": state_machine.previous_state.state_name if state_machine.previous_state else "none",
			"transition_count": state_machine.transition_count
		}
	
	return info
