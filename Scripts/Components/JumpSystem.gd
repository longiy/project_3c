# JumpSystem.gd - FIXED: Signal-driven, proper air jump handling
extends Node
class_name JumpSystem

@export_group("Jump Properties")
@export var jump_height = 6.0
@export var air_jump_height = 4.8  # Slightly weaker air jumps
@export var max_air_jumps = 1
@export var coyote_time = 0.15
@export var jump_buffer_time = 0.1

@export_group("Debug")
@export var enable_debug_logging = false

# Jump state
var has_ground_jump: bool = true
var air_jumps_remaining: int = 0
var coyote_timer = 0.0
var jump_buffer_timer = 0.0

# Component references
var character: CharacterBody3D

func _ready():
	character = get_parent() as CharacterBody3D
	if not character:
		push_error("JumpSystem must be child of CharacterBody3D")
		return
	
	# Initialize jump state
	has_ground_jump = true
	air_jumps_remaining = max_air_jumps
	
	# FIXED: Connect to character's ground state signal instead of polling
	if character.has_signal("ground_state_changed"):
		character.ground_state_changed.connect(_on_ground_state_changed)
	else:
		push_warning("Character missing ground_state_changed signal - jump system may not work correctly")
	
	if enable_debug_logging:
		print("✅ JumpSystem: Initialized - Ground: ", has_ground_jump, " Air: ", air_jumps_remaining)

func _physics_process(delta):
	update_timers(delta)

func update_timers(delta):
	"""Update jump-related timers"""
	coyote_timer = max(0.0, coyote_timer - delta)
	jump_buffer_timer = max(0.0, jump_buffer_timer - delta)
	
	# FIXED: Ground jump expires when coyote time runs out
	if coyote_timer <= 0 and has_ground_jump and character and is_instance_valid(character) and not character.is_on_floor():
		has_ground_jump = false
		if enable_debug_logging:
			print("⏰ Coyote time expired - Ground jump lost!")

# === SIGNAL HANDLERS ===

func _on_ground_state_changed(is_grounded: bool):
	"""Handle ground state changes from character"""
	if is_grounded:
		# Landed - reset all jumps
		has_ground_jump = true
		air_jumps_remaining = max_air_jumps
		coyote_timer = coyote_time  # Always have coyote time when grounded
		
		if enable_debug_logging:
			print("🏁 Landed! Jumps reset - Ground: ", has_ground_jump, " Air: ", air_jumps_remaining)
	else:
		# Left ground - start coyote timer if we still have ground jump
		if has_ground_jump:
			coyote_timer = coyote_time
			if enable_debug_logging:
				print("🕰️ Left ground - Coyote time started: ", coyote_timer)

# === PUBLIC API ===

func can_jump() -> bool:
	"""Check if character can use ground jump (including coyote time)"""
	if not character or not is_instance_valid(character):
		return false
	
	# Can use ground jump if: have ground jump AND (grounded OR in coyote time)
	return has_ground_jump and (character.is_on_floor() or coyote_timer > 0)

func can_air_jump() -> bool:
	"""Check if character can use air jump"""
	if not character or not is_instance_valid(character):
		return false
	
	# Can air jump if: not grounded AND no coyote time AND have air jumps
	return not character.is_on_floor() and coyote_timer <= 0 and air_jumps_remaining > 0

func can_jump_at_all() -> bool:
	"""Check if any type of jump is available"""
	return can_jump() or can_air_jump()

func handle_jump_input():
	"""Handle jump input with buffering"""
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
		
		if enable_debug_logging:
			print("🎮 Jump input buffered - Timer: ", jump_buffer_timer)

func try_consume_jump_buffer() -> bool:
	"""Try to consume jump buffer if conditions are met"""
	if jump_buffer_timer > 0 and can_jump_at_all():
		jump_buffer_timer = 0.0
		return true
	return false

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
	if not character or not is_instance_valid(character):
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
	
	# Apply jump force
	character.velocity.y = jump_force
	
	# FIXED: Consume the correct jump type
	if can_jump():
		# Ground or coyote jump
		has_ground_jump = false
		coyote_timer = 0.0  # Clear coyote time since we used the ground jump
		
		if enable_debug_logging:
			var jump_type = "ground" if character.is_on_floor() else "coyote"
			print("🦘 ", jump_type.capitalize(), " jump! Force: ", jump_force, 
				  " | Ground: ", has_ground_jump, " Air: ", air_jumps_remaining)
	
	elif can_air_jump():
		# Air jump
		air_jumps_remaining -= 1
		
		if enable_debug_logging:
			print("🦘 Air jump! Force: ", jump_force, 
				  " | Ground: ", has_ground_jump, " Air: ", air_jumps_remaining)

# === MANUAL GROUND STATE UPDATE (Fallback) ===

func update_ground_state():
	"""Manual ground state update - used as fallback if signals don't work"""
	if not character or not is_instance_valid(character):
		return
		
	# This is now mainly for compatibility - signals should handle most cases
	if character.is_on_floor() and not has_ground_jump:
		# Edge case: landed but signal didn't fire
		_on_ground_state_changed(true)

func reset_jump_state():
	"""Reset all jump-related state"""
	has_ground_jump = true
	air_jumps_remaining = max_air_jumps
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	
	if enable_debug_logging:
		print("🔄 JumpSystem: Reset jump state")

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

func get_max_jumps() -> int:
	"""Get maximum number of jumps (ground + air)"""
	return 1 + max_air_jumps

func is_in_coyote_time() -> bool:
	"""Check if currently in coyote time"""
	return coyote_timer > 0 and not character.is_on_floor()

# === JUMP FORCE GETTERS ===

func get_jump_force() -> float:
	"""Get standard ground jump force"""
	return jump_height

func get_air_jump_force() -> float:
	"""Get air jump force"""
	return air_jump_height

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get jump system debug information"""
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
		"appropriate_jump_force": get_appropriate_jump_force()
	}
