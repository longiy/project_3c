# CCC_CharacterManager.gd - Enhanced with centralized movement coordination
extends Node
class_name CCC_CharacterManager

# === WRAPPED COMPONENTS ===
@export var movement_manager: MovementManager
@export var character_body: CharacterBody3D

# === ADDITIONAL COMPONENT REFERENCES ===
var animation_manager: AnimationManager
var state_machine: CharacterStateMachine
var jump_system: JumpSystem

# === SIGNALS (Enhanced from MovementManager) ===
signal movement_changed(is_moving: bool, direction: Vector2, speed: float)
signal mode_changed(is_running: bool, is_slow_walking: bool)
signal character_state_changed(old_state: String, new_state: String)
signal physics_state_changed(is_grounded: bool, velocity: Vector3)

# === CCC CHARACTER CONFIGURATION ===
enum CharacterType {
	AVATAR,        # Direct character control (current implementation)
	OBSERVER,      # Watch-only, no direct control
	COMMANDER,     # Control multiple units/characters
	COLLABORATOR   # Shared control with AI/other players
}

# Character behavior settings for each type
var character_configs = {
	CharacterType.AVATAR: {
		"allows_direct_control": true,
		"movement_responsiveness": 1.0,
		"embodiment_quality": 1.0,
		"ai_assistance": false
	},
	CharacterType.OBSERVER: {
		"allows_direct_control": false,
		"movement_responsiveness": 0.0,
		"embodiment_quality": 0.3,
		"ai_assistance": false
	},
	CharacterType.COMMANDER: {
		"allows_direct_control": true,
		"movement_responsiveness": 0.7,
		"embodiment_quality": 0.6,
		"ai_assistance": true
	}
}

var current_character_type: CharacterType = CharacterType.AVATAR

# === MIGRATED MOVEMENT COORDINATION ===
var movement_logic_migrated = false
var last_physics_state = {"grounded": true, "velocity": Vector3.ZERO}
var movement_state_history = []
var max_history_size = 10

# === ENHANCED MOVEMENT STATE ===
var movement_context = {
	"surface_type": "ground",
	"movement_intent": "idle",
	"environmental_factors": [],
	"performance_mode": "normal"
}




func _ready():
	setup_components()
	setup_additional_references()
	connect_movement_signals()
	check_migration_status()
	print("✅ CCC_CharacterManager: Initialized with centralized movement coordination")


func setup_components():
	"""Find and reference wrapped components"""
	if not movement_manager:
		movement_manager = get_node_or_null("MovementManager")
	
	if not movement_manager:
		# Try finding it as a sibling
		movement_manager = get_parent().get_node_or_null("MovementManager")
	
	if not character_body:
		character_body = get_parent() as CharacterBody3D
	
	if not movement_manager:
		push_error("CCC_CharacterManager: No MovementManager found!")
		return
	
	if not character_body:
		push_error("CCC_CharacterManager: No CharacterBody3D found!")
		return

func setup_additional_references():
	"""Setup references to other character components for coordination"""
	animation_manager = get_parent().get_node_or_null("AnimationManager")
	state_machine = get_parent().get_node_or_null("CharacterStateMachine")
	jump_system = get_parent().get_node_or_null("JumpSystem")
	
	print("🔗 CCC_CharacterManager: Connected to ", 
		  "Animation:", animation_manager != null, 
		  " StateMachine:", state_machine != null,
		  " JumpSystem:", jump_system != null)

func check_migration_status():
	"""Check if we should take over movement coordination"""
	movement_logic_migrated = true
	print("🔄 CCC_CharacterManager: Taking control of movement coordination")

func connect_movement_signals():
	"""Connect MovementManager signals and add coordination logic"""
	if not movement_manager:
		return
	
	# Connect enhanced movement signals
	movement_manager.movement_changed.connect(_on_movement_changed_enhanced)
	movement_manager.mode_changed.connect(_on_mode_changed_enhanced)

func _physics_process(delta):
	"""MIGRATED: Enhanced physics processing with coordination"""
	if movement_logic_migrated:
		process_physics_coordination(delta)

