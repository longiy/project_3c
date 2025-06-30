# InputPriorityManager.gd - Manages input component priorities and coordination
extends Node
class_name InputPriorityManager

# === SIGNALS ===
signal movement_started(direction: Vector2, magnitude: float)
signal movement_updated(direction: Vector2, magnitude: float)
signal movement_stopped()

# === SETTINGS ===
@export var movement_update_frequency = 60
@export var input_deadzone = 0.05

# === COMPONENT REGISTRY ===
var registered_components: Array[Node] = []
var specialized_components: Dictionary = {}

# References
var character: CharacterBody3D
var camera_rig: CameraController

# State tracking
var current_winning_component: Node = null
var last_movement_input = Vector2.ZERO
var movement_active = false
var movement_update_timer = 0.0
var movement_update_interval: float

# Priority override states
var wasd_is_overriding = false

func _ready():
	movement_update_interval = 1.0 / movement_update_frequency
	print("✅ InputPriorityManager: Ready to coordinate input components")

func _physics_process(delta):
	movement_update_timer += delta
	
	if movement_update_timer >= movement_update_interval:
		process_component_priorities()
		movement_update_timer = 0.0

# === COMPONENT REGISTRATION ===

func register_component(component: Node):
	"""Register a general input component"""
	if component in registered_components:
		push_warning("Component already registered: " + component.name)
		return
	
	registered_components.append(component)
	print("✅ InputPriorityManager: Registered component: ", component.name)

func register_specialized_component(component_type: String, component: Node):
	"""Register a specialized input component (like click navigation)"""
	specialized_components[component_type] = component
	print("✅ InputPriorityManager: Registered specialized component: ", component_type)

func unregister_component(component: Node):
	"""Unregister a component"""
	registered_components.erase(component)
	
	# Remove from specialized components if present
	for key in specialized_components.keys():
		if specialized_components[key] == component:
			specialized_components.erase(key)
			break

# === COMPONENT REFERENCES ===

func setup_character_reference(char: CharacterBody3D):
	"""Setup character reference"""
	character = char

func setup_camera_reference(camera: CameraController):
	"""Setup camera reference"""
	camera_rig = camera

# === PRIORITY PROCESSING ===

func process_component_priorities():
	"""Process all input components and determine priority winner"""
	var new_input = get_prioritized_movement_input()
	var input_magnitude = new_input.length()
	
	# Handle movement state changes
	if not movement_active and input_magnitude > input_deadzone:
		# Movement started
		movement_active = true
		last_movement_input = new_input
		movement_started.emit(new_input, input_magnitude)
	
	elif movement_active and input_magnitude > input_deadzone:
		# Movement continuing - check for changes
		if new_input.distance_to(last_movement_input) > 0.01:
			last_movement_input = new_input
			movement_updated.emit(new_input, input_magnitude)
	
	elif movement_active and input_magnitude <= input_deadzone:
		# Movement stopped
		movement_active = false
		last_movement_input = Vector2.ZERO
		current_winning_component = null
		movement_stopped.emit()

func get_prioritized_movement_input() -> Vector2:
	"""Get movement input using priority system"""
	
	# Priority 1: WASD Keyboard Input (always highest priority)
	var keyboard_input = get_keyboard_input()
	if keyboard_input.length() > input_deadzone:
		handle_wasd_override(true)
		current_winning_component = null  # Built-in input, no component
		return keyboard_input
	
	# WASD no longer active
	if wasd_is_overriding:
		handle_wasd_override(false)
	
	# Priority 2: Click Navigation (if camera allows and not overridden)
	var click_nav_input = get_click_navigation_input()
	if click_nav_input.length() > input_deadzone:
		var click_nav_component = specialized_components.get("click_navigation")
		current_winning_component = click_nav_component
		return click_nav_input
	
	# Priority 3: Other registered components
	for component in registered_components:
		if component.has_method("is_active") and component.is_active():
			if component.has_method("get_movement_input"):
				var component_input = component.get_movement_input()
				if component_input.length() > input_deadzone:
					current_winning_component = component
					return component_input
	
	# No active input
	current_winning_component = null
	return Vector2.ZERO

func get_keyboard_input() -> Vector2:
	"""Get WASD keyboard input"""
	var parent_input_processor = get_parent().get_node_or_null("RawInputProcessor") as RawInputProcessor
	if parent_input_processor:
		return parent_input_processor.get_current_keyboard_input()
	
	# Fallback to direct input
	var input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	return input if input.length() > input_deadzone else Vector2.ZERO

