# CharacterActions.gd - Discrete action processing module
extends Node
class_name CharacterActions

# === SIGNALS ===
signal jump_performed(jump_force: float, jump_type: String)
signal action_started(action_name: String)
signal action_completed(action_name: String)

# === JUMP SETTINGS ===
@export_group("Jump Properties")
@export var jump_height = 6.0
@export var air_jump_height = 4.8
@export var max_air_jumps = 1
@export var coyote_time = 0.15
@export var jump_buffer_time = 0.1

@export_group("Debug")
@export var enable_debug_logging = false

# === COMPONENT REFERENCES ===
var character: CharacterBody3D
var physics_module: CharacterPhysics

# === JUMP STATE ===
var has_ground_jump: bool = true
var air_jumps_remaining: int = 0
var coyote_timer = 0.0
var jump_buffer_timer = 0.0

# === ACTION STATE ===
var active_actions: Array[String] = []
var action_cooldowns: Dictionary = {}

func _ready():
	character = get_parent() as CharacterBody3D
	if not character:
		push_error("CharacterActions must be child of CharacterBody3D")
		return
	
	setup_actions()
	connect_physics_signals()

func setup_actions():
	"""Initialize action systems"""
	# Initialize jump state
	has_ground_jump = true
	air_jumps_remaining = max_air_jumps
	
	if enable_debug_logging:
		print("✅ CharacterActions: Initialized - Ground: ", has_ground_jump, " Air: ", air_jumps_remaining)

func connect_physics_signals():
	"""Connect to physics module signals"""
	# Find physics module
	physics_module = character.get_node_or_null("CharacterPhysics")
	if physics_module and physics_module.has_signal("ground_state_changed"):
		physics_module.ground_state_changed.connect(_on_ground_state_changed)
	else:
		# Fallback to character signal if physics module not found
		if character.has_signal("ground_state_changed"):
			character.ground_state_changed.connect(_on_ground_state_changed)

func _physics_process(delta):
	update_action_timers(delta)
	process_jump_buffer()

# === TIMER MANAGEMENT ===

func update_action_timers(delta):
	"""Update all action-related timers"""
	update_jump_timers(delta)
	update_action_cooldowns(delta)

func update_jump_timers(delta):
	"""Update jump-related timers"""
	coyote_timer = max(0.0, coyote_timer - delta)
	jump_buffer_timer = max(0.0, jump_buffer_timer - delta)
	
	# Ground jump expires when coyote time runs out
	if coyote_timer <= 0 and has_ground_jump and character and not is_grounded():
		has_ground_jump = false
		if enable_debug_logging:
			print("⏰ Coyote time expired - Ground jump lost!")

func update_action_cooldowns(delta):
	"""Update action cooldown timers"""
	for action in action_cooldowns.keys():
		action_cooldowns[action] = max(0.0, action_cooldowns[action] - delta)

func process_jump_buffer():
	"""Process buffered jump input"""
	if jump_buffer_timer > 0 and can_jump_at_all():
		perform_jump()
		jump_buffer_timer = 0.0

# === SIGNAL HANDLERS ===

func _on_ground_state_changed(is_grounded: bool):
	"""Handle ground state changes from physics module"""
	if is_grounded:
		# Landed - reset all jumps
		has_ground_jump = true
		air_jumps_remaining = max_air_jumps
		coyote_timer = coyote_time
		
		if enable_debug_logging:
			print("🏁 Landed! Jumps reset - Ground: ", has_ground_jump, " Air: ", air_jumps_remaining)
	else:
		# Left ground - start coyote timer if we still have ground jump
		if has_ground_jump:
			coyote_timer = coyote_time
			if enable_debug_logging:
				print("🕰️ Left ground - Coyote time started: ", coyote_timer)

# === JUMP SYSTEM ===

func can_jump() -> bool:
	"""Check if character can use ground jump (including coyote time)"""
	if not character:
		return false
	
	return has_ground_jump and (is_grounded() or coyote_timer > 0)

func can_air_jump() -> bool:
	"""Check if character can use air jump"""
	if not character:
		return false
	
	return not is_grounded() and coyote_timer <= 0 and air_jumps_remaining > 0

func can_jump_at_all() -> bool:
	"""Check if any type of jump is available"""
	return can_jump() or can_air_jump()

func handle_jump_input():
	"""Handle jump input with buffering"""
	jump_buffer_timer = jump_buffer_time
	
	if enable_debug_logging:
		print("🎮 Jump input buffered - Timer: ", jump_buffer_timer)

func get_appropriate_jump_force() -> float:
	"""Get the correct jump force based on current state"""
	if can_jump():
		return jump_height
	elif can_air_jump():
		return air_jump_height
	else:
		return 0.0

