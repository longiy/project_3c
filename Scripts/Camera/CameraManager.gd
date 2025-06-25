# CameraManager.gd - Industry-standard camera brain
extends Node3D
class_name CameraManager

# === SIGNALS ===
signal camera_blended(from_mode: String, to_mode: String, duration: float)
signal camera_state_changed(new_state: Dictionary)
signal input_mode_changed(mode: String)

# === CORE REFERENCES ===
@export_group("Core Setup")
@export var character: CharacterBody3D
@export var camera: Camera3D
@export var spring_arm: SpringArm3D

# === CAMERA COMPONENTS ===
@export_group("Camera Components")
@export var camera_components: Array[CameraComponent] = []

# === CAMERA MODES ===
@export_group("Camera Modes")
@export var default_mode = "follow"
@export var blend_speed = 2.0

# === CURRENT STATE ===
var current_mode = ""
var active_component: CameraComponent
var target_properties: CameraProperties
var current_properties: CameraProperties
var blend_tween: Tween

# === INPUT STATE TRACKING ===
var current_input_mode = "wasd"  # "wasd", "click", "cinematic", "disabled"
var last_input_time = 0.0
var input_switch_cooldown = 0.1

func _ready():
	setup_camera_manager()
	connect_to_systems()

func setup_camera_manager():
	"""Initialize camera manager and find components"""
	if not character:
		push_error("CameraManager: No character assigned")
		return
	
	if not camera or not spring_arm:
		push_error("CameraManager: Missing camera or spring arm")
		return
	
	# Initialize properties
	current_properties = CameraProperties.new()
	target_properties = CameraProperties.new()
	
	# Setup initial values
	current_properties.fov = camera.fov
	current_properties.distance = spring_arm.spring_length
	current_properties.offset = spring_arm.position
	
	# Find camera components if not assigned
	if camera_components.is_empty():
		find_camera_components()
	
	# Setup components
	setup_components()
	
	# Start with default mode
	set_camera_mode(default_mode)
	
	print("📹 CameraManager: Initialized with ", camera_components.size(), " components")

func find_camera_components():
	"""Auto-discover camera components"""
	for child in get_children():
		if child is CameraComponent:
			camera_components.append(child)

func setup_components():
	"""Initialize all camera components"""
	for component in camera_components:
		if component:
			component.initialize(self, character, camera, spring_arm)

func connect_to_systems():
	"""Connect to character and input systems"""
	# Connect to character state machine
	if character and character.has_node("CharacterStateMachine"):
		var state_machine = character.get_node("CharacterStateMachine")
		if state_machine.has_signal("state_changed"):
			state_machine.state_changed.connect(_on_character_state_changed)
	
	# Connect to action system for input awareness
	if character and character.has_node("ActionSystem"):
		var action_system = character.get_node("ActionSystem")
		if action_system.has_signal("action_executed"):
			action_system.action_executed.connect(_on_action_executed)

func _physics_process(delta):
	"""Update camera manager"""
	update_input_mode_detection()
	update_active_component(delta)
	update_camera_properties(delta)

# === CAMERA MODE MANAGEMENT ===

func set_camera_mode(mode_name: String, blend_duration: float = -1):
	"""Set camera mode with optional custom blend duration"""
	if mode_name == current_mode:
		return
	
	var component = get_component_by_mode(mode_name)
	if not component:
		push_warning("CameraManager: Mode not found: " + mode_name)
		return
	
	var old_mode = current_mode
	current_mode = mode_name
	
	# Deactivate old component
	if active_component:
		active_component.deactivate()
	
	# Activate new component
	active_component = component
	active_component.activate()
	
	# Get target properties from new component
	target_properties = active_component.get_camera_properties()
	
	# Start blend
	var duration = blend_duration if blend_duration > 0 else (1.0 / blend_speed)
	start_property_blend(duration)
	
	# Emit signals
	camera_blended.emit(old_mode, mode_name, duration)
	emit_camera_state()
	
	print("📹 Camera mode: ", old_mode, " → ", mode_name)

func get_component_by_mode(mode_name: String) -> CameraComponent:
	"""Find component by mode name"""
	for component in camera_components:
		if component and component.mode_name == mode_name:
			return component
	return null

func has_mode(mode_name: String) -> bool:
	"""Check if camera mode exists"""
	return get_component_by_mode(mode_name) != null

# === INPUT MODE DETECTION ===

func update_input_mode_detection():
	"""Detect current input mode and switch camera accordingly"""
	var new_input_mode = detect_input_mode()
	
	if new_input_mode != current_input_mode:
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - last_input_time > input_switch_cooldown:
			switch_input_mode(new_input_mode)
			last_input_time = current_time

func detect_input_mode() -> String:
	"""Detect what input mode is currently active"""
	# Check if mouse is captured (WASD mode)
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return "wasd"
	
	# Check for click navigation ONLY if mouse is visible AND component is active
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		var click_nav = get_click_navigation_component()
		if click_nav and click_nav.is_active():
			return "click"
		else:
			return "disabled"  # Mouse visible but no click navigation
	
	# Default to WASD
	return "wasd"

