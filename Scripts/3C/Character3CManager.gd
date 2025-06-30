# Character3CManager.gd - Character Axis with 3C Configuration
extends CharacterBody3D
class_name Character3CManager

# === SIGNALS ===
signal ground_state_changed(is_grounded: bool)
signal jump_performed(jump_force: float, is_air_jump: bool)
signal movement_changed(movement_type: String, direction: Vector2, magnitude: float)
signal mode_changed(new_mode: String)

# === 3C CONFIGURATION ===
@export var active_3c_config: CharacterConfig
@export var available_presets: Array[CharacterConfig] = []

# === COMPONENTS ===
@export_group("Components")
@export var animation_controller: AnimationManager
@export var jump_system: JumpSystem
@export var debug_helper: CharacterDebugHelper

var camera_3c_manager: Camera3CManager
var control_3c_manager: Control3CManager
var state_machine: Node  # Changed from CharacterStateMachine to Node to accept any state machine type

# === MOVEMENT STATE ===
var current_movement_mode: String = "idle"
var movement_direction: Vector2 = Vector2.ZERO
var movement_magnitude: float = 0.0
var is_sprinting: bool = false
var is_slow_walking: bool = false
var target_velocity: Vector3 = Vector3.ZERO
var air_velocity: Vector3 = Vector3.ZERO

# === PHYSICS ===
var base_gravity: float
var last_emitted_grounded: bool = true

func _ready():
	setup_character()
	setup_3c_components()
	setup_state_machine()
	configure_3c_system()

func setup_character():
	base_gravity = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	if base_gravity <= 0:
		base_gravity = 9.8
	
	last_emitted_grounded = is_on_floor()
	
	# Load default config if none provided
	if not active_3c_config:
		# Create default config instead of loading from file
		active_3c_config = CharacterConfig.new()
		active_3c_config.config_name = "Default 3C Config"
		print("✅ Character3CManager: Created default 3C config")

func setup_3c_components():
	# Get or create 3C managers
	camera_3c_manager = get_node_or_null("../CAMERARIG") as Camera3CManager
	if not camera_3c_manager:
		push_warning("No Camera3CManager found - camera integration disabled")
	
	control_3c_manager = get_node_or_null("Control3CManager") as Control3CManager
	if not control_3c_manager:
		# Try to find existing InputManager to replace
		var existing_input = get_node_or_null("InputManager")
		if existing_input:
			print("⚠️ Found old InputManager - please replace with Control3CManager")
		
		control_3c_manager = Control3CManager.new()
		control_3c_manager.name = "Control3CManager"
		add_child(control_3c_manager)
		print("✅ Character3CManager: Created Control3CManager")

func setup_state_machine():
	# Try multiple possible paths for state machine
	var possible_paths = [
		"CharacterStateMachine",
		"CharacterStateMachine3C", 
		"StateMachine",
		"./CharacterStateMachine"
	]
	
	for path in possible_paths:
		state_machine = get_node_or_null(path)
		if state_machine:
			print("✅ Character3CManager: Found state machine at path: ", path)
			break
	
	if not state_machine:
		push_error("No CharacterStateMachine found! Tried paths: " + str(possible_paths))
		return

func configure_3c_system():
	"""Apply 3C configuration to character behavior"""
	if not active_3c_config:
		return
	
	# Configure movement based on character type
	match active_3c_config.character_type:
		CharacterConfig.CharacterType.AVATAR:
			setup_avatar_behavior()
		CharacterConfig.CharacterType.CONTROLLER:
			setup_controller_behavior()
		CharacterConfig.CharacterType.OBSERVER:
			setup_observer_behavior()
		CharacterConfig.CharacterType.COLLABORATOR:
			setup_collaborator_behavior()
	
	# Configure connected systems
	if camera_3c_manager and camera_3c_manager.has_method("configure_from_3c"):
		camera_3c_manager.configure_from_3c(active_3c_config)
	
	if control_3c_manager and control_3c_manager.has_method("configure_from_3c"):
		control_3c_manager.configure_from_3c(active_3c_config)
		connect_control_signals()

func setup_avatar_behavior():
	"""Full embodied character - responsive direct control"""
	# High responsiveness and embodiment
	pass

func setup_controller_behavior():
	"""Character as tool - precise indirect control"""
	# Medium responsiveness, tool-like feel
	pass

func setup_observer_behavior():
	"""Minimal character interaction - mostly watching"""
	# Low responsiveness, camera-focused
	pass

func setup_collaborator_behavior():
	"""Shared control character - adaptive responses"""
	# Variable responsiveness based on context
	pass

