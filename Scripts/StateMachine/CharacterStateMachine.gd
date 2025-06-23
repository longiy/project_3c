# CharacterStateMachine.gd - Specialized for character controller
extends StateMachine
class_name CharacterStateMachine

# Character-specific state tracking
var movement_state_history: Array[String] = []

func _ready():
	super._ready()
	
	# Connect to signals for character-specific logic
	state_changed.connect(_on_character_state_changed)

func _on_character_state_changed(old_state: String, new_state: String):
	"""Handle character-specific state changes"""
	
	# Track movement states separately
	var movement_states = ["grounded", "airborne", "climbing", "swimming"]
	if new_state in movement_states:
		movement_state_history.append(new_state)
		if movement_state_history.size() > 5:
			movement_state_history.pop_front()
	
	# Emit character-specific signals that other systems can listen to
	var character = owner_node as CharacterBody3D
	if character.has_signal("character_state_changed"):
		character.character_state_changed.emit(old_state, new_state)

func setup_basic_states():
	"""Setup the basic movement states"""
	add_state("grounded", GroundedState.new())
	add_state("airborne", AirborneState.new())
	
	# Start in grounded state
	change_state("grounded")
	
	print("🏃 Character states initialized")

func add_combat_states():
	"""Add combat states (future expansion)"""
	add_state("attacking", AttackingState.new())
	add_state("blocking", BlockingState.new()) 
	add_state("stunned", StunnedState.new())
	
	print("⚔️ Combat states added")

func get_movement_state() -> String:
	"""Get current movement-related state"""
	var current = get_current_state_name()
	var movement_states = ["grounded", "airborne", "climbing", "swimming"]
	return current if current in movement_states else "unknown"
