# TargetMovementComponent.gd - Click-to-move pathfinding movement
extends Node
class_name TargetMovementComponent

# === SIGNALS ===
signal navigation_started(destination: Vector3)
signal navigation_completed()
signal navigation_failed(reason: String)
signal path_updated(new_path: PackedVector3Array)

# === EXPORTS ===
@export_group("Required References")
@export var character_core: CharacterCore
@export var navigation_agent: NavigationAgent3D
@export var config_component: Node  # 3CConfigComponent

@export_group("Navigation Properties")
@export var arrival_threshold: float = 0.5
@export var enable_path_smoothing: bool = true
@export var enable_debug_output: bool = false

# === NAVIGATION STATE ===
var target_destination: Vector3 = Vector3.ZERO
var current_path: PackedVector3Array = PackedVector3Array()
var navigation_active: bool = false
var path_index: int = 0

func _ready():
	validate_setup()
	setup_navigation_agent()
	
	if enable_debug_output:
		print("TargetMovementComponent: Initialized")

func validate_setup():
	"""Validate required references"""
	if not character_core:
		push_error("TargetMovementComponent: character_core reference required")
	
	if not navigation_agent:
		push_error("TargetMovementComponent: navigation_agent reference required")
	
	if not config_component:
		push_error("TargetMovementComponent: config_component reference required")

func setup_navigation_agent():
	"""Setup navigation agent properties"""
	if not navigation_agent:
		return
	
	# Connect navigation agent signals
	navigation_agent.navigation_finished.connect(_on_navigation_finished)
	navigation_agent.target_reached.connect(_on_target_reached)
	navigation_agent.velocity_computed.connect(_on_velocity_computed)
	
	# Configure agent properties
	navigation_agent.path_desired_distance = 0.5
	navigation_agent.target_desired_distance = arrival_threshold
	navigation_agent.max_speed = get_config_value("run_speed", 6.0)

func _physics_process(delta):
	"""Process navigation movement"""
	if navigation_active and navigation_agent:
		process_navigation_movement(delta)

# === NAVIGATION CONTROL ===

func navigate_to_position(destination: Vector3):
	"""Start navigation to destination"""
	target_destination = destination
	
	if not navigation_agent:
		navigation_failed.emit("No navigation agent")
		return
	
	# Set navigation target
	navigation_agent.target_position = destination
	navigation_active = true
	
	# Get initial path
	await get_tree().process_frame  # Wait for navigation to update
	current_path = navigation_agent.get_current_navigation_path()
	path_index = 0
	
	navigation_started.emit(destination)
	path_updated.emit(current_path)
	
	if enable_debug_output:
		print("TargetMovementComponent: Navigation started to ", destination)
		print("TargetMovementComponent: Path length: ", current_path.size())

func cancel_navigation():
	"""Cancel current navigation"""
	navigation_active = false
	current_path.clear()
	path_index = 0
	
	if navigation_agent:
		navigation_agent.target_position = character_core.global_position
	
	if enable_debug_output:
		print("TargetMovementComponent: Navigation cancelled")

func process_navigation_movement(delta: float):
	"""Process movement along navigation path"""
	if not character_core or not navigation_agent:
		return
	
	# Check if we've reached the destination
	var distance_to_target = character_core.global_position.distance_to(target_destination)
	if distance_to_target <= arrival_threshold:
		complete_navigation()
		return
	
	# Get next position from navigation agent
	var next_position = navigation_agent.get_next_path_position()
	
	if next_position == Vector3.ZERO:
		navigation_failed.emit("Invalid path")
		return
	
	# Calculate movement direction
	var movement_direction = (next_position - character_core.global_position).normalized()
	movement_direction.y = 0  # Keep movement horizontal
	
	# Calculate movement speed
	var movement_speed = get_config_value("run_speed", 6.0)
	var movement_velocity = movement_direction * movement_speed
	
	# Apply movement to character
	character_core.apply_movement_velocity(movement_velocity)
	
	if enable_debug_output and movement_velocity.length() > 0:
		print("TargetMovementComponent: Moving towards ", next_position)