func get_click_navigation_input() -> Vector2:
	"""Get click navigation input"""
	var click_nav_component = specialized_components.get("click_navigation")
	
	if not click_nav_component:
		return Vector2.ZERO
	
	# Check camera mode
	if camera_rig and not camera_rig.is_in_click_navigation_mode():
		return Vector2.ZERO
	
	# Check if click navigation is active
	if click_nav_component.has_method("is_active") and click_nav_component.is_active():
		if click_nav_component.has_method("get_movement_input"):
			return click_nav_component.get_movement_input()
	
	return Vector2.ZERO

# === WASD OVERRIDE HANDLING ===

func handle_wasd_override(is_active: bool):
	"""Handle WASD override state changes"""
	if is_active and not wasd_is_overriding:
		# WASD started - cancel click navigation
		wasd_is_overriding = true
		cancel_click_navigation()
	elif not is_active and wasd_is_overriding:
		# WASD stopped
		wasd_is_overriding = false

func cancel_click_navigation():
	"""Cancel click navigation input"""
	var click_nav_component = specialized_components.get("click_navigation")
	if click_nav_component and click_nav_component.has_method("cancel_input"):
		click_nav_component.cancel_input()

# === SIGNAL HANDLERS ===

func _on_click_navigation_event(event_type: String, data: Dictionary):
	"""Handle click navigation events from RawInputProcessor"""
	var click_nav_component = specialized_components.get("click_navigation")
	if not click_nav_component:
		return
	
	# Only process if camera is in click navigation mode
	if camera_rig and not camera_rig.is_in_click_navigation_mode():
		return
	
	# Route to appropriate handler
	match event_type:
		"click_start":
			if click_nav_component.has_method("_on_click_navigation_requested"):
				click_nav_component._on_click_navigation_requested(data.screen_position)
		"drag_update":
			if click_nav_component.has_method("_on_drag_navigation_updated"):
				click_nav_component._on_drag_navigation_updated(data.screen_position)
		"click_end":
			if click_nav_component.has_method("_on_drag_navigation_ended"):
				click_nav_component._on_drag_navigation_ended()

# === PUBLIC API ===

func set_input_mode(mode: String):
	"""Set input mode for camera coordination"""
	# This could be used for different priority schemes based on game mode
	pass

func cancel_all_input():
	"""Cancel all active input"""
	wasd_is_overriding = false
	
	# Cancel specialized components
	for component in specialized_components.values():
		if component.has_method("cancel_input"):
			component.cancel_input()
	
	# Cancel registered components
	for component in registered_components:
		if component.has_method("cancel_input"):
			component.cancel_input()

func get_winning_component() -> Node:
	"""Get the currently winning input component"""
	return current_winning_component

func get_current_input() -> Vector2:
	"""Get current processed movement input"""
	return last_movement_input

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get debug information"""
	var active_components = []
	for component in registered_components:
		if component.has_method("is_active") and component.is_active():
			active_components.append(component.name)
	
	var specialized_status = {}
	for key in specialized_components.keys():
		var component = specialized_components[key]
		if component.has_method("is_active"):
			specialized_status[key] = component.is_active()
		else:
			specialized_status[key] = "unknown"
	
	return {
		"movement_active": movement_active,
		"current_input": last_movement_input,
		"input_magnitude": last_movement_input.length(),
		"wasd_overriding": wasd_is_overriding,
		"winning_component": current_winning_component.name if current_winning_component else "keyboard/none",
		"registered_components": registered_components.size(),
		"specialized_components": specialized_components.keys(),
		"active_components": active_components,
		"specialized_status": specialized_status,
		"camera_mode": camera_rig.get_mode_name(camera_rig.get_current_mode()) if camera_rig else "unknown"
	}

func get_component_status() -> Dictionary:
	"""Get detailed status of all components"""
	var status = {}
	
	# Registered components
	for component in registered_components:
		status[component.name] = {
			"active": component.is_active() if component.has_method("is_active") else false,
			"type": "registered"
		}
	
	# Specialized components
	for key in specialized_components.keys():
		var component = specialized_components[key]
		status[key] = {
			"active": component.is_active() if component.has_method("is_active") else false,
			"type": "specialized",
			"component_name": component.name
		}
	
	return status
