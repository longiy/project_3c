# MovementStateManager.gd - Single source of truth for movement state
extends Node
class_name MovementStateManager

# === SIGNALS ===
signal movement_state_changed(is_moving: bool, direction: Vector2, magnitude: float)
signal movement_mode_changed(is_running: bool, is_slow_walking: bool)
signal speed_changed(new_speed: float)

# === MOVEMENT STATE ===
var is_movement_active: bool = false
var current_input_direction: Vector2 = Vector2.ZERO
var input_magnitude: float = 0.0

# === MOVEMENT MODES ===
var is_running: bool = false
var is_slow_walking: bool = false

# === INTERNAL STATE ===
var character: CharacterBody3D
var last_emitted_speed: float = 0.0
var last_emitted_mode_running: bool = false
var last_emitted_mode_slow: bool = false

# Deferred state changes to avoid race conditions
var pending_mode_changes: Dictionary = {}
var has_pending_changes: bool = false

func _ready():
	character = get_parent() as CharacterBody3D
	if not character:
		push_error("MovementStateManager must be child of CharacterBody3D")

func _physics_process(delta):
	# Apply any pending mode changes at start of physics frame
	apply_pending_mode_changes()
	
	# Emit speed changes
	emit_speed_changes()

# === ACTION INTERFACE ===

func handle_movement_action(action: Action):
	"""Handle movement actions - called by states"""
	match action.name:
		"move_start":
			set_movement_active(true, action.get_movement_vector(), action.context.get("magnitude", 0.0))
		"move_update":
			if is_movement_active:
				set_movement_direction(action.get_movement_vector(), action.context.get("magnitude", 0.0))
		"move_end":
			set_movement_active(false, Vector2.ZERO, 0.0)

func handle_mode_action(action: Action):
	"""Handle mode actions - deferred to avoid race conditions"""
	match action.name:
		"sprint_start":
			schedule_mode_change("running", true)
		"sprint_end":
			schedule_mode_change("running", false)
		"slow_walk_start":
			schedule_mode_change("slow_walking", true)
		"slow_walk_end":
			schedule_mode_change("slow_walking", false)

# === STATE MANAGEMENT ===

func set_movement_active(active: bool, direction: Vector2 = Vector2.ZERO, magnitude: float = 0.0):
	"""Set movement state and emit signals immediately"""
	var changed = is_movement_active != active
	
	is_movement_active = active
	current_input_direction = direction
	input_magnitude = magnitude
	
	if changed or direction != Vector2.ZERO:
		movement_state_changed.emit(active, direction, magnitude)

func set_movement_direction(direction: Vector2, magnitude: float):
	"""Update movement direction without changing active state"""
	current_input_direction = direction
	input_magnitude = magnitude
	movement_state_changed.emit(is_movement_active, direction, magnitude)

# === MODE MANAGEMENT (Deferred) ===

func schedule_mode_change(mode: String, value: bool):
	"""Schedule mode change for next physics frame"""
	pending_mode_changes[mode] = value
	has_pending_changes = true

func apply_pending_mode_changes():
	"""Apply all pending mode changes at once"""
	if not has_pending_changes:
		return
	
	var mode_changed = false
	
	if pending_mode_changes.has("running"):
		var new_running = pending_mode_changes["running"]
		if is_running != new_running:
			is_running = new_running
			mode_changed = true
	
	if pending_mode_changes.has("slow_walking"):
		var new_slow = pending_mode_changes["slow_walking"]
		if is_slow_walking != new_slow:
			is_slow_walking = new_slow
			mode_changed = true
	
	# Emit signal only if something actually changed
	if mode_changed:
		emit_movement_mode_changes()
	
	# Clear pending changes
	pending_mode_changes.clear()
	has_pending_changes = false

func emit_movement_mode_changes():
	"""Emit mode change signal if values changed"""
	if is_running != last_emitted_mode_running or is_slow_walking != last_emitted_mode_slow:
		last_emitted_mode_running = is_running
		last_emitted_mode_slow = is_slow_walking
		movement_mode_changed.emit(is_running, is_slow_walking)

func emit_speed_changes():
	"""Emit speed change signal if threshold exceeded"""
	if not character:
		return
		
	var current_speed = Vector3(character.velocity.x, 0, character.velocity.z).length()
	if abs(current_speed - last_emitted_speed) > 0.5:
		last_emitted_speed = current_speed
		speed_changed.emit(current_speed)

# === STATE QUERIES ===

func get_target_movement_state() -> String:
	"""Determine what state character should be in"""
	if not is_movement_active:
		return "idle"
	
	if is_running and not is_slow_walking:
		return "running"
	elif is_slow_walking and not is_running:
		return "walking"  # or "slow_walking" if you have that state
	else:
		return "walking"

func should_transition_to_state(current_state: String) -> String:
	"""Check if current state should transition"""
	var target_state = get_target_movement_state()
	return target_state if target_state != current_state else ""

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	return {
		"movement_active": is_movement_active,
		"input_direction": current_input_direction,
		"input_magnitude": input_magnitude,
		"is_running": is_running,
		"is_slow_walking": is_slow_walking,
		"pending_changes": pending_mode_changes,
		"target_state": get_target_movement_state(),
		"current_speed": Vector3(character.velocity.x, 0, character.velocity.z).length() if character else 0.0
	}
