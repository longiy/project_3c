# InputManager.gd - ENHANCED: Clean integration with ClickNavigationComponent
extends Node
class_name InputManager

# === SIGNALS ===
signal movement_started(direction: Vector2, magnitude: float)
signal movement_updated(direction: Vector2, magnitude: float)
signal movement_stopped()
signal jump_pressed()
signal sprint_started()
signal sprint_stopped()
signal slow_walk_started()
signal slow_walk_stopped()
signal reset_pressed()

# NEW: Click navigation signals
signal click_navigation_requested(screen_position: Vector2)
signal drag_navigation_updated(screen_position: Vector2)
signal drag_navigation_ended()

# === SETTINGS ===
@export_group("Input Settings")
@export var input_deadzone = 0.05
@export var movement_update_frequency = 60

# === STATE ===
var character: CharacterBody3D
var camera_rig: CameraController

var current_raw_input = Vector2.ZERO
var last_sent_input = Vector2.ZERO
var movement_active = false
var movement_start_time = 0.0

var input_components: Array[Node] = []
var movement_update_timer = 0.0
var movement_update_interval: float

# ENHANCED: Click navigation integration
var click_navigation_component: ClickNavigationComponent
var is_click_dragging = false

# ENHANCED: WASD override state
var wasd_is_overriding = false

func _ready():
	character = get_parent() as CharacterBody3D
	if not character:
		push_error("InputManager must be child of CharacterBody3D")
		return
	
	movement_update_interval = 1.0 / movement_update_frequency
	
	camera_rig = get_node_or_null("../../CAMERARIG") as CameraController
	if not camera_rig:
		push_warning("No CameraController found - click navigation may not work")
	
	call_deferred("find_input_components")

func _input(event):
	# Handle discrete inputs
	if event.is_action_pressed("jump"):
		jump_pressed.emit()
	elif event.is_action_pressed("reset"):
		reset_pressed.emit()
	elif event.is_action_pressed("sprint"):
		sprint_started.emit()
	elif event.is_action_released("sprint"):
		sprint_stopped.emit()
	elif event.is_action_pressed("walk"):
		slow_walk_started.emit()
	elif event.is_action_released("walk"):
		slow_walk_stopped.emit()
	
	# ENHANCED: Handle click navigation input
	handle_click_navigation_input(event)

func handle_click_navigation_input(event):
	"""ENHANCED: Centralized click navigation input handling"""
	if not camera_rig or not camera_rig.is_in_click_navigation_mode():
		return
	
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# Start click navigation
			is_click_dragging = true
			click_navigation_requested.emit(event.position)
		elif not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# End click navigation
			is_click_dragging = false
			drag_navigation_ended.emit()
	
	elif event is InputEventMouseMotion and is_click_dragging:
		# Update drag navigation
		drag_navigation_updated.emit(event.position)

func _physics_process(delta):
	movement_update_timer += delta
	
	if movement_update_timer >= movement_update_interval:
		process_movement_input()
		movement_update_timer = 0.0

func process_movement_input():
	"""ENHANCED: Process movement input with click navigation integration"""
	var new_input = get_combined_movement_input()
	var input_magnitude = new_input.length()
	
	# Check for WASD override
	var wasd_input = get_wasd_input()
	var wasd_active = wasd_input.length() > input_deadzone
	
	if wasd_active and not wasd_is_overriding:
		# WASD started - cancel click navigation
		wasd_is_overriding = true
		if click_navigation_component:
			click_navigation_component.cancel_input()
	elif not wasd_active and wasd_is_overriding:
		# WASD stopped
		wasd_is_overriding = false
	
	# Process movement state changes
	if not movement_active and input_magnitude > input_deadzone:
		# Movement started
		movement_active = true
		movement_start_time = Time.get_ticks_msec() / 1000.0
		current_raw_input = new_input
		last_sent_input = new_input
		movement_started.emit(new_input, input_magnitude)
	
	elif movement_active and input_magnitude > input_deadzone:
		# Movement continuing
		if new_input.distance_to(last_sent_input) > 0.01:
			current_raw_input = new_input
			last_sent_input = new_input
			movement_updated.emit(new_input, input_magnitude)
	
	elif movement_active and input_magnitude <= input_deadzone:
		# Movement stopped
		movement_active = false
		current_raw_input = Vector2.ZERO
		last_sent_input = Vector2.ZERO
		movement_stopped.emit()

func get_combined_movement_input() -> Vector2:
	"""ENHANCED: Get movement input from all sources with proper priority"""
	# Priority 1: WASD input (always takes precedence)
	var wasd_input = get_wasd_input()
	if wasd_input.length() > input_deadzone:
		return wasd_input
	
	# Priority 2: Click navigation (only if not overridden by WASD)
	if not wasd_is_overriding and click_navigation_component and click_navigation_component.is_active():
		return click_navigation_component.get_movement_input()
	
	# Priority 3: Other input components
	for component in input_components:
		if component.has_method("is_active") and component.is_active():
			if component.has_method("get_movement_input"):
				var component_input = component.get_movement_input()
				if component_input.length() > input_deadzone:
					return component_input
	
	return Vector2.ZERO

func get_wasd_input() -> Vector2:
	"""Get WASD keyboard input"""
	var input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	return input if input.length() > input_deadzone else Vector2.ZERO

# === COMPONENT REGISTRATION ===

func register_click_navigation_component(component: ClickNavigationComponent):
	"""ENHANCED: Register click navigation component"""
	click_navigation_component = component
	print("✅ InputManager: Registered ClickNavigationComponent")

func find_input_components():
	"""Find and register input components"""
	input_components.clear()
	
	# Find all input components in parent
	for child in get_parent().get_children():
		if child.has_method("is_active") and child.has_method("get_movement_input"):
			# Skip click navigation component (handled separately)
			if not child is ClickNavigationComponent:
				input_components.append(child)
				print("✅ InputManager: Found input component: ", child.name)

func cancel_all_input():
	"""Cancel all active input sources"""
	wasd_is_overriding = false
	is_click_dragging = false
	
	if click_navigation_component:
		click_navigation_component.cancel_input()
	
	for component in input_components:
		if component.has_method("cancel_input"):
			component.cancel_input()

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get input debug information"""
	var active_components = []
	for component in input_components:
		if component.has_method("is_active") and component.is_active():
			active_components.append(component.name)
	
	return {
		"movement_active": movement_active,
		"current_input": current_raw_input,
		"input_magnitude": current_raw_input.length(),
		"movement_duration": (Time.get_ticks_msec() / 1000.0) - movement_start_time if movement_active else 0.0,
		"camera_mode": camera_rig.get_mode_name(camera_rig.get_current_mode()) if camera_rig else "unknown",
		"wasd_overriding": wasd_is_overriding,
		"click_dragging": is_click_dragging,
		"click_nav_active": click_navigation_component.is_active() if click_navigation_component else false,
		"active_components": active_components,
		"total_components": input_components.size() + (1 if click_navigation_component else 0)
	}
