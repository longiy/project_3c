# CharacterStateMachine.gd - ADD THESE LINES to existing script
extends StateMachine
class_name StateMachineCharacter

# ADD THIS: Resource configuration
@export_group("State Resources")
@export var grounded_state_resource: CharacterStateGroundedResource
@export var airborne_state_resource: CharacterStateAirborneResource

# Character-specific state tracking
var movement_state_history: Array[String] = []

# ADD THIS: Resource lookup
var state_resources: Dictionary = {}

func _ready():
	super._ready()
	
	# ADD THIS: Build resource lookup
	build_resource_lookup()
	
	# Connect to signals for character-specific logic
	state_changed.connect(_on_character_state_changed)

# ADD THIS: New method to build resource lookup
func build_resource_lookup():
	"""Build dictionary mapping state names to resources"""
	state_resources.clear()
	
	if grounded_state_resource:
		state_resources["grounded"] = grounded_state_resource
		print("📋 Registered grounded state resource: ", grounded_state_resource.display_name)
	
	if airborne_state_resource:
		state_resources["airborne"] = airborne_state_resource
		print("📋 Registered airborne state resource: ", airborne_state_resource.display_name)

# ADD THIS: Method for states to get their resources
func get_state_resource(state_name: String) -> CharacterState:
	"""Get resource for a specific state"""
	return state_resources.get(state_name, null)
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
	add_state("grounded", StateGrounded.new())
	add_state("airborne", StateAirborne.new())
	
	# Start in grounded state
	change_state("grounded")

func add_combat_states():
	"""Add combat states (future expansion)"""
	add_state("attacking", StateAttacking.new())
	add_state("blocking", StateBlocking.new()) 
	add_state("stunned", StateStunned.new())

func get_movement_state() -> String:
	"""Get current movement-related state"""
	var current = get_current_state_name()
	var movement_states = ["grounded", "airborne", "climbing", "swimming"]
	return current if current in movement_states else "unknown"