func process_physics_coordination(delta: float):
	"""MIGRATED: Coordinate physics, animation, and state systems"""
	# Track physics state changes
	var current_grounded = character_body.is_on_floor()
	var current_velocity = character_body.velocity
	
	if current_grounded != last_physics_state.grounded or current_velocity.distance_to(last_physics_state.velocity) > 0.5:
		last_physics_state.grounded = current_grounded
		last_physics_state.velocity = current_velocity
		physics_state_changed.emit(current_grounded, current_velocity)
		
		# Coordinate state transitions based on physics
		coordinate_state_transitions(current_grounded, current_velocity)
	
	# Update movement context
	update_movement_context(delta)

func coordinate_state_transitions(is_grounded: bool, velocity: Vector3):
	"""MIGRATED: Coordinate state transitions across systems"""
	# Update jump system ground state
	if jump_system:
		jump_system.update_ground_state()
	
	# Coordinate with state machine if character type allows
	var config = character_configs.get(current_character_type, {})
	if config.get("allows_direct_control", true) and state_machine:
		coordinate_with_state_machine(is_grounded, velocity)

func coordinate_with_state_machine(is_grounded: bool, velocity: Vector3):
	"""Coordinate movement with state machine"""
	var current_state = state_machine.get_current_state_name() if state_machine else ""
	var suggested_state = ""
	
	# Suggest state transitions based on physics and movement
	if not is_grounded and velocity.y < -1.0:
		if current_state != "airborne" and current_state != "falling":
			suggested_state = "airborne"
	elif is_grounded and velocity.y <= 0.1:
		if current_state == "airborne" or current_state == "falling":
			suggested_state = "landing"
		elif is_movement_active() and current_state == "idle":
			suggested_state = "walking"
		elif not is_movement_active() and (current_state == "walking" or current_state == "running"):
			suggested_state = "idle"
	
	# Apply state transition if suggested
	if suggested_state != "" and suggested_state != current_state:
		print("🎭 CCC_CharacterManager: Coordinating state transition: ", current_state, " → ", suggested_state)
		if state_machine and state_machine.has_method("request_state_change"):
			state_machine.request_state_change(suggested_state)

func update_movement_context(delta: float):
	"""Update movement context for enhanced coordination"""
	# Determine movement intent
	if is_movement_active():
		if is_running():
			movement_context.movement_intent = "running"
		elif is_slow_walking():
			movement_context.movement_intent = "slow_walking"
		else:
			movement_context.movement_intent = "walking"
	else:
		movement_context.movement_intent = "idle"
	
	# Determine surface type (can be expanded)
	movement_context.surface_type = "ground" if character_body.is_on_floor() else "air"
	
	# Store movement history for analysis
	add_movement_state_to_history()

func add_movement_state_to_history():
	"""Add current movement state to history for pattern analysis"""
	var state_snapshot = {
		"timestamp": Time.get_ticks_msec() / 1000.0,
		"position": character_body.global_position,
		"velocity": character_body.velocity,
		"is_grounded": character_body.is_on_floor(),
		"movement_intent": movement_context.movement_intent,
		"input_direction": get_current_input_direction()
	}
	
	movement_state_history.append(state_snapshot)
	
	# Keep history size manageable
	if movement_state_history.size() > max_history_size:
		movement_state_history.pop_front()

# === ENHANCED SIGNAL HANDLERS ===

func _on_movement_changed_enhanced(is_moving: bool, direction: Vector2, speed: float):
	"""Enhanced movement change handler with coordination"""
	# Emit standard signal
	movement_changed.emit(is_moving, direction, speed)
	
	# Enhanced coordination logic
	if movement_logic_migrated:
		coordinate_movement_change(is_moving, direction, speed)

func _on_mode_changed_enhanced(is_running: bool, is_slow_walking: bool):
	"""Enhanced mode change handler with coordination"""
	# Emit standard signal
	mode_changed.emit(is_running, is_slow_walking)
	
	# Enhanced coordination logic
	if movement_logic_migrated:
		coordinate_mode_change(is_running, is_slow_walking)

