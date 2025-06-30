# ControllerCharacter.gd - 3C Framework Integration
extends CharacterBody3D

@export_group("Physics")
@export var gravity_multiplier = 1.0

@export_group("3C Configuration")
@export var active_3c_config: CharacterConfig
@export var auto_apply_config_on_ready: bool = true
@export var available_presets: Array[CharacterConfig] = []

@export_group("Components")
@export var animation_controller: AnimationManager
@export var camera: Camera3D
@export var input_manager: InputManager
@export var jump_system: JumpSystem
@export var debug_helper: CharacterDebugHelper

# === SIGNALS ===
signal ground_state_changed(is_grounded: bool)
signal jump_performed(jump_force: float, is_air_jump: bool)
signal three_c_config_changed(config: CharacterConfig)

# === COMPONENTS ===
var state_machine: CharacterStateMachine
var movement_manager: MovementManager
var camera_rig: CameraRig

# === STATE ===
var last_emitted_grounded: bool = true
var base_gravity: float

func _ready():
	setup_character()
	setup_components()
	setup_3c_system()
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
	
	# Get camera rig
	camera_rig = get_node_or_null("CameraRig") as CameraRig
	if not camera_rig:
		push_warning("No CameraRig found - some 3C features will be limited")
	
	# Setup camera reference
	if camera:
		movement_manager.setup_camera_reference(camera)

func setup_3c_system():
	"""Initialize the 3C configuration system"""
	# Load default config if none set
	if not active_3c_config:
		active_3c_config = TCPresets.get_botw_config()
		print("🎮 3C: Using default BOTW config")
	
	# Load available presets if empty
	if available_presets.is_empty():
		available_presets = TCPresets.get_all_presets()
	
	# Apply initial configuration
	if auto_apply_config_on_ready:
		apply_3c_configuration()

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

# === 3C CONFIGURATION SYSTEM ===

func apply_3c_configuration():
	"""Apply current 3C configuration to all systems"""
	if not active_3c_config:
		push_warning("No 3C config to apply!")
		return
	
	print("🎮 3C: Applying configuration: ", active_3c_config.config_name)
	
	# Apply to movement manager
	if movement_manager and movement_manager.has_method("configure_from_3c"):
		movement_manager.configure_from_3c(active_3c_config)
	elif movement_manager:
		active_3c_config.apply_to_movement_manager(movement_manager)
	
	# Apply to camera rig
	if camera_rig and camera_rig.has_method("configure_from_3c"):
		camera_rig.configure_from_3c(active_3c_config)
	elif camera_rig:
		active_3c_config.apply_to_camera_rig(camera_rig)
	
	# Apply to input manager
	if input_manager and input_manager.has_method("configure_from_3c"):
		input_manager.configure_from_3c(active_3c_config)
	elif input_manager:
		active_3c_config.apply_to_input_manager(input_manager)
	
	# Emit signal for other systems
	three_c_config_changed.emit(active_3c_config)
	
	print("🎮 3C: Configuration applied successfully")

func switch_3c_config(new_config: CharacterConfig):
	"""Runtime 3C configuration switching"""
	if not new_config:
		push_warning("Cannot switch to null 3C config!")
		return
	
	active_3c_config = new_config
	apply_3c_configuration()
	print("🎮 3C: Switched to configuration: ", new_config.config_name)

func switch_to_preset(preset_name: String):
	"""Switch to a preset by name"""
	var preset = TCPresets.get_preset_by_name(preset_name)
	if preset:
		switch_3c_config(preset)
	else:
		push_warning("3C preset not found: " + preset_name)

func get_current_3c_info() -> Dictionary:
	"""Get current 3C configuration information"""
	if not active_3c_config:
		return {}
	
	return {
		"config_name": active_3c_config.config_name,
		"character_type": CharacterConfig.CharacterType.keys()[active_3c_config.character_type],
		"camera_type": CharacterConfig.CameraType.keys()[active_3c_config.camera_type],
		"control_type": CharacterConfig.ControlType.keys()[active_3c_config.control_type],
		"character_responsiveness": active_3c_config.character_responsiveness,
		"camera_distance": active_3c_config.camera_distance,
		"control_precision": active_3c_config.control_precision
	}

# === PRESET MANAGEMENT ===

func add_custom_preset(config: CharacterConfig):
	"""Add a custom configuration to available presets"""
	if config and not config in available_presets:
		available_presets.append(config)
		print("🎮 3C: Added custom preset: ", config.config_name)

func remove_preset(config_name: String):
	"""Remove a preset by name"""
	for i in range(available_presets.size()):
		if available_presets[i].config_name == config_name:
			available_presets.remove_at(i)
			print("🎮 3C: Removed preset: ", config_name)
			return
	push_warning("Preset not found for removal: " + config_name)

func get_available_preset_names() -> Array[String]:
	"""Get list of all available preset names"""
	var names: Array[String] = []
	for preset in available_presets:
		names.append(preset.config_name)
	return names

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
	if jump_system and jump_system.can_jump():
		var jump_force = jump_system.calculate_jump_force()
		velocity.y = jump_force
		jump_performed.emit(jump_force, not is_on_floor())

func _on_reset_pressed():
	global_position = Vector3.ZERO
	velocity = Vector3.ZERO

func emit_ground_state_changes():
	var current_grounded = is_on_floor()
	if current_grounded != last_emitted_grounded:
		ground_state_changed.emit(current_grounded)
		last_emitted_grounded = current_grounded

# === MISSING METHODS FOR STATE COMPATIBILITY ===

func update_ground_state():
	"""Update ground detection - for state compatibility"""
	emit_ground_state_changes()

func apply_gravity(delta: float):
	"""Apply gravity to character"""
	if not is_on_floor():
		velocity.y -= base_gravity * gravity_multiplier * delta

func get_movement_vector() -> Vector3:
	"""Get current movement vector"""
	if movement_manager:
		return movement_manager.get_movement_vector()
	return Vector3.ZERO

func get_target_velocity(delta: float) -> Vector3:
	"""Get target velocity including gravity"""
	if movement_manager:
		var target_vel = movement_manager.get_target_velocity(velocity, delta)
		# Preserve Y velocity (gravity)
		target_vel.y = velocity.y
		return target_vel
	return velocity

# === DEBUG HELPERS ===

func print_3c_status():
	"""Debug function to print current 3C configuration"""
	var info = get_current_3c_info()
	print("=== 3C STATUS ===")
	for key in info:
		print(key + ": " + str(info[key]))

func test_all_presets():
	"""Debug function to cycle through all presets"""
	for preset in available_presets:
		print("🧪 Testing preset: ", preset.config_name)
		switch_3c_config(preset)
		await get_tree().create_timer(2.0).timeout
	
	# Return to original
	switch_3c_config(TCPresets.get_botw_config())