func connect_control_signals():
	"""Connect control manager signals"""
	if not control_3c_manager:
		return
	
	# Connect input signals
	if control_3c_manager.has_signal("movement_started"):
		control_3c_manager.movement_started.connect(_on_movement_started)
	if control_3c_manager.has_signal("movement_updated"):
		control_3c_manager.movement_updated.connect(_on_movement_updated)
	if control_3c_manager.has_signal("movement_stopped"):
		control_3c_manager.movement_stopped.connect(_on_movement_stopped)
	if control_3c_manager.has_signal("sprint_started"):
		control_3c_manager.sprint_started.connect(_on_sprint_started)
	if control_3c_manager.has_signal("sprint_stopped"):
		control_3c_manager.sprint_stopped.connect(_on_sprint_stopped)
	if control_3c_manager.has_signal("slow_walk_started"):
		control_3c_manager.slow_walk_started.connect(_on_slow_walk_started)
	if control_3c_manager.has_signal("slow_walk_stopped"):
		control_3c_manager.slow_walk_stopped.connect(_on_slow_walk_stopped)
	if control_3c_manager.has_signal("jump_pressed"):
		control_3c_manager.jump_pressed.connect(_on_jump_pressed)
	if control_3c_manager.has_signal("reset_pressed"):
		control_3c_manager.reset_pressed.connect(_on_reset_pressed)

func _physics_process(delta):
	if state_machine:
		state_machine.update(delta)
	
	emit_ground_state_changes()

# === 3C CONFIGURATION SWITCHING ===

func switch_3c_config(new_config: CharacterConfig):
	"""Runtime 3C configuration switching"""
	active_3c_config = new_config
	configure_3c_system()
	print("Switched to 3C config: ", new_config.config_name)

# === MOVEMENT HANDLING ===

func handle_movement_action(action: String, data: Dictionary = {}):
	"""Process movement actions with 3C configuration"""
	match action:
		"move_start":
			start_movement(data.get("direction", Vector2.ZERO), data.get("magnitude", 0.0))
		"move_update":
			update_movement(data.get("direction", Vector2.ZERO), data.get("magnitude", 0.0))
		"move_stop":
			stop_movement()
		"sprint_start":
			is_sprinting = true
			update_movement_mode()
		"sprint_stop":
			is_sprinting = false
			update_movement_mode()
		"slow_walk_start":
			is_slow_walking = true
			update_movement_mode()
		"slow_walk_stop":
			is_slow_walking = false
			update_movement_mode()

func start_movement(direction: Vector2, magnitude: float):
	movement_direction = direction
	movement_magnitude = magnitude
	update_movement_mode()
	movement_changed.emit(current_movement_mode, direction, magnitude)

func update_movement(direction: Vector2, magnitude: float):
	movement_direction = direction
	movement_magnitude = magnitude
	update_movement_mode()

func stop_movement():
	movement_direction = Vector2.ZERO
	movement_magnitude = 0.0
	update_movement_mode()
	movement_changed.emit(current_movement_mode, Vector2.ZERO, 0.0)

func update_movement_mode():
	"""Determine movement mode based on input and modifiers"""
	var old_mode = current_movement_mode
	
	if movement_magnitude < active_3c_config.input_deadzone:
		current_movement_mode = "idle"
	elif is_sprinting:
		current_movement_mode = "running"
	elif is_slow_walking:
		current_movement_mode = "slow_walking"
	elif movement_magnitude > 0.8:
		current_movement_mode = "running"
	else:
		current_movement_mode = "walking"
	
	if old_mode != current_movement_mode:
		mode_changed.emit(current_movement_mode)

func should_transition_to_state(current_state: String) -> String:
	"""Determine if state machine should transition"""
	if not is_on_floor():
		return ""
	
	match current_movement_mode:
		"idle":
			if current_state != "idle":
				return "idle"
		"walking", "slow_walking":
			if current_state != "walking":
				return "walking"
		"running":
			if current_state != "running":
				return "running"
	
	return ""

# === PHYSICS APPLICATION ===

func apply_ground_movement(delta: float):
	"""Apply movement while grounded with 3C configuration"""
	if not active_3c_config:
		return
	
	var camera_transform = get_camera_transform()
	var movement_3d = get_movement_vector_3d(camera_transform)
	var target_speed = get_target_speed()
	
	target_velocity = movement_3d * target_speed
	
	# Apply acceleration/deceleration
	var acceleration_rate = active_3c_config.acceleration if movement_magnitude > 0 else active_3c_config.deceleration
	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration_rate * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration_rate * delta)
	
	# Apply gravity
	if not is_on_floor():
		velocity.y -= base_gravity * active_3c_config.character_responsiveness * delta
	
	move_and_slide()

