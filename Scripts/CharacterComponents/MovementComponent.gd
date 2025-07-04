# MovementComponent.gd
# STEP 4: Fixed missing signal connections and added bidirectional communication

extends Node
class_name MovementComponent

# ===== FEEDBACK SIGNALS TO CONTROL COMPONENTS =====
signal movement_state_changed(is_moving: bool, direction: Vector2, speed: float)
signal navigation_state_changed(is_navigating: bool, target: Vector3)
signal rotation_state_changed(current_rotation: float, target_rotation: float)

# ===== EXPORTS & CONFIGURATION =====
@export_group("Component References")
@export var direct_control_component: DirectControlComponent
@export var target_control_component: TargetControlComponent
@export var gamepad_control_component: GamepadControlComponent
@export var character_core: CharacterBody3D
@export var camera_system: CameraSystem

@export_group("Movement Speeds")
@export var walk_speed: float = 4.0
@export var run_speed: float = 6.0
@export var sprint_speed: float = 8.0

@export_group("Physics")
@export var acceleration: float = 8.0
@export var deceleration: float = 10.0
@export var gravity: float = 9.8
@export var jump_velocity: float = 4.5

@export_group("Character Rotation")
@export var movement_rotation_speed: float = 12
@export var navigation_rotation_speed: float = 12
@export var camera_align_rotation_speed: float = 12
@export var snap_rotation_threshold: float = 0.1
@export var enable_navigation_rotation: bool = true
@export var enable_direction_snap: bool = false
@export var snap_angle_degrees: float = 45.0

@export_group("Navigation")
@export var navigation_speed: float = 6.0
@export var destination_threshold: float = 0.3

# ===== MOVEMENT STATE =====
var current_direction: Vector2 = Vector2.ZERO
var target_direction: Vector2 = Vector2.ZERO
var current_speed: float = 0.0
var target_speed: float = 0.0

# ===== ACTION STATE =====
var is_sprinting: bool = false
var is_walking: bool = false
var is_jumping: bool = false

# ===== NAVIGATION STATE =====
var is_navigating: bool = false
var navigation_target: Vector3 = Vector3.ZERO

# ===== ROTATION STATE =====
var target_character_rotation: float = 0.0
var has_rotation_target: bool = false

# ===== DRAG STOP STATE =====
var is_stopping_from_drag: bool = false
var is_drag_stopping: bool = false

func _ready():
	if not find_core_references():
		push_error("MovementComponent: Required references not set in Inspector")
		return
	
	call_deferred("connect_to_input_signals")
	print("MovementComponent: Initialized successfully")

func find_core_references() -> bool:
	# Add null checks before signal connections
	if not character_core:
		push_error("MovementComponent: character_core not assigned")
		return false
	
	if not camera_system:
		push_error("MovementComponent: camera_system not assigned")
		return false
	
	return true

func connect_to_input_signals():
	connect_direct_control_signals()
	connect_target_control_signals()
	connect_gamepad_control_signals()

func connect_direct_control_signals():
	if not direct_control_component:
		push_error("MovementComponent: direct_control_component not assigned")
		return
	
	# Ensure ALL required signals are connected
	if not direct_control_component.movement_command.is_connected(_on_movement_command):
		direct_control_component.movement_command.connect(_on_movement_command)
		print("MovementComponent: Connected to DirectControlComponent.movement_command")
	
	if not direct_control_component.action_command.is_connected(_on_action_command):
		direct_control_component.action_command.connect(_on_action_command)
		print("MovementComponent: Connected to DirectControlComponent.action_command")

func connect_target_control_signals():
	if not target_control_component:
		push_error("MovementComponent: target_control_component not assigned in Inspector")
		return
	
	# Connect navigate command - CRITICAL for click movement
	if not target_control_component.navigate_command.is_connected(_on_navigate_command):
		target_control_component.navigate_command.connect(_on_navigate_command)
		print("MovementComponent: Connected to TargetControlComponent.navigate_command")
	
	# Connect character look command for rotation  
	if not target_control_component.character_look_command.is_connected(_on_character_look_command):
		target_control_component.character_look_command.connect(_on_character_look_command)
		print("MovementComponent: Connected to TargetControlComponent.character_look_command")
	
	# Connect stop navigation command
	if not target_control_component.stop_navigation_command.is_connected(_on_stop_navigation_command):
		target_control_component.stop_navigation_command.connect(_on_stop_navigation_command)
		print("MovementComponent: Connected to TargetControlComponent.stop_navigation_command")

func connect_gamepad_control_signals():
	if not gamepad_control_component:
		print("MovementComponent: gamepad_control_component not assigned (optional)")
		return
	
	if not gamepad_control_component.movement_command.is_connected(_on_movement_command):
		gamepad_control_component.movement_command.connect(_on_movement_command)
		print("MovementComponent: Connected to GamepadControlComponent.movement_command")
	
	if not gamepad_control_component.action_command.is_connected(_on_action_command):
		gamepad_control_component.action_command.connect(_on_action_command)
		print("MovementComponent: Connected to GamepadControlComponent.action_command")

# ===== PHYSICS PROCESSING =====
func _physics_process(delta):
	if not character_core:
		return
		
	if not camera_system:
		return
		
	apply_gravity(delta)
	handle_jumping()
	calculate_movement(delta)
	apply_rotation(delta)
	character_core.move_and_slide()
	
	# Emit state changes for feedback
	emit_movement_state_feedback()
	emit_navigation_state_feedback()
	emit_rotation_state_feedback()

