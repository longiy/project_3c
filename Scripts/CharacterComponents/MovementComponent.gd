# MovementComponent.gd
# Handles character physics movement with NavigationMesh debugging

extends Node
class_name MovementComponent

# Movement properties
@export_group("Movement Speeds")
@export var walk_speed: float = 4.0
@export var run_speed: float = 6.0
@export var sprint_speed: float = 8.0

@export_group("Physics")
@export var acceleration: float = 8.0
@export var deceleration: float = 10.0
@export var gravity: float = 9.8
@export var jump_velocity: float = 4.5

@export_group("Navigation")
@export var navigation_speed: float = 6.0
@export var destination_threshold: float = 0.5
@export var use_navigation_mesh: bool = true
@export var debug_navigation: bool = true

# Internal state
var character_core: CharacterBody3D
var current_direction: Vector2 = Vector2.ZERO
var target_direction: Vector2 = Vector2.ZERO
var current_speed: float = 0.0
var target_speed: float = 0.0

# Movement state
var is_sprinting: bool = false
var is_walking: bool = false
var is_jumping: bool = false
var is_navigating: bool = false

# Navigation properties
@onready var nav_agent: NavigationAgent3D = NavigationAgent3D.new()
var navigation_target: Vector3 = Vector3.ZERO
var navigation_ready: bool = false

# Camera reference
var camera_system: CameraSystem

func _ready():
	# Get character core reference
	character_core = get_node("../../CharacterCore") as CharacterBody3D
	if not character_core:
		push_error("MovementComponent: CharacterCore not found")
		return
	
	print("MovementComponent: CharacterCore found: ", character_core)
	
	# Set up NavigationAgent3D if using navigation mesh
	if use_navigation_mesh:
		setup_navigation_agent()
	
	# Get camera system reference
	camera_system = get_node("../../../CAMERA") as CameraSystem
	if not camera_system:
		push_error("MovementComponent: CAMERA system not found")
		return
	
	# Connect to input signals
	connect_to_input_signals()
	
	# Debug NavigationMesh setup
	if debug_navigation:
		call_deferred("debug_navigation_setup")
	
	print("MovementComponent: Initialized successfully (NavMesh: ", use_navigation_mesh, ")")

func setup_navigation_agent():
	# Add NavigationAgent3D to character
	character_core.add_child(nav_agent)
	
	# Configure NavigationAgent3D properties
	nav_agent.radius = 0.5
	nav_agent.height = 1.8
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = 0.5
	nav_agent.max_speed = navigation_speed
	nav_agent.path_max_distance = 100.0
	
	# Connect NavigationAgent3D signals
	nav_agent.target_reached.connect(_on_navigation_target_reached)
	nav_agent.navigation_finished.connect(_on_navigation_finished)
	
	# Wait for navigation map to be ready
	call_deferred("_navigation_setup_complete")
	
	print("MovementComponent: NavigationAgent3D configured")

func debug_navigation_setup():
	# Debug NavigationMesh setup
	print("=== NAVIGATION DEBUG ===")
	
	# Check for NavigationRegion3D in scene
	var nav_regions = find_navigation_regions(get_tree().current_scene)
	print("NavigationRegion3D nodes found: ", nav_regions.size())
	
	for region in nav_regions:
		print("  - NavigationRegion3D: ", region.name)
		print("    Position: ", region.global_position)
		var nav_mesh = region.navigation_mesh
		if nav_mesh:
			print("    NavigationMesh: ", nav_mesh)
			print("    Cell size: ", nav_mesh.cell_size)
			print("    Cell height: ", nav_mesh.cell_height)
		else:
			print("    ERROR: No NavigationMesh resource assigned!")
	
	# Check NavigationServer
	var map_count = NavigationServer3D.get_maps().size()
	print("NavigationServer maps: ", map_count)
	
	if map_count > 0:
		var map = NavigationServer3D.get_maps()[0]
		print("  Map ID: ", map)
		print("  Map active: ", NavigationServer3D.map_is_active(map))
	
	# Check character position relative to NavMesh
	if character_core:
		var char_pos = character_core.global_position
		print("Character position: ", char_pos)
		
		# Test if position is on NavigationMesh
		call_deferred("test_navmesh_position", char_pos)
	
	print("========================")