func switch_input_mode(new_mode: String):
	"""Switch camera behavior based on input mode"""
	current_input_mode = new_mode
	
	match new_mode:
		"wasd":
			set_camera_mode("follow")
		"click":
			set_camera_mode("click_follow")
		"disabled":
			set_camera_mode("follow")  # Stay in follow but may be less responsive
	
	input_mode_changed.emit(new_mode)

# === COMPONENT INTEGRATION ===

func get_click_navigation_component() -> Node:
	"""Get click navigation component from character"""
	if character:
		return character.get_node_or_null("ClickNavigationComponent")
	return null

# === CAMERA PROPERTY BLENDING ===

func update_active_component(delta: float):
	"""Update the currently active camera component"""
	if active_component:
		active_component.update(delta)
		# Get updated target properties
		var new_target = active_component.get_camera_properties()
		if not target_properties.equals(new_target):
			target_properties = new_target

func update_camera_properties(delta: float):
	"""Update camera properties with blending"""
	if not target_properties:
		return
	
	# If no blend is active, blend towards target
	if not blend_tween or not blend_tween.is_valid():
		var blend_delta = blend_speed * delta
		current_properties.blend_towards(target_properties, blend_delta)
		apply_properties_to_camera()

func start_property_blend(duration: float):
	"""Start blending camera properties"""
	if blend_tween:
		blend_tween.kill()
	
	blend_tween = create_tween()
	blend_tween.set_parallel(true)
	
	# Blend FOV
	var target_fov = target_properties.fov
	blend_tween.tween_method(
		func(value): current_properties.fov = value,
		current_properties.fov,
		target_fov,
		duration
	).set_ease(Tween.EASE_OUT)
	
	# Blend distance
	var target_distance = target_properties.distance
	blend_tween.tween_method(
		func(value): current_properties.distance = value,
		current_properties.distance,
		target_distance,
		duration
	).set_ease(Tween.EASE_OUT)
	
	# Blend offset
	var target_offset = target_properties.offset
	blend_tween.tween_method(
		func(value): current_properties.offset = value,
		current_properties.offset,
		target_offset,
		duration
	).set_ease(Tween.EASE_OUT)
	
	# Apply properties during blend
	blend_tween.tween_method(apply_properties_to_camera, 0, 1, duration)

func apply_properties_to_camera():
	"""Apply current properties to actual camera"""
	if camera:
		camera.fov = current_properties.fov
	
	if spring_arm:
		spring_arm.spring_length = current_properties.distance
		spring_arm.position = current_properties.offset

# === SIGNAL HANDLERS ===

func _on_character_state_changed(old_state: String, new_state: String):
	"""Respond to character state changes"""
	# Update active component about state change
	if active_component:
		active_component.on_character_state_changed(old_state, new_state)

func _on_action_executed(action):
	"""Respond to character actions"""
	# Pass action to active component
	if active_component:
		active_component.on_action_executed(action)

# === EXTERNAL CONTROL API ===

func set_external_control(active: bool, controller_name: String = ""):
	"""Allow external control (like CameraCinema)"""
	if active:
		# External control taking over
		if active_component:
			active_component.deactivate()
		print("📹 CameraManager: External control by ", controller_name)
	else:
		# Restore control
		if active_component:
			active_component.activate()
		print("📹 CameraManager: Control restored from ", controller_name)

func is_externally_controlled() -> bool:
	"""Check if under external control"""
	return active_component == null or not active_component.is_component_active()

# === UTILITY METHODS ===

func emit_camera_state():
	"""Emit current camera state"""
	var state = {
		"mode": current_mode,
		"input_mode": current_input_mode,
		"properties": current_properties.to_dict() if current_properties else {},
		"externally_controlled": is_externally_controlled()
	}
	camera_state_changed.emit(state)

func get_debug_info() -> Dictionary:
	"""Get debug information"""
	return {
		"current_mode": current_mode,
		"input_mode": current_input_mode,
		"active_component": active_component.mode_name if active_component else "none",
		"component_count": camera_components.size(),
		"available_modes": get_available_modes(),
		"externally_controlled": is_externally_controlled(),
		"properties": current_properties.to_dict() if current_properties else {}
	}

func get_available_modes() -> Array[String]:
	"""Get list of available camera modes"""
	var modes: Array[String] = []
	for component in camera_components:
		if component:
			modes.append(component.mode_name)
	return modes

# === TESTING HELPERS ===

func test_all_modes():
	"""Test all camera modes"""
	var modes = get_available_modes()
	for mode in modes:
		print("🧪 Testing camera mode: ", mode)
		set_camera_mode(mode)
		await get_tree().create_timer(2.0).timeout
	
	# Return to default
	set_camera_mode(default_mode)
