# CCC_CharacterController.gd - CLEANED UP: Pure CCC Architecture
extends CharacterBody3D
class_name CCC_CharacterController

# === CCC MANAGERS ===
@export_group("CCC Managers")
@export var control_manager: CCC_ControlManager
@export var character_manager: CCC_CharacterManager
@export var camera_manager: CCC_CameraManager

# === COMPONENT REFERENCES ===
@export_group("Components")
@export var animation_controller: AnimationManager
@export var jump_system: JumpSystem
@export var debug_helper: CharacterDebugHelper

# === PHYSICS ===
@export_group("Physics")
@export var gravity_multiplier = 1.0

# === CCC CONFIGURATION (Inspector Dropdowns) ===
@export_group("CCC Configuration")

@export_subgroup("Quick Presets")
enum CCC_Preset {
	CUSTOM,
	BOTW_STYLE,
	DIABLO_STYLE, 
	STRATEGY_GAME,
	FPS_SHOOTER,
	PLATFORMER_2D,
	RACING_GAME
}
@export var ccc_preset: CCC_Preset = CCC_Preset.BOTW_STYLE : set = set_ccc_preset

@export_subgroup("Individual Axis Configuration")
@export var control_type: CCC_ControlManager.ControlType = CCC_ControlManager.ControlType.HYBRID : set = set_control_type
@export var character_type: CCC_CharacterManager.CharacterType = CCC_CharacterManager.CharacterType.AVATAR : set = set_character_type  
@export var camera_type: CCC_CameraManager.CameraType = CCC_CameraManager.CameraType.ORBITAL : set = set_camera_type

@export_subgroup("Fine-Tuning Parameters")
@export_range(0.1, 2.0, 0.1) var movement_responsiveness: float = 1.0 : set = set_movement_responsiveness
@export_range(0.1, 3.0, 0.1) var camera_sensitivity: float = 1.0 : set = set_camera_sensitivity
@export_range(0.0, 1.0, 0.1) var embodiment_quality: float = 1.0 : set = set_embodiment_quality
@export var enable_ai_assistance: bool = false : set = set_ai_assistance

@export_subgroup("Advanced Settings")
@export var apply_changes_in_editor: bool = true
@export var auto_save_preset: bool = false
@export var show_debug_info: bool = false

# === PRESET DEFINITIONS ===
var preset_configs = {
	CCC_Preset.BOTW_STYLE: {
		"name": "Breath of the Wild Style",
		"control": CCC_ControlManager.ControlType.HYBRID,
		"character": CCC_CharacterManager.CharacterType.AVATAR,
		"camera": CCC_CameraManager.CameraType.ORBITAL,
		"responsiveness": 1.0,
		"sensitivity": 1.0,
		"embodiment": 1.0,
		"ai_assistance": false
	},
	CCC_Preset.DIABLO_STYLE: {
		"name": "Diablo Style",
		"control": CCC_ControlManager.ControlType.TARGET_BASED,
		"character": CCC_CharacterManager.CharacterType.AVATAR,
		"camera": CCC_CameraManager.CameraType.FOLLOWING,
		"responsiveness": 0.8,
		"sensitivity": 0.7,
		"embodiment": 0.9,
		"ai_assistance": false
	},
	CCC_Preset.STRATEGY_GAME: {
		"name": "Strategy/RTS Style",
		"control": CCC_ControlManager.ControlType.TARGET_BASED,
		"character": CCC_CharacterManager.CharacterType.COMMANDER,
		"camera": CCC_CameraManager.CameraType.FIXED,
		"responsiveness": 0.6,
		"sensitivity": 0.5,
		"embodiment": 0.4,
		"ai_assistance": true
	},
	CCC_Preset.FPS_SHOOTER: {
		"name": "FPS Shooter Style",
		"control": CCC_ControlManager.ControlType.DIRECT,
		"character": CCC_CharacterManager.CharacterType.AVATAR,
		"camera": CCC_CameraManager.CameraType.FIRST_PERSON,
		"responsiveness": 1.0,
		"sensitivity": 1.2,
		"embodiment": 1.0,
		"ai_assistance": false
	},
	CCC_Preset.PLATFORMER_2D: {
		"name": "2D Platformer Style",
		"control": CCC_ControlManager.ControlType.DIRECT,
		"character": CCC_CharacterManager.CharacterType.AVATAR,
		"camera": CCC_CameraManager.CameraType.FOLLOWING,
		"responsiveness": 1.0,
		"sensitivity": 0.0,
		"embodiment": 0.8,
		"ai_assistance": false
	},
	CCC_Preset.RACING_GAME: {
		"name": "Racing Game Style",
		"control": CCC_ControlManager.ControlType.DIRECT,
		"character": CCC_CharacterManager.CharacterType.AVATAR,
		"camera": CCC_CameraManager.CameraType.FOLLOWING,
		"responsiveness": 1.0,
		"sensitivity": 0.8,
		"embodiment": 0.7,
		"ai_assistance": true
	}
}

