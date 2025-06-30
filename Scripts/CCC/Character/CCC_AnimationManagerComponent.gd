# AnimationManagerComponent.gd - Animation state management for 3C framework
extends Node
class_name CCC_AnimationManagerComponent

# === SIGNALS ===
signal animation_state_changed(state_name: String)
signal animation_speed_changed(speed: float)

# === EXPORTS ===
@export_group("Required References")
@export var animation_tree: AnimationTree
@export var animation_player: AnimationPlayer
@export var avatar_component: Node  # AvatarComponent
@export var movement_component: Node  # DirectMovementComponent
@export var config_component: Node  # 3CConfigComponent

@export_group("Animation Properties")
@export var enable_root_motion: bool = false
@export var enable_debug_output: bool = false

# === ANIMATION STATE ===
var state_machine: AnimationNodeStateMachine
var current_animation_state: String = ""
var current_movement_speed: float = 0.0
var is_grounded: bool = true
var movement_active: bool = false

func _ready():
	validate_setup()
	setup_animation_tree()
	connect_component_signals()
	
	if enable_debug_output:
		print("AnimationManagerComponent: Initialized")

func validate_setup():
	"""Validate required references"""
	if not animation_tree:
		push_error("AnimationManagerComponent: animation_tree reference required")
	
	if not animation_player:
		push_error("AnimationManagerComponent: animation_player reference required")
	
	if not avatar_component:
		push_error("AnimationManagerComponent: avatar_component reference required")
	
	if not movement_component:
		push_error("AnimationManagerComponent: movement_component reference required")

func setup_animation_tree():
	"""Setup animation tree state machine"""
	if not animation_tree:
		return
	
	animation_tree.active = true
	state_machine = animation_tree.get("parameters/playback") as AnimationNodeStateMachine
	
	if not state_machine:
		push_error("AnimationManagerComponent: Could not find state machine in AnimationTree")
		return
	
	# Set initial state
	current_animation_state = "idle"
	
	if enable_debug_output:
		print("AnimationManagerComponent: Animation tree setup complete")

func connect_component_signals():
	"""Connect to component signals"""
	if avatar_component:
		if avatar_component.has_signal("character_state_changed"):
			avatar_component.character_state_changed.connect(_on_character_state_changed)
	
	if movement_component:
		if movement_component.has_signal("speed_changed"):
			movement_component.speed_changed.connect(_on_movement_speed_changed)
		if movement_component.has_signal("movement_started"):
			movement_component.movement_started.connect(_on_movement_started)
		if movement_component.has_signal("movement_stopped"):
			movement_component.movement_stopped.connect(_on_movement_stopped)

# === SIGNAL HANDLERS ===

func _on_character_state_changed(state_name: String):
	"""Handle character state changes"""
	update_animation_state(state_name)
	
	if enable_debug_output:
		print("AnimationManagerComponent: Character state changed to ", state_name)

func _on_movement_speed_changed(speed: float):
	"""Handle movement speed changes"""
	current_movement_speed = speed
	update_animation_speed()
	
	if enable_debug_output:
		print("AnimationManagerComponent: Movement speed changed to ", speed)

func _on_movement_started():
	"""Handle movement start"""
	movement_active = true
	update_movement_blend()

func _on_movement_stopped():
	"""Handle movement stop"""
	movement_active = false
	update_movement_blend()

# === ANIMATION STATE MANAGEMENT ===

func update_animation_state(new_state: String):
	"""Update animation state based on character state"""
	if new_state == current_animation_state:
		return
	
	var animation_state = map_character_state_to_animation(new_state)
	
	if state_machine and state_machine.has_method("travel"):
		state_machine.travel(animation_state)
		current_animation_state = animation_state
		animation_state_changed.emit(animation_state)
		
		if enable_debug_output:
			print("AnimationManagerComponent: Animation state changed to ", animation_state)

func map_character_state_to_animation(character_state: String) -> String:
	"""Map character state to animation state name"""
	match character_state.to_lower():
		"idle":
			return "Idle"
		"walking":
			return "Move"  # Assuming blend space for walk/run
		"running":
			return "Move"
		"jumping":
			return "Airborne"
		"airborne":
			return "Airborne"
		"landing":
			return "Land"
		_:
			return "Idle"

