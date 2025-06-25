# CameraComponent.gd - Base class for modular camera components
class_name CameraComponent
extends Node

# === COMPONENT IDENTITY ===
@export var mode_name: String = "follow"
@export var component_enabled: bool = true

# === CORE REFERENCES ===
var camera_manager: CameraManager
var character: CharacterBody3D
var camera: Camera3D
var spring_arm: SpringArm3D

# === COMPONENT STATE ===
var is_active: bool = false
var camera_properties: CameraProperties
var time_active: float = 0.0

# === ROTATION STATE ===
var current_rotation_x: float = 0.0
var current_rotation_y: float = 0.0

func _ready():
	# Create default properties
	camera_properties = create_default_properties()

# === INITIALIZATION ===

func initialize(manager: CameraManager, char: CharacterBody3D, cam: Camera3D, arm: SpringArm3D):
	"""Initialize component with references"""
	camera_manager = manager
	character = char
	camera = cam
	spring_arm = arm
	
	# Setup initial rotation from current state
	if manager:
		current_rotation_x = deg_to_rad(-20.0)  # Default pitch
		current_rotation_y = manager.rotation.y
	
	print("📹 ", mode_name, " component initialized")

# === VIRTUAL METHODS (Override in child classes) ===

func create_default_properties() -> CameraProperties:
	"""Override to create component-specific default properties"""
	return CameraProperties.create_follow_preset()

func activate():
	"""Called when this component becomes active"""
	is_active = true
	time_active = 0.0
	on_activate()

func deactivate():
	"""Called when this component becomes inactive"""
	is_active = false
	on_deactivate()

func update(delta: float):
	"""Called every frame when active"""
	if not is_active:
		return
	
	time_active += delta
	update_component(delta)

func on_activate():
	"""Override for component-specific activation logic"""
	pass

func on_deactivate():
	"""Override for component-specific deactivation logic"""
	pass

func update_component(delta: float):
	"""Override for component-specific update logic"""
	pass

func on_character_state_changed(old_state: String, new_state: String):
	"""Override to respond to character state changes"""
	pass

func on_action_executed(action):
	"""Override to respond to character actions"""
	pass

# === MOUSE LOOK HELPERS ===

func handle_mouse_look(mouse_delta: Vector2):
	"""Standard mouse look implementation"""
	if not camera_properties:
		return
	
	var sensitivity = camera_properties.mouse_sensitivity
	
	# Update rotation
	current_rotation_y -= mouse_delta.x * sensitivity
	current_rotation_x -= mouse_delta.y * sensitivity
	
	# Apply limits
	if camera_properties.pitch_limits != Vector2.ZERO:
		current_rotation_x = clamp(
			current_rotation_x,
			deg_to_rad(camera_properties.pitch_limits.x),
			deg_to_rad(camera_properties.pitch_limits.y)
		)
	
	if camera_properties.yaw_limits != Vector2.ZERO:
		current_rotation_y = clamp(
			current_rotation_y,
			deg_to_rad(camera_properties.yaw_limits.x),
			deg_to_rad(camera_properties.yaw_limits.y)
		)
	
	# Apply to camera manager
	if camera_manager:
		camera_manager.rotation.y = current_rotation_y
	
	if spring_arm:
		spring_arm.rotation.x = current_rotation_x

# === FOLLOW HELPERS ===

func update_follow_position(delta: float, target_position: Vector3):
	"""Standard position following"""
	if not camera_manager or not camera_properties:
		return
	
	var current_pos = camera_manager.global_position
	var speed = camera_properties.follow_speed
	
	# Apply anticipation if movement is detected
	var anticipated_pos = target_position
	if camera_properties.anticipation > 0 and character:
		var velocity = character.velocity
		if velocity.length() > 0.1:
			anticipated_pos += velocity.normalized() * camera_properties.anticipation
	
	# Smooth movement
	var new_pos = current_pos.lerp(anticipated_pos, speed * delta)
	camera_manager.global_position = new_pos

# === PROPERTY MANAGEMENT ===

func get_camera_properties() -> CameraProperties:
	"""Get current camera properties"""
	return camera_properties

func set_camera_properties(props: CameraProperties):
	"""Set new camera properties"""
	camera_properties = props

func modify_property(property_name: String, value):
	"""Modify a specific property"""
	if camera_properties:
		camera_properties.set(property_name, value)

# === STATE HELPERS ===

func is_component_active() -> bool:
	"""Check if component is active"""
	return is_active

func get_time_active() -> float:
	"""Get time component has been active"""
	return time_active

# === UTILITY METHODS ===

func get_character_input_direction() -> Vector2:
	"""Get character's current input direction"""
	if character and character.has_method("get_current_input_direction"):
		return character.get_current_input_direction()
	return Vector2.ZERO

func get_character_velocity() -> Vector3:
	"""Get character's velocity"""
	if character:
		return character.velocity
	return Vector3.ZERO

func get_character_state() -> String:
	"""Get character's current state"""
	if character and character.has_method("get_current_state_name"):
		return character.get_current_state_name()
	return "unknown"

# === DEBUG ===

func get_debug_info() -> Dictionary:
	"""Get debug information"""
	return {
		"mode_name": mode_name,
		"is_active": is_active,
		"time_active": time_active,
		"enabled": component_enabled,
		"has_properties": camera_properties != null,
		"character_state": get_character_state(),
		"rotation_x": rad_to_deg(current_rotation_x),
		"rotation_y": rad_to_deg(current_rotation_y)
	}

# === VALIDATION ===

func _get_configuration_warnings() -> PackedStringArray:
	"""Provide editor warnings"""
	var warnings = PackedStringArray()
	
	if mode_name.is_empty():
		warnings.append("Mode name must be set")
	
	return warnings
