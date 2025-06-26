# InputManager.gd - CENTRALIZED input processing (ALL input flows through here)
extends Node
class_name InputManager

@export_group("Input Settings")
@export var input_deadzone = 0.05
@export var movement_update_frequency = 60  # Hz for move_update actions

@export_group("Mouse Settings")
@export var scroll_zoom_speed = 0.5

# Component references
var action_system: ActionSystem
var character: CharacterBody3D

# Movement state tracking
var current_raw_input = Vector2.ZERO
var last_sent_input = Vector2.ZERO
var movement_active = false
var movement_start_time = 0.0

# Input component priority and references
@export var input_component_priority: Array[String] = ["ClickNavigation", "Gamepad"]
var input_components: Array[Node] = []

# Update timing for movement actions
var movement_update_timer = 0.0
var movement_update_interval: float

func _ready():
	character = get_parent() as CharacterBody3D
	if not character:
		push_error("InputManager must be child of CharacterBody3D")
		return
	
	# Calculate update interval
	movement_update_interval = 1.0 / movement_update_frequency
	
	# Find action system (deferred to ensure it's ready)
	call_deferred("setup_action_system")
	
	# Find input components
	call_deferred("find_input_components")
	
	print("📝 InputManager: CENTRALIZED input processing initialized")

func setup_action_system():
	"""Find and validate action system"""
	action_system = character.get_node_or_null("ActionSystem")
	if not action_system:
		push_error("InputManager requires ActionSystem as sibling")
		return
	
	print("✅ InputManager: Connected to ActionSystem")

func _input(event):
	"""Process ALL input events and convert to actions"""
	# Safety check - don't process input until action system is ready
	if not action_system:
		return
		
	# Handle discrete input events (keys, buttons)
	handle_discrete_input(event)
	
	# Handle mouse look (CENTRALIZED - was in CameraActionReceiver)
	handle_mouse_look(event)
	
	# Handle mouse wheel (CENTRALIZED - was in CameraActionReceiver)
	handle_mouse_wheel(event)
	
	# Handle mouse buttons (CENTRALIZED)
	handle_mouse_buttons(event)

func _physics_process(delta):
	"""Process continuous input (movement) at fixed intervals"""
	# Safety check - don't process until action system is ready
	if not action_system:
		return
		
	handle_movement_input(delta)

# === DISCRETE INPUT HANDLING ===

func handle_discrete_input(event: InputEvent):
	"""Convert key/button events to actions"""
	if not action_system:
		return  # Safely return if action system not ready
		
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				action_system.request_action("jump")
			KEY_ENTER when Input.is_action_pressed("reset"):
				action_system.request_action("reset")
	
	# Handle movement mode toggles
	if event.is_action_pressed("sprint"):
		action_system.request_action("sprint_start")
	elif event.is_action_released("sprint"):
		action_system.request_action("sprint_end")
	
	if event.is_action_pressed("walk"):
		action_system.request_action("slow_walk_start")
	elif event.is_action_released("walk"):
		action_system.request_action("slow_walk_end")

# === MOUSE INPUT HANDLING (CENTRALIZED) ===

func handle_mouse_look(event: InputEvent):
	"""Convert mouse movement to look actions (MOVED FROM CameraActionReceiver)"""
	if not action_system:
		return  # Safely return if action system not ready
		
	if event is InputEventMouseMotion:
		# Only process if mouse is captured
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			action_system.request_action("look_delta", {
				"delta": event.relative,
				"sensitivity": 1.0
			})

func handle_mouse_wheel(event: InputEvent):
	"""Convert scroll wheel to zoom actions (MOVED FROM CameraActionReceiver)"""
	if not action_system:
		return  # Safely return if action system not ready
		
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				action_system.request_action("camera_zoom", {
					"zoom_delta": -scroll_zoom_speed
				})
			MOUSE_BUTTON_WHEEL_DOWN:
				action_system.request_action("camera_zoom", {
					"zoom_delta": scroll_zoom_speed
				})

func handle_mouse_buttons(event: InputEvent):
	"""Handle mouse button presses (CENTRALIZED)"""
	if not action_system:
		return  # Safely return if action system not ready
		
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_RIGHT:
				# Mouse toggle for camera
				action_system.request_action("camera_toggle_mouse")
			
			MOUSE_BUTTON_LEFT:
				# Let ClickNavigationComponent handle this through normal flow
				# (ClickNav → InputManager is already correct)
				pass

