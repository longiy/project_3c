# JumpSystem.gd - Handles all jump mechanics and timing
extends Node
class_name JumpSystem

@export_group("Jump Properties")
@export var jump_height = 6.0
@export var max_air_jumps = 1
@export var coyote_time = 0.15
@export var jump_buffer_time = 0.1

@export_group("Debug")
@export var enable_debug_logging = false

# Jump timing
var coyote_timer = 0.0
var jump_buffer_timer = 0.0
var jumps_remaining = 0

# Component references
var character: CharacterBody3D

func _ready():
	character = get_parent() as CharacterBody3D
	if not character:
		push_error("JumpSystem must be child of CharacterBody3D")
		return
	
	# Initialize jump count
	jumps_remaining = max_air_jumps + 1  # +1 for ground jump
	
	if enable_debug_logging:
		print("✅ JumpSystem: Initialized with ", max_air_jumps, " air jumps")

func _physics_process(delta):
	update_timers(delta)

func update_timers(delta):
	"""Update jump-related timers"""
	coyote_timer = max(0.0, coyote_timer - delta)
	jump_buffer_timer = max(0.0, jump_buffer_timer - delta)

# === PUBLIC API (Used by Character) ===

func can_jump() -> bool:
	"""Check if character can jump"""
	if not character:
		return false
	return (character.is_on_floor() or coyote_timer > 0) and jumps_remaining > 0

func can_air_jump() -> bool:
	"""Check if character can air jump"""
	if not character:
		return false
	return not character.is_on_floor() and jumps_remaining > 0

func handle_jump_input():
	"""Handle jump input with buffering"""
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time

func try_consume_jump_buffer() -> bool:
	"""Try to consume jump buffer if conditions are met"""
	if jump_buffer_timer > 0 and can_jump():
		jump_buffer_timer = 0.0
		return true
	return false

func perform_jump(jump_force: float):
	"""Execute a jump with given force"""
	if not character:
		return
	
	character.velocity.y = jump_force
	if jumps_remaining > 0:
		jumps_remaining -= 1
	
	if enable_debug_logging:
		print("🦘 Jump! Force: ", jump_force, " Remaining: ", jumps_remaining)

func update_ground_state():
	"""Update ground-related timers and jump counts"""
	if not character:
		return
	
	if character.is_on_floor():
		coyote_timer = coyote_time
		jumps_remaining = max_air_jumps + 1  # Reset jumps
	elif coyote_timer > 0 and was_grounded_last_frame():
		# Still in coyote time
		pass
	else:
		# Fully airborne
		pass

func was_grounded_last_frame() -> bool:
	"""Check if character was grounded in previous frame"""
	# This would need to be tracked, for now return false
	# Could be enhanced later to track ground state history
	return false

func reset_jump_state():
	"""Reset all jump-related state"""
	jumps_remaining = max_air_jumps + 1
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	
	if enable_debug_logging:
		print("🔄 JumpSystem: Reset jump state")

# === JUMP FORCE CALCULATION ===

func get_jump_force() -> float:
	"""Get standard jump force"""
	return jump_height

func get_air_jump_force() -> float:
	"""Get air jump force (typically weaker)"""
	return jump_height * 0.8

# === PUBLIC GETTERS ===

func get_jumps_remaining() -> int:
	"""Get number of jumps remaining"""
	return jumps_remaining

func get_coyote_timer() -> float:
	"""Get current coyote timer value"""
	return coyote_timer

func get_jump_buffer_timer() -> float:
	"""Get current jump buffer timer value"""
	return jump_buffer_timer

func get_max_jumps() -> int:
	"""Get maximum number of jumps (ground + air)"""
	return max_air_jumps + 1

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get jump system debug information"""
	return {
		"jump_height": jump_height,
		"max_air_jumps": max_air_jumps,
		"jumps_remaining": jumps_remaining,
		"coyote_timer": coyote_timer,
		"jump_buffer_timer": jump_buffer_timer,
		"can_jump": can_jump(),
		"can_air_jump": can_air_jump(),
		"is_grounded": character.is_on_floor() if character else false,
		"has_jump_buffer": jump_buffer_timer > 0
	}
