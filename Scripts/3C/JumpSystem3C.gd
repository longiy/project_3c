# JumpSystem3C.gd - 3C Compatible Jump System
extends Node
class_name JumpSystem3C

@export_group("Base Jump Properties")
@export var base_jump_height = 6.0
@export var base_air_jump_height = 4.8
@export var max_air_jumps = 1
@export var coyote_time = 0.15
@export var jump_buffer_time = 0.1

@export_group("Debug")
@export var enable_debug_logging = false

# 3C Configuration
var active_3c_config: CharacterConfig

# Jump state
var has_ground_jump: bool = true
var air_jumps_remaining: int = 0
var coyote_timer = 0.0
var jump_buffer_timer = 0.0

# Component references
var character: Character3CManager

func _ready():
	character = get_parent() as Character3CManager
	if not character:
		push_error("JumpSystem3C must be child of Character3CManager")
		return
	
	# Initialize jump state
	has_ground_jump = true
	air_jumps_remaining = max_air_jumps
	
	# Connect to character's ground state signal
	if character.has_signal("ground_state_changed"):
		character.ground_state_changed.connect(_on_ground_state_changed)
	else:
		push_warning("Character missing ground_state_changed signal - jump system may not work correctly")
	
	if enable_debug_logging:
		print("✅ JumpSystem3C: Initialized - Ground: ", has_ground_jump, " Air: ", air_jumps_remaining)

func configure_from_3c(config: CharacterConfig):
	"""Configure jump system based on 3C settings"""
	active_3c_config = config
	
	# Adjust jump characteristics based on character type
	match config.character_type:
		CharacterConfig.CharacterType.AVATAR:
			# Responsive, embodied jumping
			configure_avatar_jumping()
		CharacterConfig.CharacterType.CONTROLLER:
			# Tool-like, precise jumping
			configure_controller_jumping()
		CharacterConfig.CharacterType.OBSERVER:
			# Minimal or no jumping
			configure_observer_jumping()
		CharacterConfig.CharacterType.COLLABORATOR:
			# Adaptive jumping
			configure_collaborator_jumping()

func configure_avatar_jumping():
	"""Configure for avatar-style embodied jumping"""
	# Full responsiveness, natural feel
	pass

func configure_controller_jumping():
	"""Configure for controller-style tool jumping"""
	# More predictable, less floaty
	pass

func configure_observer_jumping():
	"""Configure for observer-style minimal jumping"""
	# Very limited or no jumping capability
	pass

func configure_collaborator_jumping():
	"""Configure for collaborative adaptive jumping"""
	# Context-sensitive jump behavior
	pass

func _physics_process(delta):
	update_timers(delta)

func update_timers(delta):
	"""Update jump-related timers"""
	coyote_timer = max(0.0, coyote_timer - delta)
	jump_buffer_timer = max(0.0, jump_buffer_timer - delta)
	
	# Ground jump expires when coyote time runs out
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
		coyote_timer = coyote_time
		
		if enable_debug_logging:
			print("🏁 Landed! Jumps restored - Ground: ", has_ground_jump, " Air: ", air_jumps_remaining)
	else:
		# Left ground - start coyote timer if we had ground jump
		if has_ground_jump:
			coyote_timer = coyote_time
			if enable_debug_logging:
				print("🕰️ Left ground - Coyote time started!")

# === JUMP EXECUTION ===

func can_jump() -> bool:
	"""Check if can perform ground/coyote jump"""
	if not character or not is_instance_valid(character):
		return false
	
	return has_ground_jump or (coyote_timer > 0 and not character.is_on_floor())

func can_air_jump() -> bool:
	"""Check if can perform air jump"""
	if not character or not is_instance_valid(character):
		return false
	
	return air_jumps_remaining > 0 and not character.is_on_floor()

func can_jump_at_all() -> bool:
	"""Check if any type of jump is possible"""
	return can_jump() or can_air_jump()

func perform_jump():
	"""Execute a jump with 3C configuration"""
	if not active_3c_config:
		push_warning("JumpSystem3C: No 3C config - using defaults")
		execute_basic_jump()
		return
	
	var jump_force = get_appropriate_jump_force()
	execute_jump_with_force(jump_force)