func coordinate_movement_change(is_moving: bool, direction: Vector2, speed: float):
	"""Coordinate movement changes across character systems"""
	# Apply character type-specific behavior
	var config = character_configs.get(current_character_type, {})
	var responsiveness = config.get("movement_responsiveness", 1.0)
	
	if responsiveness < 1.0:
		# Reduce responsiveness for commander/observer types
		# Could modify movement speed or add delays here
		pass
	
	# Enhanced animation coordination
	if animation_manager:
		coordinate_with_animation(is_moving, direction, speed)

func coordinate_mode_change(is_running: bool, is_slow_walking: bool):
	"""Coordinate mode changes across character systems"""
	print("🏃 CCC_CharacterManager: Movement mode coordinated - Running:", is_running, " SlowWalk:", is_slow_walking)

func coordinate_with_animation(is_moving: bool, direction: Vector2, speed: float):
	"""Enhanced animation coordination"""
	# This could be expanded to provide more sophisticated animation control
	# For now, let the existing animation manager handle it
	pass

# === MOVEMENT PASSTHROUGH METHODS (Enhanced) ===

func handle_movement_action(action: String, context: Dictionary = {}):
	"""Enhanced movement action handling"""
	if not movement_manager:
		return
	
	# Apply character type filtering
	var config = character_configs.get(current_character_type, {})
	if not config.get("allows_direct_control", true):
		print("🚫 CCC_CharacterManager: Movement blocked for character type: ", CharacterType.keys()[current_character_type])
		return
	
	# Apply responsiveness modification
	var responsiveness = config.get("movement_responsiveness", 1.0)
	if responsiveness < 1.0 and context.has("magnitude"):
		context["magnitude"] = context["magnitude"] * responsiveness
	
	movement_manager.handle_movement_action(action, context)

func handle_mode_action(action: String):
	"""Enhanced mode action handling"""
	if not movement_manager:
		return
	
	# Apply character type filtering
	var config = character_configs.get(current_character_type, {})
	if not config.get("allows_direct_control", true):
		return
	
	movement_manager.handle_mode_action(action)

func apply_ground_movement(delta: float):
	"""Enhanced ground movement application"""
	if movement_manager:
		movement_manager.apply_ground_movement(delta)

func apply_air_movement(delta: float):
	"""Enhanced air movement application"""
	if movement_manager:
		movement_manager.apply_air_movement(delta)

# === CHARACTER STATE PROPERTIES (Enhanced) ===

func is_movement_active() -> bool:
	"""Check if character is actively moving"""
	if movement_manager:
		return movement_manager.is_movement_active
	return false

func is_running() -> bool:
	"""Check if character is running"""
	if movement_manager:
		return movement_manager.is_running
	return false

func is_slow_walking() -> bool:
	"""Check if character is slow walking"""
	if movement_manager:
		return movement_manager.is_slow_walking
	return false

func get_current_input_direction() -> Vector2:
	"""Get current input direction"""
	if movement_manager:
		return movement_manager.current_input_direction
	return Vector2.ZERO

func get_movement_speed() -> float:
	"""Get current movement speed"""
	if movement_manager:
		return movement_manager.get_movement_speed()
	return 0.0

func get_target_speed() -> float:
	"""Get target movement speed"""
	if movement_manager:
		return movement_manager.get_target_speed()
	return 0.0

# === PHYSICS PASSTHROUGH (Enhanced) ===

func get_velocity() -> Vector3:
	"""Get character velocity"""
	if character_body:
		return character_body.velocity
	return Vector3.ZERO

func set_velocity(velocity: Vector3):
	"""Set character velocity with character type consideration"""
	if character_body:
		var config = character_configs.get(current_character_type, {})
		var responsiveness = config.get("movement_responsiveness", 1.0)
		character_body.velocity = velocity * responsiveness

func is_on_floor() -> bool:
	"""Check if character is on floor"""
	if character_body:
		return character_body.is_on_floor()
	return false

func get_position() -> Vector3:
	"""Get character position"""
	if character_body:
		return character_body.global_position
	return Vector3.ZERO

func set_position(position: Vector3):
	"""Set character position"""
	if character_body:
		character_body.global_position = position