# === SIGNALS ===
signal ground_state_changed(is_grounded: bool)
signal jump_performed(jump_force: float, is_air_jump: bool)

# === INTERNAL COMPONENTS ===
var state_machine: CharacterStateMachine
var movement_manager: MovementManager  # Referenced by character_manager
var input_manager: InputManager        # Referenced by control_manager

# === STATE ===
var last_emitted_grounded: bool = true
var base_gravity: float

func _ready():
	setup_character()
	setup_ccc_managers()
	setup_components()
	connect_ccc_signals()
	validate_ccc_setup()
	
	# Apply initial configuration
	call_deferred("apply_configuration_to_managers")
	
	if show_debug_info:
		call_deferred("print_configuration_summary")
	
	print("✅ CCC_CharacterController: Pure CCC Architecture initialized with inspector configuration")

func print_configuration_summary():
	"""Print configuration summary for debugging"""
	print(get_configuration_summary())

# === CONFIGURATION SETTERS (Called when dropdowns change) ===

func set_ccc_preset(preset: CCC_Preset):
	"""Apply complete preset configuration"""
	ccc_preset = preset
	
	if preset == CCC_Preset.CUSTOM:
		print("🎛️ CCC: Custom configuration active")
		return
	
	if not preset_configs.has(preset):
		print("❌ CCC: Unknown preset ", preset)
		return
	
	var config = preset_configs[preset]
	print("🎮 CCC: Applying preset - ", config.name)
	
	# Apply preset without triggering individual setters
	_apply_preset_silent(config)
	
	# Apply to managers if they exist
	if Engine.is_editor_hint() and apply_changes_in_editor:
		call_deferred("apply_configuration_to_managers")
	elif not Engine.is_editor_hint():
		apply_configuration_to_managers()

# === CONFIGURATION APPLICATION ===

func apply_configuration_to_managers():
	"""Apply current configuration to all managers"""
	if not validate_ccc_setup():
		print("⚠️ CCC: Cannot apply configuration - managers not ready")
		return
	
	print("🔧 CCC: Applying configuration to managers...")
	
	# Apply to control manager
	if control_manager:
		control_manager.configure_control_type(control_type)
	
	# Apply to character manager  
	if character_manager:
		character_manager.configure_character_type(character_type)
		character_manager.set_responsiveness(movement_responsiveness)
		character_manager.set_embodiment_quality(embodiment_quality)
		character_manager.enable_ai_assistance(enable_ai_assistance)
	
	# Apply to camera manager
	if camera_manager:
		camera_manager.configure_camera_type(camera_type)
		camera_manager.set_information_clarity(camera_sensitivity)
	
	print("✅ CCC: Configuration applied successfully")

# === PRESET MANAGEMENT ===

func get_current_configuration_as_preset() -> Dictionary:
	"""Get current configuration as a preset dictionary"""
	return {
		"name": "Custom Configuration",
		"control": control_type,
		"character": character_type,
		"camera": camera_type,
		"responsiveness": movement_responsiveness,
		"sensitivity": camera_sensitivity,
		"embodiment": embodiment_quality,
		"ai_assistance": enable_ai_assistance
	}

func save_current_as_preset(preset_name: String):
	"""Save current configuration as a named preset"""
	var config = get_current_configuration_as_preset()
	config.name = preset_name
	
	# Could save to a file or user preferences
	print("💾 CCC: Saved preset '", preset_name, "'")
	# TODO: Implement preset saving to disk

func load_preset_from_file(file_path: String):
	"""Load preset from file"""
	# TODO: Implement preset loading from disk
	print("📁 CCC: Loading preset from ", file_path)

# === DEBUG AND VALIDATION ===

func get_configuration_summary() -> String:
	"""Get a human-readable summary of current configuration"""
	var preset_name = "Custom" if ccc_preset == CCC_Preset.CUSTOM else preset_configs.get(ccc_preset, {}).get("name", "Unknown")
	
	return """
CCC Configuration Summary:
========================
Preset: %s
Control: %s
Character: %s  
Camera: %s
Responsiveness: %.1f
Sensitivity: %.1f
Embodiment: %.1f
AI Assistance: %s
""" % [
		preset_name,
		CCC_ControlManager.ControlType.keys()[control_type],
		CCC_CharacterManager.CharacterType.keys()[character_type],
		CCC_CameraManager.CameraType.keys()[camera_type],
		movement_responsiveness,
		camera_sensitivity,
		embodiment_quality,
		"Yes" if enable_ai_assistance else "No"
	]