func execute_basic_jump():
	"""Execute jump without 3C configuration"""
	if can_jump():
		var force = base_jump_height
		character.velocity.y = force
		has_ground_jump = false
		coyote_timer = 0.0
	elif can_air_jump():
		var force = base_air_jump_height
		character.velocity.y = force
		air_jumps_remaining -= 1

func execute_jump_with_force(jump_force: float):
	"""Execute jump with specific force"""
	if can_jump():
		# Ground or coyote jump
		character.velocity.y = jump_force
		has_ground_jump = false
		coyote_timer = 0.0
		
		if enable_debug_logging:
			print("🦘 Ground jump! Force: ", jump_force)
			
	elif can_air_jump():
		# Air jump
		var air_force = jump_force * get_air_jump_multiplier()
		character.velocity.y = air_force
		air_jumps_remaining -= 1
		
		if enable_debug_logging:
			print("🦘 Air jump! Force: ", air_force, " (Air remaining: ", air_jumps_remaining, ")")

func get_appropriate_jump_force() -> float:
	"""Get jump force based on 3C configuration"""
	if not active_3c_config:
		return base_jump_height
	
	var base_force = active_3c_config.jump_height
	var responsiveness = active_3c_config.character_responsiveness
	var embodiment = active_3c_config.character_embodiment_quality
	
	# Calculate final jump force based on 3C parameters
	var final_force = base_force * responsiveness
	
	# Character type modifiers
	match active_3c_config.character_type:
		CharacterConfig.CharacterType.AVATAR:
			# Full force, responsive
			final_force *= embodiment
		CharacterConfig.CharacterType.CONTROLLER:
			# Consistent, predictable
			final_force *= 0.9
		CharacterConfig.CharacterType.OBSERVER:
			# Minimal jumping
			final_force *= 0.3
		CharacterConfig.CharacterType.COLLABORATOR:
			# Context adaptive
			final_force *= (responsiveness + embodiment) / 2.0
	
	return final_force

func get_air_jump_multiplier() -> float:
	"""Get multiplier for air jumps based on 3C config"""
	if not active_3c_config:
		return 0.8  # Default air jump is 80% of ground jump
	
	# Air control affects air jump strength
	return 0.6 + (active_3c_config.air_control * 0.4)

# === UTILITY METHODS ===

func reset_jump_state():
	"""Reset all jump-related state"""
	has_ground_jump = true
	air_jumps_remaining = max_air_jumps
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	
	if enable_debug_logging:
		print("🔄 JumpSystem3C: Reset jump state")

func get_jumps_remaining() -> int:
	"""Get total number of jumps remaining"""
	var total = 0
	if has_ground_jump or coyote_timer > 0:
		total += 1
	total += air_jumps_remaining
	return total

func get_debug_info() -> Dictionary:
	"""Get comprehensive debug information"""
	return {
		"3c_configured": active_3c_config != null,
		"character_type": CharacterConfig.CharacterType.keys()[active_3c_config.character_type] if active_3c_config else "none",
		"configured_jump_height": active_3c_config.jump_height if active_3c_config else base_jump_height,
		"character_responsiveness": active_3c_config.character_responsiveness if active_3c_config else 1.0,
		"character_embodiment": active_3c_config.character_embodiment_quality if active_3c_config else 1.0,
		"calculated_jump_force": get_appropriate_jump_force(),
		"air_jump_multiplier": get_air_jump_multiplier(),
		"has_ground_jump": has_ground_jump,
		"air_jumps_remaining": air_jumps_remaining,
		"total_jumps_remaining": get_jumps_remaining(),
		"coyote_timer": coyote_timer,
		"jump_buffer_timer": jump_buffer_timer,
		"can_jump": can_jump(),
		"can_air_jump": can_air_jump(),
		"can_jump_at_all": can_jump_at_all(),
		"is_grounded": character.is_on_floor() if character else false,
		"is_in_coyote_time": coyote_timer > 0 and not character.is_on_floor()
	}
