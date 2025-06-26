# AnimationController.gd - Pure signal-driven version (NO ACTION SYSTEM)
extends Node
class_name AnimationController

@export var animation_tree: AnimationTree

@export_group("Blend Space Settings") 
@export var move_blend_param = "parameters/Move/blend_position"
@export var blend_smoothing = 8.0

@export_group("Speed Mapping")
@export var idle_threshold = 0.3
@export var walk_speed_reference = 3.0
@export var run_speed_reference = 6.0

# Character reference (keep for validation only)
var character: CharacterBody3D

# Animation state tracking - PURE SIGNAL-DRIVEN
var current_blend_value = 0.0  # For 1D
var current_blend_vector = Vector2.ZERO  # For 2D
var target_blend_value = 0.0
var target_blend_vector = Vector2.ZERO

# Signal-driven state (NO MORE DIRECT READS)
var received_movement_speed = 0.0
var received_input_direction = Vector2.ZERO
var received_is_movement_active = false
var received_is_running = false
var received_is_slow_walking = false

func _ready():
	character = get_parent() as CharacterBody3D
	
	if not character:
		push_error("AnimationController must be child of CharacterBody3D")
		return
		
	if not animation_tree:
		push_error("AnimationTree not assigned to AnimationController")
		return
	
	animation_tree.active = true
	
	# CONNECT TO CHARACTER SIGNALS ONLY
	connect_to_character_signals()
	
	print("✅ AnimationController: Pure signal-driven system initialized")

func connect_to_character_signals():
	"""Connect to character signals for data"""
	# Connect to movement signals
	if character.has_signal("movement_state_changed"):
		character.movement_state_changed.connect(_on_movement_state_changed)
		print("✅ Animation: Connected to movement_state_changed")
	
	if character.has_signal("movement_mode_changed"):
		character.movement_mode_changed.connect(_on_movement_mode_changed)
		print("✅ Animation: Connected to movement_mode_changed")
	
	if character.has_signal("speed_changed"):
		character.speed_changed.connect(_on_speed_changed)
		print("✅ Animation: Connected to speed_changed")

func _physics_process(delta):
	# Handle blend smoothing only
	if animation_tree:
		update_blend_smoothing(delta)

# === SIGNAL HANDLERS (PURE SIGNAL VERSION) ===

func _on_movement_state_changed(is_moving: bool, direction: Vector2, magnitude: float):
	"""Handle movement state changes via signal"""
	received_is_movement_active = is_moving
	received_input_direction = direction
	
	print("🎬 Animation: Movement signal - Active:", is_moving, " Direction:", direction)
	update_animation_immediately()

func _on_movement_mode_changed(is_running: bool, is_slow_walking: bool):
	"""Handle movement mode changes via signal"""
	received_is_running = is_running
	received_is_slow_walking = is_slow_walking
	
	print("🎬 Animation: Mode signal - Running:", is_running, " SlowWalk:", is_slow_walking)
	update_animation_immediately()

func _on_speed_changed(new_speed: float):
	"""Handle speed changes via signal"""
	received_movement_speed = new_speed
	
	print("🎬 Animation: Speed signal - Speed:", new_speed)
	update_animation_immediately()

func update_animation_immediately():
	"""Update animation targets based on RECEIVED signal data"""
	if is_using_1d_blend_space():
		calculate_1d_blend_target()
	else:
		calculate_2d_blend_target()

# === BLEND SPACE CALCULATION (SIGNAL-DRIVEN) ===

func calculate_1d_blend_target():
	"""Calculate 1D blend target based on SIGNAL data"""
	if not received_is_movement_active:
		target_blend_value = 0.0
		return
	
	var input_magnitude = received_input_direction.length()
	
	if input_magnitude < 0.1:
		target_blend_value = 0.0
		return
	
	# Use RECEIVED mode data instead of reading character
	if received_is_running:
		target_blend_value = 0.5  # Run animation
	elif received_is_slow_walking:
		target_blend_value = -0.5  # Slow walk animation
	else:
		target_blend_value = -0.2  # Normal walk animation
	
	print("🎬 1D Blend calculated: ", target_blend_value, " (Signal Running: ", received_is_running, ", Slow: ", received_is_slow_walking, ")")

func calculate_2d_blend_target():
	"""Calculate 2D blend target based on SIGNAL data"""
	if not received_is_movement_active:
		target_blend_vector = Vector2.ZERO
		return
	
	var input_magnitude = received_input_direction.length()
	
	if input_magnitude < 0.1:
		target_blend_vector = Vector2.ZERO
		return
	
	# Map input to blend space coordinates
	target_blend_vector.x = received_input_direction.x * 1.0  # Strafe amount
	target_blend_vector.y = -received_input_direction.y * 1.0  # Forward/back amount
	
	# Scale by RECEIVED mode data
	if received_is_running:
		target_blend_vector *= 1.5  # Running intensity
	elif received_is_slow_walking:
		target_blend_vector *= 0.5  # Slow walk intensity
	else:
		target_blend_vector *= 1.0  # Normal walk intensity
	
	print("🎬 2D Blend calculated: ", target_blend_vector, " from signal input: ", received_input_direction)

func update_blend_smoothing(delta: float):
	"""Apply smoothing to blend transitions"""
	if not animation_tree:
		return
	
	if is_using_1d_blend_space():
		current_blend_value = lerp(current_blend_value, target_blend_value, blend_smoothing * delta)
		animation_tree.set(move_blend_param, current_blend_value)
	else:
		current_blend_vector = current_blend_vector.lerp(target_blend_vector, blend_smoothing * delta)
		animation_tree.set(move_blend_param, current_blend_vector)

# === UTILITY METHODS ===

func is_using_1d_blend_space() -> bool:
	var current_value = animation_tree.get(move_blend_param)
	return current_value is float

# === DEBUG INFO (PURE SIGNALS) ===

func get_debug_info() -> Dictionary:
	return {
		"movement_speed": received_movement_speed,
		"input_direction": received_input_direction,
		"is_movement_active": received_is_movement_active,
		"is_running": received_is_running,
		"is_slow_walking": received_is_slow_walking,
		"blend_1d": current_blend_value,
		"blend_2d": current_blend_vector,
		"target_1d": target_blend_value,
		"target_2d": target_blend_vector,
		"is_1d_mode": is_using_1d_blend_space(),
		"system_type": "Pure Signal-Driven",
		"action_system_dependency": false
	}
