extends Resource
class_name CharacterStateMachineConfig

@export_group("Core States")
@export var grounded_state: GroundedStateResource
@export var airborne_state: AirborneStateResource

@export_group("Combat States") 
@export var attacking_state: CharacterStateResource
@export var blocking_state: CharacterStateResource

@export_group("Environment States")
@export var swimming_state: CharacterStateResource
@export var climbing_state: CharacterStateResource

@export_group("State Machine Settings")
@export var starting_state: String = "grounded"
@export var enable_debug_logging: bool = false
@export var transition_history_size: int = 10
