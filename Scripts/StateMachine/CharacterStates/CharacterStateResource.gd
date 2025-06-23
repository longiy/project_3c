# Base resource for all character states
extends Resource
class_name CharacterStateResource

@export_group("State Identity")
@export var state_name: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""

@export_group("Movement Parameters")
@export var max_speed: float = 6.0
@export var acceleration: float = 15.0
@export var deceleration: float = 18.0
@export var air_control_multiplier: float = 0.3

@export_group("Debug & Timing")
@export var log_transitions: bool = true
@export var min_state_duration: float = 0.0