# ===== STATE FEEDBACK EMISSION =====
func emit_movement_state_feedback():
	var is_moving = current_speed > 0.1
	movement_state_changed.emit(is_moving, current_direction, current_speed)

func emit_navigation_state_feedback():
	navigation_state_changed.emit(is_navigating, navigation_target)

func emit_rotation_state_feedback():
	if has_rotation_target:
		rotation_state_changed.emit(character_core.rotation.y, target_character_rotation)

# ===== INPUT SIGNAL HANDLERS =====
func _on_movement_command(direction: Vector2, magnitude: float):
	target_direction = direction * magnitude
	
	# Stop navigation when manual movement starts
	if is_navigating and direction.length() > 0:
		stop_navigation()

func _on_action_command(action: String, pressed: bool):
	match action:
		"jump":
			if pressed and character_core.is_on_floor():
				is_jumping = true
		"sprint":
			is_sprinting = pressed
		"walk":
			is_walking = pressed

func _on_navigate_command(target_position: Vector3):
	start_navigation(target_position)

func _on_character_look_command(target_direction: Vector3):
	set_character_look_direction(target_direction)

func _on_stop_navigation_command():
	stop_navigation()

# ===== NAVIGATION CONTROL =====
func start_navigation(target_position: Vector3):
	navigation_target = target_position
	is_navigating = true
	
	print("MovementComponent: Started navigation to ", target_position)

func stop_navigation():
	if is_navigating:
		is_navigating = false
		print("MovementComponent: Navigation stopped")

func calculate_navigation_direction() -> Vector2:
	if not is_navigating:
		return Vector2.ZERO
	
	var char_pos = character_core.global_position
	var target_pos = navigation_target
	
	# Calculate 2D direction (ignore Y)
	var direction_3d = (target_pos - char_pos).normalized()
	var direction_2d = Vector2(direction_3d.x, direction_3d.z)
	
	# Check if we've reached the destination
	var distance = char_pos.distance_to(target_pos)
	if distance < destination_threshold:
		stop_navigation()
		return Vector2.ZERO
	
	return direction_2d

# ===== MOVEMENT CALCULATION =====
func calculate_movement(delta):
	# Priority: Navigation > Manual input
	var input_direction = Vector2.ZERO
	
	if is_navigating:
		input_direction = calculate_navigation_direction()
		target_speed = navigation_speed
	else:
		input_direction = target_direction
		calculate_target_speed()
	
	# Update current direction and speed
	current_direction = current_direction.lerp(input_direction, acceleration * delta)
	current_speed = lerp(current_speed, target_speed, acceleration * delta)
	
	# Apply movement relative to camera
	if current_direction.length() > 0.01:
		apply_camera_relative_movement()

func calculate_target_speed():
	if target_direction.length() == 0:
		target_speed = 0.0
	elif is_sprinting:
		target_speed = sprint_speed
	elif is_walking:
		target_speed = walk_speed
	else:
		target_speed = run_speed

func apply_camera_relative_movement():
	if not camera_system:
		return
	
	# Use CameraSystem's utility methods - invert forward for correct WASD behavior
	var camera_forward = -camera_system.get_camera_forward()  # Invert so W moves away from camera
	var camera_right = camera_system.get_camera_right()
	
	# Calculate camera-relative movement
	var forward_movement = camera_forward * current_direction.y * current_speed
	var right_movement = camera_right * current_direction.x * current_speed
	var world_movement = forward_movement + right_movement
	
	# Remove Y component for ground movement
	world_movement.y = 0
	character_core.velocity.x = world_movement.x
	character_core.velocity.z = world_movement.z

# ===== PHYSICS =====
func apply_gravity(delta):
	if not character_core.is_on_floor():
		character_core.velocity.y -= gravity * delta

func handle_jumping():
	if is_jumping and character_core.is_on_floor():
		character_core.velocity.y = jump_velocity
		is_jumping = false

# ===== ROTATION =====
func apply_rotation(delta):
	if current_direction.length() < 0.01:
		return
	
	var movement_angle = atan2(current_direction.x, current_direction.y)
	
	if camera_system:
		var camera_forward = camera_system.get_camera_forward()
		var camera_angle = atan2(camera_forward.x, camera_forward.z)
		movement_angle += camera_angle
		
		# Add 180 degrees to face the direction of movement instead of backing into it
		movement_angle += PI
	
	target_character_rotation = movement_angle
	has_rotation_target = true
	
	var current_rotation = character_core.rotation.y
	var new_rotation = lerp_angle(current_rotation, target_character_rotation, movement_rotation_speed * delta)
	character_core.rotation.y = new_rotation

func set_character_look_direction(target_direction: Vector3):
	var look_angle = atan2(target_direction.x, target_direction.z)
	target_character_rotation = look_angle
	has_rotation_target = true

# ===== PUBLIC API =====
func get_current_speed() -> float:
	return current_speed

func get_is_navigating() -> bool:
	return is_navigating

func get_navigation_target() -> Vector3:
	return navigation_target

func force_stop():
	target_direction = Vector2.ZERO
	current_direction = Vector2.ZERO
	target_speed = 0.0
	stop_navigation()