func find_navigation_regions(node: Node) -> Array:
	# Recursively find all NavigationRegion3D nodes
	var regions = []
	
	if node is NavigationRegion3D:
		regions.append(node)
	
	for child in node.get_children():
		regions.append_array(find_navigation_regions(child))
	
	return regions

func test_navmesh_position(position: Vector3):
	# Test if position is valid on NavigationMesh
	if not navigation_ready:
		print("Navigation not ready yet, skipping position test")
		return
	
	var query = NavigationServer3D.map_get_closest_point(NavigationServer3D.get_maps()[0], position)
	var distance = position.distance_to(query)
	
	print("Position test for: ", position)
	print("  Closest NavMesh point: ", query)
	print("  Distance to NavMesh: ", distance)
	
	if distance < 1.0:
		print("  ✓ Position is ON NavigationMesh")
	else:
		print("  ✗ Position is OFF NavigationMesh (distance: ", distance, ")")

func _navigation_setup_complete():
	# Called after navigation system is ready
	navigation_ready = true
	print("MovementComponent: Navigation system ready")
	
	# Additional debug after setup
	if debug_navigation:
		print("NavigationAgent3D ready. Map: ", nav_agent.get_navigation_map())

func _physics_process(delta):
	if not character_core:
		return
	
	# Apply gravity
	if not character_core.is_on_floor():
		character_core.velocity.y -= gravity * delta
	
	# Handle jumping
	if is_jumping and character_core.is_on_floor():
		character_core.velocity.y = jump_velocity
		is_jumping = false
	
	# Calculate movement (navigation or direct input)
	if is_navigating:
		if use_navigation_mesh and navigation_ready:
			calculate_navmesh_movement(delta)
		else:
			calculate_direct_navigation_movement(delta)
	else:
		calculate_movement(delta)
	
	# Apply movement
	character_core.move_and_slide()

func connect_to_input_signals():
	# Connect to DirectControlComponent signals
	var direct_control = get_node("../../../CONTROL/ControlComponents/DirectControlComponent")
	if direct_control:
		if direct_control.has_signal("movement_command"):
			direct_control.movement_command.connect(_on_movement_command)
			print("MovementComponent: Connected to movement_command")
		
		if direct_control.has_signal("action_command"):
			direct_control.action_command.connect(_on_action_command)
			print("MovementComponent: Connected to action_command")
	else:
		push_warning("MovementComponent: DirectControlComponent not found")
	
	# Connect to TargetControlComponent signals
	var target_control = get_node("../../../CONTROL/ControlComponents/TargetControlComponent")
	if target_control:
		if target_control.has_signal("navigate_command"):
			target_control.navigate_command.connect(_on_navigate_command)
			print("MovementComponent: Connected to navigate_command")
	else:
		push_warning("MovementComponent: TargetControlComponent not found")

func _on_movement_command(direction: Vector2, magnitude: float):
	target_direction = direction
	
	if is_sprinting:
		target_speed = sprint_speed * magnitude
	elif is_walking:
		target_speed = walk_speed * magnitude
	else:
		target_speed = run_speed * magnitude

func _on_action_command(action: String, pressed: bool):
	match action:
		"jump":
			if pressed and character_core.is_on_floor():
				is_jumping = true
		"sprint":
			is_sprinting = pressed
		"walk":
			is_walking = pressed
		"reset":
			if pressed:
				reset_character_position()

func _on_navigate_command(target_position: Vector3):
	print("MovementComponent: Navigation command received")
	print("  Target: ", target_position)
	print("  Use NavMesh: ", use_navigation_mesh)
	print("  Navigation ready: ", navigation_ready)
	
	navigation_target = target_position
	is_navigating = true
	
	if use_navigation_mesh and navigation_ready:
		# Test if target is reachable
		call_deferred("test_navmesh_position", target_position)
		
		nav_agent.target_position = target_position
		print("  ✓ Using NavigationAgent3D pathfinding")
		print("  ✓ Agent target set to: ", nav_agent.target_position)
		
		# Debug path
		call_deferred("debug_navigation_path")
	else:
		print("  → Using direct movement (NavMesh not ready)")

func debug_navigation_path():
	# Debug the calculated path
	if nav_agent.is_navigation_finished():
		print("  ✗ Navigation finished immediately (target unreachable?)")
		return
	
	var path = nav_agent.get_current_navigation_path()
	print("  Navigation path points: ", path.size())
	for i in range(min(path.size(), 5)):  # Show first 5 points
		print("    [", i, "] ", path[i])