func apply_air_movement(delta: float):
	"""Apply movement while airborne with 3C configuration"""
	if not active_3c_config:
		return
	
	var camera_transform = get_camera_transform()
	var movement_3d = get_movement_vector_3d(camera_transform)
	var target_speed = get_target_speed() * active_3c_config.air_control
	
	# Air control
	var air_acceleration = active_3c_config.acceleration * active_3c_config.air_control
	velocity.x = move_toward(velocity.x, movement_3d.x * target_speed, air_acceleration * delta)
	velocity.z = move_toward(velocity.z, movement_3d.z * target_speed, air_acceleration * delta)
	
	# Apply gravity
	velocity.y -= base_gravity * active_3c_config.character_responsiveness * delta
	
	move_and_slide()

func get_camera_transform() -> Transform3D:
	"""Get camera transform for movement calculation"""
	if camera_3c_manager and camera_3c_manager.camera:
		return camera_3c_manager.camera.global_transform
	return Transform3D.IDENTITY

func get_movement_vector_3d(camera_transform: Transform3D) -> Vector3:
	"""Convert 2D input to 3D movement vector"""
	var camera_basis = camera_transform.basis
	var forward = -camera_basis.z
	var right = camera_basis.x
	
	forward.y = 0
	right.y = 0
	forward = forward.normalized()
	right = right.normalized()
	
	return (forward * movement_direction.y + right * movement_direction.x).normalized()

func get_target_speed() -> float:
	"""Get target speed based on movement mode and 3C config"""
	match current_movement_mode:
		"slow_walking":
			return active_3c_config.walk_speed * 0.5
		"walking":
			return active_3c_config.walk_speed
		"running":
			return active_3c_config.run_speed if not is_sprinting else active_3c_config.sprint_speed
		_:
			return 0.0

# === JUMP HANDLING ===

func handle_jump():
	"""Handle jump with 3C configuration"""
	if jump_system and active_3c_config:
		var jump_force = active_3c_config.jump_height * active_3c_config.character_responsiveness
		if jump_system.can_jump():
			jump_system.execute_jump(jump_force)
			jump_performed.emit(jump_force, not is_on_floor())

# === GROUND STATE DETECTION ===

func emit_ground_state_changes():
	var current_grounded = is_on_floor()
	if current_grounded != last_emitted_grounded:
		ground_state_changed.emit(current_grounded)
		last_emitted_grounded = current_grounded

# === SIGNAL HANDLERS ===

func _on_movement_started(direction: Vector2, magnitude: float):
	handle_movement_action("move_start", {"direction": direction, "magnitude": magnitude})

func _on_movement_updated(direction: Vector2, magnitude: float):
	handle_movement_action("move_update", {"direction": direction, "magnitude": magnitude})

func _on_movement_stopped():
	handle_movement_action("move_stop")

func _on_sprint_started():
	handle_movement_action("sprint_start")

func _on_sprint_stopped():
	handle_movement_action("sprint_stop")

func _on_slow_walk_started():
	handle_movement_action("slow_walk_start")

func _on_slow_walk_stopped():
	handle_movement_action("slow_walk_stop")

func _on_jump_pressed():
	handle_jump()

func _on_reset_pressed():
	# Reset character position or state as needed
	pass

# === ANIMATION CONNECTION ===

func connect_animation_controller():
	"""Connect to animation controller if available"""
	if animation_controller:
		movement_changed.connect(animation_controller._on_movement_changed)
		mode_changed.connect(animation_controller._on_mode_changed)

# === LEGACY COMPATIBILITY METHODS ===
# These methods maintain compatibility with existing state scripts

func update_ground_state():
	"""Legacy method for state compatibility"""
	emit_ground_state_changes()

func get_movement_manager():
	"""Legacy method - returns self as movement manager"""
	return self

func set_movement_active(active: bool):
	"""Legacy method for movement state"""
	if active and movement_magnitude == 0:
		movement_magnitude = 0.1
		movement_direction = Vector2.UP
	elif not active:
		movement_magnitude = 0.0
		movement_direction = Vector2.ZERO
	update_movement_mode()

func set_running(running: bool):
	"""Legacy method for running state"""
	is_sprinting = running
	update_movement_mode()

func set_slow_walking(slow: bool):
	"""Legacy method for slow walking state"""
	is_slow_walking = slow
	update_movement_mode()

func reset_jump_state():
	"""Legacy method for jump system compatibility"""
	if jump_system and jump_system.has_method("reset_jump_state"):
		jump_system.reset_jump_state()

func apply_gravity(delta: float):
	"""Legacy method - apply gravity to character"""
	if not is_on_floor():
		velocity.y -= base_gravity * active_3c_config.character_responsiveness * delta if active_3c_config else base_gravity * delta

func apply_movement(delta: float):
	"""Legacy method - apply movement and call move_and_slide"""
	if is_on_floor():
		apply_ground_movement(delta)
	else:
		apply_air_movement(delta)