# === MOVEMENT INPUT HANDLING ===

func handle_movement_input(delta: float):
	"""Process movement input and generate appropriate actions"""
	if not action_system:
		return  # Safely return if action system not ready
		
	movement_update_timer += delta
	
	# Get current movement input
	var new_input = get_current_movement_input()
	var input_magnitude = new_input.length()
	var has_input = input_magnitude > input_deadzone
	
	# Apply deadzone
	if not has_input:
		new_input = Vector2.ZERO
	
	# Detect movement state changes
	var was_moving = movement_active
	var is_moving = has_input
	
	# Handle movement start
	if is_moving and not was_moving:
		movement_active = true
		movement_start_time = Time.get_ticks_msec() / 1000.0
		current_raw_input = new_input
		last_sent_input = new_input
		
		action_system.request_action("move_start", {
			"direction": new_input,
			"magnitude": input_magnitude
		})
		print("📝 Movement started: ", new_input)
	
	# Handle movement end
	elif not is_moving and was_moving:
		movement_active = false
		current_raw_input = Vector2.ZERO
		last_sent_input = Vector2.ZERO
		
		action_system.request_action("move_end")
		print("📝 Movement ended")
	
	# Handle movement update (only if moving and enough time passed)
	elif is_moving and movement_update_timer >= movement_update_interval:
		# Only send update if input changed significantly
		if new_input.distance_to(last_sent_input) > 0.1:
			current_raw_input = new_input
			last_sent_input = new_input
			
			action_system.request_action("move_update", {
				"direction": new_input,
				"magnitude": input_magnitude,
				"duration": get_movement_duration()
			})
		
		movement_update_timer = 0.0

# === INPUT SOURCE MANAGEMENT ===

func get_current_movement_input() -> Vector2:
	"""Get movement input from highest priority active source"""
	# WASD always has highest priority
	var wasd_input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if wasd_input.length() > input_deadzone:
		cancel_all_input_components()
		return wasd_input
	
	# Check input components by priority
	for component_name in input_component_priority:
		var component = get_component_by_name(component_name)
		if component and is_component_active(component):
			var component_input = component.get_movement_input()
			if component_input and component_input.length() > input_deadzone:
				return component_input
	
	return Vector2.ZERO

func get_component_by_name(component_name: String) -> Node:
	"""Find input component by name"""
	for component in input_components:
		if component.name.contains(component_name):
			return component
	return null

func is_component_active(component: Node) -> bool:
	"""Check if input component is currently active"""
	if not is_instance_valid(component):
		return false
	
	if component.has_method("is_active"):
		return component.is_active()
	
	# Fallback: check if component has input
	if component.has_method("get_movement_input"):
		var test_input = component.get_movement_input()
		return test_input != null and test_input.length() > input_deadzone
	
	return false

func cancel_all_input_components():
	"""Cancel input components when WASD takes over"""
	for component in input_components:
		if component and component.has_method("cancel_input"):
			component.cancel_input()

func find_input_components():
	"""Auto-discover input components"""
	input_components.clear()
	
	for child in character.get_children():
		if child == self:
			continue
		if child.has_method("get_movement_input"):
			input_components.append(child)
			print("📝 InputManager: Found input component: ", child.name)
	
	print("📝 InputManager: Total input components: ", input_components.size())

# === UTILITY METHODS ===

func get_movement_duration() -> float:
	"""Get how long movement has been active"""
	if movement_active:
		return (Time.get_ticks_msec() / 1000.0) - movement_start_time
	return 0.0

func is_movement_active() -> bool:
	"""Check if movement is currently active"""
	return movement_active

func get_current_input_direction() -> Vector2:
	"""Get current input for external systems that still need it"""
	return current_raw_input

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	return {
		"movement_active": movement_active,
		"current_input": current_raw_input,
		"movement_duration": get_movement_duration(),
		"component_count": input_components.size(),
		"active_components": get_active_components(),
		"action_system_connected": action_system != null,
		"update_frequency": movement_update_frequency,
		"centralized_mouse": true,
		"input_flow": "ALL_CENTRALIZED"
	}

func get_active_components() -> Array[String]:
	var active: Array[String] = []
	for component in input_components:
		if is_component_active(component):
			active.append(component.name)
	return active
