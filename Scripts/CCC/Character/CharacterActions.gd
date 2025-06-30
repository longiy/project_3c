# CharacterActions.gd - Character actions processing module (integrates JumpSystem)
extends Node
class_name CharacterActions

# === SIGNALS ===
signal jump_performed(jump_force: float, is_air_jump: bool)
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

# === CHARACTER REFERENCE ===
var character: CharacterBody3D

# === JUMP STATE (Integrated from JumpSystem) ===
var has_ground_jump: bool = true
var air_jumps_remaining: int = 0
var coyote_timer = 0.0
var jump_buffer_timer = 0.0

# === ACTION STATE ===
var active_actions: Dictionary = {}

func setup_character_reference(char: CharacterBody3D):
	"""Setup character reference"""
	character = char
	
	# Initialize jump state
	has_ground_jump = true
	air_jumps_remaining = max_air_jumps
	
	if enable_debug_logging:
		print("✅ CharacterActions: Initialized - Ground: ", has_ground_jump, " Air: ", air_jumps_remaining)

func _physics_process(delta):
	update_action_timers(delta)

func update_action_timers(delta: float):
	"""Update action-related timers"""
	coyote_timer = max(0.0, coyote_timer - delta)
	jump_buffer_timer = max(0.0, jump_buffer_timer - delta)
	
	# Ground jump expires when coyote time runs out
	if coyote_timer <= 0 and has_ground_jump and character and not character.is_on_floor():
		has_ground_jump = false
		if enable_debug_logging:
			print("⏰ CharacterActions: Coyote time expired - Ground jump lost!")

# === GROUND STATE INTEGRATION ===

func _on_ground_state_changed(is_grounded: bool):
	"""Handle ground state changes from physics module"""
	if is_grounded:
		# Landed - reset all jumps
		has_ground_jump = true
		air_jumps_remaining = max_air_jumps
		coyote_timer = coyote_time
		
		if enable_debug_logging:
			print("🏁 CharacterActions: Landed! Jumps reset - Ground: ", has_ground_jump, " Air: ", air_jumps_remaining)
	else:
		# Left ground - start coyote timer if we still have ground jump
		if has_ground_jump:
			coyote_timer = coyote_time
			if enable_debug_logging:
				print("🕰️ CharacterActions: Left ground - Coyote time started: ", coyote_timer)

# === JUMP SYSTEM ===

func can_jump() -> bool:
	"""Check if character can use ground jump (including coyote time)"""
	if not character:
		return false
	
	return has_ground_jump and (character.is_on_floor() or coyote_timer > 0)

func can_air_jump() -> bool:
	"""Check if character can use air jump"""
	if not character:
		return false
	
	return not character.is_on_floor() and coyote_timer <= 0 and air_jumps_remaining > 0

func can_jump_at_all() -> bool:
	"""Check if any type of jump is available"""
	return can_jump() or can_air_jump()

func perform_jump(jump_force: float = 0.0):
	"""Execute a jump - determines type automatically if no force given"""
	if not character:
		if enable_debug_logging:
			print("❌ CharacterActions: Cannot jump - invalid character reference")
		return
	
	# Auto-determine jump type and force if not specified
	if jump_force <= 0.0:
		jump_force = get_appropriate_jump_force()
	
	if jump_force <= 0.0:
		if enable_debug_logging:
			print("❌ CharacterActions: No jump available!")
		return
	
	# Apply jump force
	character.velocity.y = jump_force
	
	# Consume the correct jump type
	var is_air_jump = false
	if can_jump():
		# Ground or coyote jump
		has_ground_jump = false
		coyote_timer = 0.0
		
		if enable_debug_logging:
			var jump_type = "ground" if character.is_on_floor() else "coyote"
			print("🦘 CharacterActions: ", jump_type.capitalize(), " jump! Force: ", jump_force)
	
	elif can_air_jump():
		# Air jump
		air_jumps_remaining -= 1
		is_air_jump = true
		
		if enable_debug_logging:
			print("🦘 CharacterActions: Air jump! Force: ", jump_force, " | Remaining: ", air_jumps_remaining)
	
	# Emit signals
	jump_performed.emit(jump_force, is_air_jump)
	action_started.emit("jump")

func get_appropriate_jump_force() -> float:
	"""Get the correct jump force based on current state"""
	if can_jump():
		return jump_height
	elif can_air_jump():
		return air_jump_height
	else:
		return 0.0

# === JUMP BUFFER SYSTEM ===

func handle_jump_input():
	"""Handle jump input with buffering"""
	jump_buffer_timer = jump_buffer_time
	
	if enable_debug_logging:
		print("🎮 CharacterActions: Jump input buffered - Timer: ", jump_buffer_timer)

func try_consume_jump_buffer() -> bool:
	"""Try to consume jump buffer if conditions are met"""
	if jump_buffer_timer > 0 and can_jump_at_all():
		jump_buffer_timer = 0.0
		return true
	return false

# === FUTURE ACTIONS FRAMEWORK ===

func start_action(action_name: String, duration: float = 0.0):
	"""Start a timed action"""
	active_actions[action_name] = {
		"start_time": Time.get_ticks_msec() / 1000.0,
		"duration": duration
	}
	
	action_started.emit(action_name)

func end_action(action_name: String):
	"""End an active action"""
	if active_actions.has(action_name):
		active_actions.erase(action_name)
		action_completed.emit(action_name)

func is_action_active(action_name: String) -> bool:
	"""Check if an action is currently active"""
	return active_actions.has(action_name)

# === ACTIONS RESET ===

func reset_actions():
	"""Reset all action state"""
	has_ground_jump = true
	air_jumps_remaining = max_air_jumps
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	active_actions.clear()
	
	if enable_debug_logging:
		print("🔄 CharacterActions: All actions reset")

# === CONFIGURATION ===

func set_jump_properties(height: float, air_height: float, max_air: int):
	"""Update jump properties"""
	jump_height = height
	air_jump_height = air_height
	max_air_jumps = max_air
	air_jumps_remaining = max_air_jumps

func set_jump_timing(coyote: float, buffer: float):
	"""Update jump timing properties"""
	coyote_time = coyote
	jump_buffer_time = buffer

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get actions debug information"""
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
		"is_grounded": character.is_on_floor() if character else false,
		"is_in_coyote_time": is_in_coyote_time(),
		"has_jump_buffer": jump_buffer_timer > 0,
		"appropriate_jump_force": get_appropriate_jump_force(),
		"active_actions": active_actions.keys(),
		"active_action_count": active_actions.size()
	}

func get_jumps_remaining() -> int:
	"""Get total number of jumps remaining"""
	var total = 0
	if has_ground_jump:
		total += 1
	total += air_jumps_remaining
	return total

func is_in_coyote_time() -> bool:
	"""Check if currently in coyote time"""
	return coyote_timer > 0 and character and not character.is_on_floor()