func perform_jump(jump_force: float = 0.0):
	"""Execute a jump - determines type automatically if no force given"""
	if not character:
		if enable_debug_logging:
			print("❌ Cannot jump - invalid character reference")
		return
	
	# Auto-determine jump type and force if not specified
	if jump_force <= 0.0:
		jump_force = get_appropriate_jump_force()
	
	if jump_force <= 0.0:
		if enable_debug_logging:
			print("❌ No jump available!")
		return
	
	# Apply jump force via physics module or directly
	if physics_module:
		physics_module.set_vertical_velocity(jump_force)
	else:
		character.velocity.y = jump_force
	
	# Determine and consume the correct jump type
	var jump_type = ""
	if can_jump():
		# Ground or coyote jump
		has_ground_jump = false
		coyote_timer = 0.0
		jump_type = "ground" if is_grounded() else "coyote"
	elif can_air_jump():
		# Air jump
		air_jumps_remaining -= 1
		jump_type = "air"
	
	# Emit signals
	jump_performed.emit(jump_force, jump_type)
	action_started.emit("jump")
	
	if enable_debug_logging:
		print("🦘 ", jump_type.capitalize(), " jump! Force: ", jump_force, 
			  " | Ground: ", has_ground_jump, " Air: ", air_jumps_remaining)

# === GENERAL ACTION SYSTEM ===

func can_perform_action(action_name: String) -> bool:
	"""Check if action can be performed"""
	# Check if action is on cooldown
	if action_cooldowns.get(action_name, 0.0) > 0:
		return false
	
	# Check if action is already active
	if action_name in active_actions:
		return false
	
	# Action-specific checks
	match action_name:
		"jump":
			return can_jump_at_all()
		"dash":
			return can_dash()  # Future implementation
		"interact":
			return can_interact()  # Future implementation
		_:
			return true

func start_action(action_name: String, duration: float = 0.0):
	"""Start a discrete action"""
	if not can_perform_action(action_name):
		return false
	
	active_actions.append(action_name)
	action_started.emit(action_name)
	
	# If action has duration, schedule completion
	if duration > 0:
		await get_tree().create_timer(duration).timeout
		complete_action(action_name)
	
	return true

func complete_action(action_name: String):
	"""Complete and cleanup an action"""
	if action_name in active_actions:
		active_actions.erase(action_name)
		action_completed.emit(action_name)

func set_action_cooldown(action_name: String, cooldown_time: float):
	"""Set cooldown for an action"""
	action_cooldowns[action_name] = cooldown_time

# === FUTURE ACTION PLACEHOLDERS ===

func can_dash() -> bool:
	"""Check if dash is available - Future implementation"""
	return false

func can_interact() -> bool:
	"""Check if interaction is available - Future implementation"""
	return false

func perform_dash():
	"""Perform dash action - Future implementation"""
	pass

func perform_interact():
	"""Perform interaction - Future implementation"""
	pass

# === UTILITY FUNCTIONS ===

func is_grounded() -> bool:
	"""Check if character is grounded"""
	if physics_module:
		return physics_module.is_grounded()
	else:
		return character.is_on_floor()

func reset_jump_state():
	"""Reset all jump-related state"""
	has_ground_jump = true
	air_jumps_remaining = max_air_jumps
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	
	if enable_debug_logging:
		print("🔄 CharacterActions: Reset jump state")

func reset_all_actions():
	"""Reset all action states"""
	reset_jump_state()
	active_actions.clear()
	action_cooldowns.clear()

# === GETTERS ===

func get_jumps_remaining() -> int:
	"""Get total number of jumps remaining"""
	var total = 0
	if has_ground_jump:
		total += 1
	total += air_jumps_remaining
	return total

func get_ground_jumps_remaining() -> int:
	"""Get ground jumps remaining (0 or 1)"""
	return 1 if has_ground_jump else 0

func get_air_jumps_remaining() -> int:
	"""Get air jumps remaining"""
	return air_jumps_remaining

func get_coyote_timer() -> float:
	"""Get current coyote timer value"""
	return coyote_timer

func get_jump_buffer_timer() -> float:
	"""Get current jump buffer timer value"""
	return jump_buffer_timer

func is_in_coyote_time() -> bool:
	"""Check if currently in coyote time"""
	return coyote_timer > 0 and not is_grounded()

func is_action_active(action_name: String) -> bool:
	"""Check if action is currently active"""
	return action_name in active_actions

func get_action_cooldown(action_name: String) -> float:
	"""Get remaining cooldown time for action"""
	return action_cooldowns.get(action_name, 0.0)

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get action system debug information"""
	return {
		"jump_height": jump_height,
		"air_jump_height": air_jump_height,
		"max_air_jumps": max_air_jumps,
		"has_ground_jump": has_ground_jump,
		"air_jumps_remaining": air_jumps_remaining,
		"total_jumps_remaining": get_jumps_remaining(),
		"coyote_timer": coyote_timer,
		"jump_buffer_timer": jump_buffer_timer,
		"can_jump": can_jump(),
		"can_air_jump": can_air_jump(),
		"can_jump_at_all": can_jump_at_all(),
		"is_grounded": is_grounded(),
		"is_in_coyote_time": is_in_coyote_time(),
		"has_jump_buffer": jump_buffer_timer > 0,
		"active_actions": active_actions,
		"action_cooldowns": action_cooldowns,
		"appropriate_jump_force": get_appropriate_jump_force()
	}