func calculate_movement(delta: float):
	current_direction = current_direction.lerp(target_direction, acceleration * delta)
	
	if target_direction.length() > 0:
		current_speed = lerp(current_speed, target_speed, acceleration * delta)
	else:
		current_speed = lerp(current_speed, 0.0, deceleration * delta)
	
	var movement_3d = convert_to_world_space(current_direction)
	character_core.velocity.x = movement_3d.x * current_speed
	character_core.velocity.z = movement_3d.z * current_speed

func calculate_navmesh_movement(delta: float):
	if not is_navigating:
		return
	
	if nav_agent.is_navigation_finished():
		if debug_navigation:
			print("MovementComponent: NavigationAgent reports finished")
		finish_navigation()
		return
	
	var next_path_position = nav_agent.get_next_path_position()
	var current_position = character_core.global_position
	var direction = (next_path_position - current_position).normalized()
	
	if debug_navigation:
		print("NavMesh Movement:")
		print("  Current: ", current_position)
		print("  Next waypoint: ", next_path_position)
		print("  Direction: ", direction)
		print("  Distance to waypoint: ", current_position.distance_to(next_path_position))
	
	character_core.velocity.x = direction.x * navigation_speed
	character_core.velocity.z = direction.z * navigation_speed

func calculate_direct_navigation_movement(delta: float):
	if not is_navigating:
		return
	
	var current_position = character_core.global_position
	var distance_to_target = current_position.distance_to(navigation_target)
	
	if distance_to_target < destination_threshold:
		finish_navigation()
		return
	
	var direction = (navigation_target - current_position).normalized()
	character_core.velocity.x = direction.x * navigation_speed
	character_core.velocity.z = direction.z * navigation_speed

func _on_navigation_target_reached():
	print("MovementComponent: NavigationAgent3D target_reached signal")
	finish_navigation()

func _on_navigation_finished():
	print("MovementComponent: NavigationAgent3D navigation_finished signal")
	finish_navigation()

func finish_navigation():
	is_navigating = false
	character_core.velocity.x = 0
	character_core.velocity.z = 0
	
	var target_control = get_node("../../../CONTROL/ControlComponents/TargetControlComponent")
	if target_control and target_control.has_method("on_destination_reached"):
		target_control.on_destination_reached()
	
	print("MovementComponent: Navigation finished")

func convert_to_world_space(input_direction: Vector2) -> Vector3:
	if not camera_system or input_direction.length() == 0:
		return Vector3.ZERO
	
	var camera_forward = -camera_system.get_camera_forward()
	var camera_right = camera_system.get_camera_right()
	
	camera_forward.y = 0
	camera_right.y = 0
	camera_forward = camera_forward.normalized()
	camera_right = camera_right.normalized()
	
	var movement_vector = Vector3.ZERO
	movement_vector += camera_right * input_direction.x
	movement_vector += camera_forward * input_direction.y
	
	return movement_vector.normalized()

func reset_character_position():
	if character_core:
		character_core.global_position = Vector3.ZERO
		character_core.velocity = Vector3.ZERO
		is_navigating = false
		print("MovementComponent: Character position reset")

# Public API
func get_movement_speed() -> float:
	return current_speed / run_speed

func get_is_moving() -> bool:
	return current_speed > 0.1 or is_navigating

func get_is_grounded() -> bool:
	return character_core.is_on_floor() if character_core else false

func get_movement_direction() -> Vector3:
	return Vector3(character_core.velocity.x, 0, character_core.velocity.z).normalized() if character_core else Vector3.ZERO

# Debug info
func get_debug_info() -> Dictionary:
	return {
		"current_speed": current_speed,
		"is_moving": get_is_moving(),
		"is_navigating": is_navigating,
		"navigation_target": navigation_target,
		"use_navigation_mesh": use_navigation_mesh,
		"navigation_ready": navigation_ready,
		"nav_agent_finished": nav_agent.is_navigation_finished() if use_navigation_mesh else false,
		"nav_regions_found": find_navigation_regions(get_tree().current_scene).size(),
		"velocity": character_core.velocity if character_core else Vector3.ZERO
	}
