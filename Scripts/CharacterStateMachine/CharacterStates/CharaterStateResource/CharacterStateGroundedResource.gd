extends CharacterState
class_name CharacterStateGroundedResource

@export_group("Grounded Specific")
@export var jump_velocity: float = 6.0
@export var coyote_time: float = 0.1
@export var max_jumps: int = 2
@export var slope_limit_degrees: float = 45.0

@export_group("Movement Modes")
@export var slow_walk_speed: float = 2.0
@export var walk_speed: float = 3.0  
@export var run_speed: float = 6.0
