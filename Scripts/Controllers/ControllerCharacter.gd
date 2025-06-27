# ControllerCharacter.gd - Simplified character controller
extends CharacterBody3D

@export_group("Physics")
@export var gravity_multiplier = 1.0

@export_group("Components")
@export var animation_controller: AnimationController
@export var camera: Camera3D
@export var input_manager: InputManager
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
	
	# Create or get movement manager
	movement_manager = get_node_or_null("MovementManager")
	if not movement_manager:
		movement_manager = MovementManager.new()
		movement_manager.name = "MovementManager"
		add_child(movement_manager)
	
	# Setup camera reference
	if camera:
		movement_manager.setup_camera_reference(camera)

func connect_signals():
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
	if state_machine:
		state_machine.update(delta)
	
	emit_ground_state_changes()

# === SIGNAL HANDLERS ===

func _on_movement_started(direction: Vector2, magnitude: float):
	movement_manager.handle_movement_action("move_start", {"direction": direction, "magnitude": magnitude})

func _on_movement_updated(direction: Vector2, magnitude: float):
	movement_manager.handle_movement_action("move_update", {"direction": direction, "magnitude": magnitude})

func _on_movement_stopped():
	movement_manager.handle_movement_action("move_end")

func _on_sprint_started():
	movement_manager.handle_mode_action("sprint_start")

func _on_sprint_stopped():
	movement_manager.handle_mode_action("sprint_end")

func _on_slow_walk_started():
	movement_manager.handle_mode_action("slow_walk_start")

func _on_slow_walk_stopped():
	movement_manager.handle_mode_action("slow_walk_end")

func _on_jump_pressed():
	"""FIXED: Handle both ground and air jumps properly"""
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


# UPDATED: These methods now delegate to JumpSystem
func can_jump() -> bool:
	return jump_system.can_jump() if jump_system else false

func can_air_jump() -> bool:
	return jump_system.can_air_jump() if jump_system else false

func _on_reset_pressed():
	reset_character()

# === MOVEMENT INTERFACE ===

func apply_ground_movement(delta: float):
	movement_manager.apply_ground_movement(delta)

func apply_air_movement(delta: float):
	movement_manager.apply_air_movement(delta)

func get_movement_speed() -> float:
	return movement_manager.get_movement_speed()

func get_target_speed() -> float:
	return movement_manager.get_target_speed()

# === MOVEMENT MODE PROPERTIES ===

var is_running: bool:
	get:
		return movement_manager.is_running if movement_manager else false

var is_slow_walking: bool:
	get:
		return movement_manager.is_slow_walking if movement_manager else false

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

# === SIGNAL EMISSION ===

func emit_ground_state_changes():
	var current_grounded = is_on_floor()
	if current_grounded != last_emitted_grounded:
		last_emitted_grounded = current_grounded
		ground_state_changed.emit(current_grounded)

# === STATE QUERIES ===

func should_transition_to_state(current_state: String) -> String:
	return movement_manager.should_transition_to_state(current_state) if movement_manager else ""

# === STATE MACHINE INTERFACE ===

func get_current_state_name() -> String:
	return state_machine.get_current_state_name() if state_machine else "none"

func get_previous_state_name() -> String:
	return state_machine.get_previous_state_name() if state_machine else "none"

# === UTILITY ===

func reset_character():
	if debug_helper:
		debug_helper.reset_character()

func get_debug_info() -> Dictionary:
	if debug_helper:
		return debug_helper.get_comprehensive_debug_info()
	else:
		return {
			"current_state": get_current_state_name(),
			"movement_speed": get_movement_speed(),
			"is_grounded": is_on_floor()
		}
