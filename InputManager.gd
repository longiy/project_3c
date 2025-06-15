# InputManager.gd - Create this as a new file
extends Node

# Input signals
signal movement_input(direction: Vector2)
signal mouse_look_input(delta: Vector2)
signal jump_pressed()
signal click_navigation(world_position: Vector3)
signal mouse_mode_changed(is_captured: bool)

# Input state
enum InputMode { CAMERA_LOOK, CURSOR_NAVIGATION }
var current_mode: InputMode = InputMode.CAMERA_LOOK
var mouse_sensitivity = 0.002

# References
var camera: Camera3D
var world: World3D

func _ready():
	print("InputManager initialized")
	# Start in camera look mode
	set_camera_mode(true)

func set_camera(cam: Camera3D):
	camera = cam
	if cam:
		world = cam.get_world_3d()
		print("Camera set for InputManager")

func set_camera_mode(is_camera_mode: bool):
	if is_camera_mode:
		current_mode = InputMode.CAMERA_LOOK
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		current_mode = InputMode.CURSOR_NAVIGATION
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	mouse_mode_changed.emit(is_camera_mode)
	print("Input mode changed to: ", "CAMERA_LOOK" if is_camera_mode else "CURSOR_NAVIGATION")

func _input(event):
	# Handle mode toggle
	if event.is_action_pressed("toggle_mouse_look"):
		toggle_input_mode()
	
	# Handle input based on current mode
	match current_mode:
		InputMode.CAMERA_LOOK:
			handle_camera_input(event)
		InputMode.CURSOR_NAVIGATION:
			handle_navigation_input(event)

func toggle_input_mode():
	set_camera_mode(current_mode == InputMode.CURSOR_NAVIGATION)

func handle_camera_input(event):
	if event is InputEventMouseMotion:
		mouse_look_input.emit(event.relative * mouse_sensitivity)

func handle_navigation_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var world_pos = raycast_to_world(event.position)
		if world_pos != Vector3.ZERO:
			click_navigation.emit(world_pos)
			print("Click navigation to: ", world_pos)

func _physics_process(_delta):
	# Always emit movement input - even when it's zero
	var move_input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	movement_input.emit(move_input)  # Emit every frame, including Vector2.ZERO
	
	if Input.is_action_just_pressed("jump"):
		jump_pressed.emit()

func raycast_to_world(screen_pos: Vector2) -> Vector3:
	if not camera or not world:
		print("No camera or world for raycast")
		return Vector3.ZERO
	
	var space_state = world.direct_space_state
	var from = camera.project_ray_origin(screen_pos)
	var to = from + camera.project_ray_normal(screen_pos) * 1000
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	
	# Exclude character from raycast
	query.collision_mask = 1  # Only hit layer 1 (ground/environment)
	# Alternative: query.exclude = [character_body]  # If you want to exclude specific objects
	
	var result = space_state.intersect_ray(query)
	
	if result:
		print("Raycast hit at: ", result.position)
		return result.position
	else:
		print("No raycast hit")
		return Vector3.ZERO

func get_current_cursor_world_position() -> Vector3:
	if current_mode == InputMode.CURSOR_NAVIGATION:
		return raycast_to_world(get_viewport().get_mouse_position())
	return Vector3.ZERO