# === CCC CHARACTER INTERFACE (Enhanced Implementation) ===

func configure_character_type(character_type: CharacterType):
	"""Configure the character type with full implementation"""
	var old_type = current_character_type
	current_character_type = character_type
	
	print("👤 CCC_CharacterManager: Character type changed from ", CharacterType.keys()[old_type], " to ", CharacterType.keys()[character_type])
	
	# Apply character type configuration
	var config = character_configs.get(character_type, {})
	
	# Apply immediate changes based on character type
	match character_type:
		CharacterType.AVATAR:
			print("   → Avatar: Full direct control with maximum responsiveness")
		CharacterType.OBSERVER:
			print("   → Observer: Watch-only mode, movement disabled")
			# Stop any current movement
			if movement_manager:
				movement_manager.set_movement_active(false)
		CharacterType.COMMANDER:
			print("   → Commander: Reduced direct control, AI assistance enabled")
		CharacterType.COLLABORATOR:
			print("   → Collaborator: Shared control mode")

func set_embodiment_quality(quality: float):
	"""Set how much the player feels 'present' in the character"""
	var config = character_configs.get(current_character_type, {})
	config["embodiment_quality"] = clamp(quality, 0.0, 1.0)
	
	# Could affect camera closeness, animation responsiveness, etc.
	print("👤 CCC_CharacterManager: Embodiment quality set to ", quality)

func set_responsiveness(responsiveness: float):
	"""Set character responsiveness to input"""
	var config = character_configs.get(current_character_type, {})
	config["movement_responsiveness"] = clamp(responsiveness, 0.0, 1.0)
	
	print("👤 CCC_CharacterManager: Movement responsiveness set to ", responsiveness)

func enable_ai_assistance(enabled: bool):
	"""Enable AI assistance for movement"""
	var config = character_configs.get(current_character_type, {})
	config["ai_assistance"] = enabled
	
	print("👤 CCC_CharacterManager: AI assistance ", "enabled" if enabled else "disabled")

# === CAMERA REFERENCE SETUP ===

func setup_camera_reference(camera: Camera3D):
	"""Setup camera reference for movement calculations"""
	if movement_manager:
		movement_manager.setup_camera_reference(camera)

# === ENHANCED DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get comprehensive debug information"""
	var debug_data = {
		"character_type": CharacterType.keys()[current_character_type],
		"migration_status": "movement_coordination_migrated" if movement_logic_migrated else "legacy",
		"character_config": character_configs.get(current_character_type, {}),
		"movement_context": movement_context,
		"physics_state": last_physics_state
	}
	
	if character_body:
		debug_data.merge({
			"position": get_position(),
			"velocity": get_velocity(),
			"is_on_floor": is_on_floor()
		})
	
	if movement_manager:
		debug_data["movement"] = {
			"is_active": is_movement_active(),
			"is_running": is_running(),
			"is_slow_walking": is_slow_walking(),
			"speed": get_movement_speed(),
			"target_speed": get_target_speed(),
			"input_direction": get_current_input_direction()
		}
	
	# Add coordination status
	debug_data["coordination"] = {
		"animation_manager": animation_manager != null,
		"state_machine": state_machine != null,
		"jump_system": jump_system != null,
		"history_size": movement_state_history.size()
	}
	
	return debug_data

# === MOVEMENT ANALYSIS (New) ===

func get_movement_analysis() -> Dictionary:
	"""Analyze movement patterns from history"""
	if movement_state_history.size() < 2:
		return {"status": "insufficient_data"}
	
	var recent_states = movement_state_history.slice(-5)  # Last 5 states
	var movement_patterns = {
		"average_speed": 0.0,
		"direction_changes": 0,
		"time_moving": 0.0,
		"time_idle": 0.0
	}
	
	for i in range(recent_states.size()):
		var state = recent_states[i]
		movement_patterns.average_speed += state.velocity.length()
		
		if state.movement_intent != "idle":
			movement_patterns.time_moving += 1.0
		else:
			movement_patterns.time_idle += 1.0
	
	movement_patterns.average_speed /= recent_states.size()
	
	return movement_patterns