func _apply_preset_silent(config: Dictionary):
	"""Apply preset configuration without triggering setters"""
	control_type = config.control
	character_type = config.character
	camera_type = config.camera
	movement_responsiveness = config.responsiveness
	camera_sensitivity = config.sensitivity
	embodiment_quality = config.embodiment
	enable_ai_assistance = config.ai_assistance

func set_control_type(new_type: CCC_ControlManager.ControlType):
	"""Set control type and mark as custom if different from preset"""
	control_type = new_type
	check_if_custom_configuration()
	
	if control_manager and not Engine.is_editor_hint():
		control_manager.configure_control_type(new_type)

func set_character_type(new_type: CCC_CharacterManager.CharacterType):
	"""Set character type and mark as custom if different from preset"""
	character_type = new_type
	check_if_custom_configuration()
	
	if character_manager and not Engine.is_editor_hint():
		character_manager.configure_character_type(new_type)

func set_camera_type(new_type: CCC_CameraManager.CameraType):
	"""Set camera type and mark as custom if different from preset"""
	camera_type = new_type
	check_if_custom_configuration()
	
	if camera_manager and not Engine.is_editor_hint():
		camera_manager.configure_camera_type(new_type)

func set_movement_responsiveness(value: float):
	"""Set movement responsiveness"""
	movement_responsiveness = value
	check_if_custom_configuration()
	
	if character_manager and not Engine.is_editor_hint():
		character_manager.set_responsiveness(value)

func set_camera_sensitivity(value: float):
	"""Set camera sensitivity"""
	camera_sensitivity = value
	check_if_custom_configuration()
	
	if camera_manager and not Engine.is_editor_hint():
		camera_manager.set_information_clarity(value)

func set_embodiment_quality(value: float):
	"""Set embodiment quality"""
	embodiment_quality = value
	check_if_custom_configuration()
	
	if character_manager and not Engine.is_editor_hint():
		character_manager.set_embodiment_quality(value)

func set_ai_assistance(enabled: bool):
	"""Set AI assistance"""
	enable_ai_assistance = enabled
	check_if_custom_configuration()
	
	if character_manager and not Engine.is_editor_hint():
		character_manager.enable_ai_assistance(enabled)

func check_if_custom_configuration():
	"""Check if current settings match any preset, otherwise mark as custom"""
	if ccc_preset == CCC_Preset.CUSTOM:
		return  # Already custom
	
	# Check if current settings match the selected preset
	if preset_configs.has(ccc_preset):
		var config = preset_configs[ccc_preset]
		if (control_type != config.control or 
			character_type != config.character or
			camera_type != config.camera or
			abs(movement_responsiveness - config.responsiveness) > 0.1 or
			abs(camera_sensitivity - config.sensitivity) > 0.1 or
			abs(embodiment_quality - config.embodiment) > 0.1 or
			enable_ai_assistance != config.ai_assistance):
			
			print("🎛️ CCC: Configuration modified - switching to CUSTOM")
			ccc_preset = CCC_Preset.CUSTOM

func setup_character():
	"""Setup basic character properties"""
	base_gravity = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	if base_gravity <= 0:
		base_gravity = 9.8
	
	last_emitted_grounded = is_on_floor()

func setup_ccc_managers():
	"""Setup and validate CCC managers"""
	var managers_found = 0
	
	# Find CCC managers
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
	
	# Check if all CCC managers are present
	if managers_found == 3:
		print("🎯 CCC_CharacterController: All 3 CCC managers found")
	else:
		push_error("CCC_CharacterController: Missing CCC managers - found ", managers_found, "/3")

func setup_components():
	"""Setup component references"""
	# Get required components
	state_machine = get_node("CharacterStateMachine") as CharacterStateMachine
	if not state_machine:
		push_error("No CharacterStateMachine found!")
		return
	
	# Get component references for managers
	movement_manager = get_node_or_null("MovementManager")
	if not movement_manager:
		movement_manager = MovementManager.new()
		movement_manager.name = "MovementManager"
		add_child(movement_manager)
	
	input_manager = get_node_or_null("InputManager")
	
	# Setup camera reference for movement calculations
	var camera = get_camera_reference()
	if camera and movement_manager:
		movement_manager.setup_camera_reference(camera)

func connect_ccc_signals():
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

func _physics_process(delta):
	if state_machine:
		state_machine.update(delta)
	
	emit_ground_state_changes()

# === SIGNAL HANDLERS ===

func _on_movement_started(direction: Vector2, magnitude: float):
	character_manager.handle_movement_action("move_start", {"direction": direction, "magnitude": magnitude})