# === NAVIGATION CALLBACKS ===

func _on_navigation_finished():
	"""Called when navigation agent finishes"""
	complete_navigation()

func _on_target_reached():
	"""Called when navigation agent reaches target"""
	complete_navigation()

func _on_velocity_computed(safe_velocity: Vector3):
	"""Called when navigation agent computes safe velocity"""
	# Could use this for obstacle avoidance
	if enable_debug_output:
		print("TargetMovementComponent: Safe velocity computed: ", safe_velocity)

func complete_navigation():
	"""Complete the current navigation"""
	navigation_active = false
	current_path.clear()
	path_index = 0
	
	# Stop character movement
	if character_core:
		character_core.apply_movement_velocity(Vector3.ZERO)
	
	navigation_completed.emit()
	
	if enable_debug_output:
		print("TargetMovementComponent: Navigation completed")

# === PATH UTILITIES ===

func get_current_path() -> PackedVector3Array:
	"""Get current navigation path"""
	return current_path

func get_remaining_distance() -> float:
	"""Get remaining distance to destination"""
	if not navigation_agent or not navigation_active:
		return 0.0
	
	return navigation_agent.distance_to_target()

func is_path_valid() -> bool:
	"""Check if current path is valid"""
	return navigation_agent != null and navigation_agent.is_navigation_finished() == false

# === ADVANCED NAVIGATION ===

func set_navigation_speed(speed: float):
	"""Set navigation movement speed"""
	if navigation_agent:
		navigation_agent.max_speed = speed

func set_arrival_threshold(threshold: float):
	"""Set how close to destination counts as arrival"""
	arrival_threshold = threshold
	if navigation_agent:
		navigation_agent.target_desired_distance = threshold

func enable_obstacle_avoidance(enabled: bool):
	"""Enable/disable obstacle avoidance"""
	if navigation_agent:
		navigation_agent.avoidance_enabled = enabled

# === PUBLIC API ===

func is_navigating() -> bool:
	"""Check if currently navigating"""
	return navigation_active

func get_destination() -> Vector3:
	"""Get current navigation destination"""
	return target_destination

func get_progress() -> float:
	"""Get navigation progress (0.0 to 1.0)"""
	if not navigation_active or current_path.is_empty():
		return 0.0
	
	var total_distance = 0.0
	var traveled_distance = 0.0
	
	# Calculate total path distance
	for i in range(current_path.size() - 1):
		total_distance += current_path[i].distance_to(current_path[i + 1])
	
	# Calculate traveled distance
	var current_pos = character_core.global_position
	for i in range(path_index):
		if i < current_path.size() - 1:
			traveled_distance += current_path[i].distance_to(current_path[i + 1])
	
	# Add distance to current target
	if path_index < current_path.size():
		traveled_distance += current_pos.distance_to(current_path[path_index])
	
	return traveled_distance / total_distance if total_distance > 0 else 0.0

def force_complete_navigation():
	"""Force complete current navigation (for scripted sequences)"""
	complete_navigation()

# === CONFIGURATION ===

func get_config_value(property_name: String, default_value):
	"""Get configuration value safely"""
	if config_component and config_component.has_method("get_config_value"):
		return config_component.get_config_value(property_name, default_value)
	return default_value

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get debug information about target movement component"""
	return {
		"navigation_active": navigation_active,
		"destination": target_destination,
		"current_path_length": current_path.size(),
		"path_index": path_index,
		"remaining_distance": get_remaining_distance(),
		"progress": get_progress(),
		"arrival_threshold": arrival_threshold,
		"path_valid": is_path_valid(),
		"agent_max_speed": navigation_agent.max_speed if navigation_agent else 0.0
	}