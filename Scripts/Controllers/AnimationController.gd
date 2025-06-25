# AnimationController.gd - Debug Fix for Walk Detection
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

# Character and action system references
var character: CharacterBody3D
var action_system: ActionSystem

# Animation state tracking
var current_blend_value = 0.0  # For 1D
var current_blend_vector = Vector2.ZERO  # For 2D
var target_blend_value = 0.0
var target_blend_vector = Vector2.ZERO

# Action-based state
var current_movement_speed = 0.0
var current_input_direction = Vector2.ZERO
var is_movement_active = false

# DEBUG: Track state for debugging
var debug_last_speed = 0.0
var debug_last_input = Vector2.ZERO

func _ready():
	character = get_parent() as CharacterBody3D
	
	if not character:
		push_error("AnimationController must be child of CharacterBody3D")
		return
		
	if not animation_tree:
		push_error("AnimationTree not assigned to AnimationController")
		return
	
	# Find action system
	action_system = character.get_node_or_null("ActionSystem")
	if not action_system:
		push_error("ActionSystem not found - animations will not sync properly")
		return
	
	animation_tree.active = true
	setup_action_listeners()
	print("✅ AnimationController: Action-based system initialized")

func _physics_process(delta):
	# Handle blend smoothing and debug info
	if animation_tree:
		update_blend_smoothing(delta)
		
		# DEBUG: Print when values change significantly
		var speed_changed = abs(current_movement_speed - debug_last_speed) > 0.1
		var input_changed = current_input_direction.distance_to(debug_last_input) > 0.1
		
		if speed_changed or input_changed:
			print("🎬 Animation Debug: Speed=", current_movement_speed, " Input=", current_input_direction, " Active=", is_movement_active, " Blend=", current_blend_value)
			debug_last_speed = current_movement_speed
			debug_last_input = current_input_direction

func setup_action_listeners():
	"""Connect to action system for immediate animation updates"""
	if not action_system:
		return
	
	# Listen to action execution for immediate updates
	action_system.action_executed.connect(_on_action_executed)
	print("✅ AnimationController: Connected to action system")

# === ACTION SYSTEM INTEGRATION ===

func _on_action_executed(action: Action):
	"""Handle executed actions and update animations immediately"""
	match action.name:
		"move_start":
			handle_movement_start(action)
		"move_update":
			handle_movement_update(action)
		"move_end":
			handle_movement_end(action)
		"sprint_start", "sprint_end", "slow_walk_start", "slow_walk_end":
			handle_mode_change(action)

func handle_movement_start(action: Action):
	"""Handle start of movement - immediate animation response"""
	is_movement_active = true
	current_input_direction = action.get_movement_vector()
	
	# FORCE immediate speed update from character
	current_movement_speed = character.get_movement_speed()
	
	# If speed is still zero, use a minimum value to trigger animation
	if current_movement_speed < 0.1:
		current_movement_speed = 1.0  # Force minimum speed for animation
	
	update_animation_immediately()
	print("🎬 Animation: Movement started - Input:", current_input_direction, " Speed:", current_movement_speed)

func handle_movement_update(action: Action):
	"""Handle movement updates - smooth animation transitions"""
	current_input_direction = action.get_movement_vector()
	current_movement_speed = character.get_movement_speed()
	
	# Ensure we have movement speed when input is active
	if is_movement_active and current_movement_speed < 0.1:
		current_movement_speed = 1.0
	
	update_animation_immediately()

func handle_movement_end(_action: Action):
	"""Handle end of movement - return to idle"""
	is_movement_active = false
	current_input_direction = Vector2.ZERO
	current_movement_speed = 0.0
	update_animation_immediately()
	print("🎬 Animation: Movement ended - returning to idle")

func handle_mode_change(_action: Action):
	"""Handle movement mode changes (sprint/walk)"""
	current_movement_speed = character.get_movement_speed()
	update_animation_immediately()

func update_animation_immediately():
	"""Update animation targets immediately based on current action state"""
	if is_using_1d_blend_space():
		calculate_1d_blend_target()
	else:
		calculate_2d_blend_target()

# === BLEND SPACE CALCULATION (FIXED) ===

func calculate_1d_blend_target():
	"""Calculate 1D blend target based on action state"""
	if not is_movement_active:
		target_blend_value = 0.0
		return
	
	# FIXED: Use input magnitude instead of relying on character speed
	var input_magnitude = current_input_direction.length()
	
	if input_magnitude < 0.1:
		target_blend_value = 0.0
		return
	
	# Use character mode to determine animation
	if character.is_running:
		target_blend_value = 0.5  # Run animation
	elif character.is_slow_walking:
		target_blend_value = -0.5  # Slow walk animation
	else:
		target_blend_value = -0.2  # Normal walk animation
	
	print("🎬 1D Blend calculated: ", target_blend_value, " (Running: ", character.is_running, ", Slow: ", character.is_slow_walking, ")")

func calculate_2d_blend_target():
	"""Calculate 2D blend target based on action state"""
	if not is_movement_active:
		target_blend_vector = Vector2.ZERO
		return
	
	# FIXED: Use input direction directly
	var input_magnitude = current_input_direction.length()
	
	if input_magnitude < 0.1:
		target_blend_vector = Vector2.ZERO
		return
	
	# Map input to blend space coordinates
	target_blend_vector.x = current_input_direction.x * 1.0  # Strafe amount
	target_blend_vector.y = -current_input_direction.y * 1.0  # Forward/back amount
	
	# Scale by movement mode
	if character.is_running:
		target_blend_vector *= 1.5  # Running intensity
	elif character.is_slow_walking:
		target_blend_vector *= 0.5  # Slow walk intensity
	else:
		target_blend_vector *= 1.0  # Normal walk intensity
	
	print("🎬 2D Blend calculated: ", target_blend_vector, " from input: ", current_input_direction)

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

# === PUBLIC API FOR EXPRESSIONS (Enhanced for debugging) ===

func get_movement_speed() -> float:
	"""Public API for AnimationTree expressions"""
	var speed = current_movement_speed
	# DEBUG: Log when expressions ask for movement speed
	if speed > 0.1:
		print("📊 Expression queried movement_speed: ", speed)
	return speed

func is_on_floor() -> bool:
	return character.is_on_floor() if character else false

func is_grounded() -> bool:
	return is_on_floor()

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	return {
		"movement_speed": current_movement_speed,
		"input_direction": current_input_direction,
		"is_movement_active": is_movement_active,
		"blend_1d": current_blend_value,
		"blend_2d": current_blend_vector,
		"target_1d": target_blend_value,
		"target_2d": target_blend_vector,
		"is_1d_mode": is_using_1d_blend_space(),
		"action_system_connected": action_system != null,
		"character_running": character.is_running if character else false,
		"character_slow_walking": character.is_slow_walking if character else false
	}