func update_animation_speed():
	"""Update animation speed based on movement"""
	if not animation_tree:
		return
	
	# Calculate animation speed multiplier
	var base_speed = get_config_value("walk_speed", 3.0)
	var speed_multiplier = current_movement_speed / base_speed if base_speed > 0 else 1.0
	
	# Clamp speed multiplier to reasonable range
	speed_multiplier = clamp(speed_multiplier, 0.0, 3.0)
	
	# Apply to animation tree
	animation_tree.set("parameters/TimeScale/scale", speed_multiplier)
	animation_speed_changed.emit(speed_multiplier)

func update_movement_blend():
	"""Update movement blend based on speed and activity"""
	if not animation_tree:
		return
	
	# Update blend space position for walk/run blend
	var walk_speed = get_config_value("walk_speed", 3.0)
	var run_speed = get_config_value("run_speed", 6.0)
	
	var blend_position: float = 0.0
	
	if movement_active and current_movement_speed > 0.1:
		if current_movement_speed <= walk_speed:
			blend_position = -1.0  # Walk
		elif current_movement_speed >= run_speed:
			blend_position = 1.0   # Run
		else:
			# Interpolate between walk and run
			var t = (current_movement_speed - walk_speed) / (run_speed - walk_speed)
			blend_position = lerp(-1.0, 1.0, t)
	
	# Apply blend position to animation tree
	animation_tree.set("parameters/Move/blend_position", blend_position)
	
	if enable_debug_output:
		print("AnimationManagerComponent: Movement blend position: ", blend_position)

# === ANIMATION CONTROL ===

func play_one_shot_animation(animation_name: String):
	"""Play a one-shot animation (like attack, jump start)"""
	if animation_player and animation_player.has_animation(animation_name):
		animation_player.play(animation_name)
		
		if enable_debug_output:
			print("AnimationManagerComponent: Playing one-shot animation: ", animation_name)

func set_animation_parameter(parameter_name: String, value):
	"""Set animation tree parameter"""
	if animation_tree:
		animation_tree.set("parameters/" + parameter_name, value)

func get_animation_parameter(parameter_name: String):
	"""Get animation tree parameter"""
	if animation_tree:
		return animation_tree.get("parameters/" + parameter_name)
	return null

# === ROOT MOTION ===

func apply_root_motion():
	"""Apply root motion if enabled (placeholder)"""
	if not enable_root_motion:
		return
	
	# Root motion implementation would go here
	# This would need to work with the character movement system

# === PUBLIC API ===

func get_current_animation_state() -> String:
	"""Get current animation state"""
	return current_animation_state

func is_animation_playing(animation_name: String) -> bool:
	"""Check if specific animation is playing"""
	if animation_player:
		return animation_player.current_animation == animation_name
	return false

func get_animation_length(animation_name: String) -> float:
	"""Get length of specific animation"""
	if animation_player and animation_player.has_animation(animation_name):
		return animation_player.get_animation(animation_name).length
	return 0.0

func set_animation_speed_scale(scale: float):
	"""Set global animation speed scale"""
	if animation_tree:
		animation_tree.set("parameters/TimeScale/scale", scale)

func reset_to_idle():
	"""Reset animation to idle state"""
	update_animation_state("idle")
	current_movement_speed = 0.0
	movement_active = false
	update_movement_blend()

# === CONFIGURATION ===

func configure_from_3c(config: CharacterConfig):
	"""Configure animation system from 3C config"""
	if not config:
		return
	
	# Apply any animation-specific configuration
	if "enable_root_motion" in config:
		enable_root_motion = config.enable_root_motion
	else:
		enable_root_motion = false
		
	if enable_debug_output:
		print("AnimationManagerComponent: Configured from 3C config")

func get_config_value(property_name: String, default_value):
	"""Get configuration value safely"""
	if config_component and config_component.has_method("get_config_value"):
		return config_component.get_config_value(property_name, default_value)
	return default_value

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get debug information about animation manager"""
	var info = {
		"current_state": current_animation_state,
		"movement_speed": current_movement_speed,
		"movement_active": movement_active,
		"animation_tree_active": animation_tree.active if animation_tree else false,
		"root_motion_enabled": enable_root_motion
	}
	
	if animation_tree:
		info["blend_position"] = animation_tree.get("parameters/Move/blend_position")
		info["time_scale"] = animation_tree.get("parameters/TimeScale/scale")
	
	if animation_player:
		info["current_animation"] = animation_player.current_animation
		info["is_playing"] = animation_player.is_playing()
	
	return info