func _on_movement_updated(direction: Vector2, magnitude: float):
	character_manager.handle_movement_action("move_update", {"direction": direction, "magnitude": magnitude})

func _on_movement_stopped():
	character_manager.handle_movement_action("move_end")

func _on_sprint_started():
	character_manager.handle_mode_action("sprint_start")

func _on_sprint_stopped():
	character_manager.handle_mode_action("sprint_end")

func _on_slow_walk_started():
	character_manager.handle_mode_action("slow_walk_start")

func _on_slow_walk_stopped():
	character_manager.handle_mode_action("slow_walk_end")

func _on_jump_pressed():
	"""Handle jump input through jump system"""
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

func _on_reset_pressed():
	reset_character()

# === MOVEMENT INTERFACE ===

func apply_ground_movement(delta: float):
	character_manager.apply_ground_movement(delta)

func apply_air_movement(delta: float):
	character_manager.apply_air_movement(delta)

func get_movement_speed() -> float:
	return character_manager.get_movement_speed()

func get_target_speed() -> float:
	return character_manager.get_target_speed()

# === MOVEMENT MODE PROPERTIES ===

var is_running: bool:
	get:
		return character_manager.is_running()

var is_slow_walking: bool:
	get:
		return character_manager.is_slow_walking()

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

# === CCC CONFIGURATION INTERFACE ===

func configure_ccc_setup(control_type: String, character_type: String, camera_type: String):
	"""Configure complete CCC setup"""
	print("🎯 CCC_CharacterController: Configuring CCC setup...")
	
	# Apply configurations through managers
	if control_manager and control_manager.has_method("configure_control_type"):
		var control_enum = CCC_ControlManager.ControlType.get(control_type.to_upper())
		if control_enum != null:
			control_manager.configure_control_type(control_enum)
	
	if character_manager and character_manager.has_method("configure_character_type"):
		var character_enum = CCC_CharacterManager.CharacterType.get(character_type.to_upper())
		if character_enum != null:
			character_manager.configure_character_type(character_enum)
	
	if camera_manager and camera_manager.has_method("configure_camera_type"):
		var camera_enum = CCC_CameraManager.CameraType.get(camera_type.to_upper())
		if camera_enum != null:
			camera_manager.configure_camera_type(camera_enum)

func switch_to_preset(preset_name: String):
	"""Switch to a predefined CCC preset"""
	match preset_name.to_lower():
		"botw", "zelda":
			configure_ccc_setup("HYBRID", "AVATAR", "ORBITAL")
		"diablo":
			configure_ccc_setup("TARGET_BASED", "AVATAR", "FOLLOWING")
		"strategy", "rts":
			configure_ccc_setup("TARGET_BASED", "COMMANDER", "FIXED")
		"fps":
			configure_ccc_setup("DIRECT", "AVATAR", "FIRST_PERSON")
		_:
			print("❌ Unknown preset: ", preset_name)

# === UTILITY ===

func reset_character():
	if debug_helper:
		debug_helper.reset_character()

func get_camera_reference() -> Camera3D:
	"""Get camera reference from camera manager"""
	if camera_manager and camera_manager.camera_controller and camera_manager.camera_controller.camera:
		return camera_manager.camera_controller.camera
	
	# Fallback to finding CAMERARIG
	var camera_rig = get_node_or_null("../CAMERARIG") as CameraController
	if camera_rig and camera_rig.camera:
		return camera_rig.camera
	
	return null

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get comprehensive CCC debug information"""
	var debug_data = {
		"architecture": "CCC (Pure)",
		"current_state": get_current_state_name(),
		"is_grounded": is_on_floor(),
		"velocity": velocity,
		"position": global_position
	}
	
	# Add CCC manager debug info
	if control_manager:
		debug_data["control"] = control_manager.get_debug_info()
	if character_manager:
		debug_data["character"] = character_manager.get_debug_info()
	if camera_manager:
		debug_data["camera"] = camera_manager.get_debug_info()
	
	return debug_data

# === VALIDATION ===

func validate_ccc_setup() -> bool:
	"""Validate that CCC setup is complete and working"""
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

# === CCC TESTING (Remove after cleanup) ===

func test_character_types():
	"""Test character type switching - REMOVE AFTER CLEANUP"""
	await get_tree().create_timer(3.0).timeout
	print("Switching to observer mode...")
	character_manager.configure_character_type(CCC_CharacterManager.CharacterType.OBSERVER)
	
	await get_tree().create_timer(3.0).timeout
	print("Switching to commander mode...")
	character_manager.configure_character_type(CCC_CharacterManager.CharacterType.COMMANDER)
	
	await get_tree().create_timer(3.0).timeout
	print("Switching back to avatar mode...")
	character_manager.configure_character_type(CCC_CharacterManager.CharacterType.AVATAR)
