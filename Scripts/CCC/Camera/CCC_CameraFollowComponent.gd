# CameraFollowComponent.gd - Smooth camera following behavior
extends Node
class_name CCC_CameraFollowComponent

# === SIGNALS ===
signal target_acquired(target: Node3D)
signal target_lost()
signal follow_position_changed(new_position: Vector3)

# === EXPORTS ===
@export_group("Required References")
@export var camera_core: CCC_CameraCore
@export var camera_rig: Node3D  # The rig that follows the target
@export var target_node: Node3D  # What to follow
@export var config_component: Node  # 3CConfigComponent

@export_group("Follow Properties")
@export var enable_smooth_following: bool = true
@export var enable_height_offset: bool = true
@export var enable_debug_output: bool = false

# === FOLLOW STATE ===
var target_position: Vector3 = Vector3.ZERO
var last_target_position: Vector3 = Vector3.ZERO
var follow_active: bool = false

func _ready():
	validate_setup()
	setup_initial_follow()
	
	if enable_debug_output:
		print("CameraFollowComponent: Initialized")

func validate_setup():
	"""Validate required references"""
	if not camera_core:
		push_error("CameraFollowComponent: camera_core reference required")
	
	if not camera_rig:
		push_error("CameraFollowComponent: camera_rig reference required")
	
	if not config_component:
		push_error("CameraFollowComponent: config_component reference required")

func setup_initial_follow():
	"""Setup initial following state"""
	if target_node:
		set_follow_target(target_node)

func _process(delta):
	"""Update camera following"""
	if follow_active and target_node:
		update_follow_position(delta)

# === FOLLOW CONTROL ===

func set_follow_target(new_target: Node3D):
	"""Set new target to follow"""
	if new_target == target_node:
		return
	
	target_node = new_target
	
	if target_node:
		follow_active = true
		update_target_position()
		
		# Set initial position immediately
		if camera_rig:
			camera_rig.global_position = target_position
		
		target_acquired.emit(target_node)
		
		if enable_debug_output:
			print("CameraFollowComponent: Target acquired - ", target_node.name)
	else:
		follow_active = false
		target_lost.emit()
		
		if enable_debug_output:
			print("CameraFollowComponent: Target lost")

func update_follow_position(delta: float):
	"""Update camera position to follow target"""
	if not target_node or not camera_rig:
		return
	
	update_target_position()
	
	if enable_smooth_following:
		update_smooth_following(delta)
	else:
		camera_rig.global_position = target_position

func update_target_position():
	"""Calculate target position with height offset"""
	if not target_node:
		return
	
	var base_position = target_node.global_position
	
	if enable_height_offset:
		var height_offset = get_config_value("camera_height_offset", 1.6)
		target_position = base_position + Vector3(0, height_offset, 0)
	else:
		target_position = base_position

func update_smooth_following(delta: float):
	"""Update position with smooth following"""
	if not camera_rig:
		return
	
	var follow_speed = get_config_value("camera_smoothing", 8.0)
	var current_position = camera_rig.global_position
	
	var new_position = current_position.lerp(target_position, follow_speed * delta)
	camera_rig.global_position = new_position
	
	# Emit signal if position changed significantly
	if current_position.distance_to(new_position) > 0.01:
		follow_position_changed.emit(new_position)

# === ADVANCED FOLLOW BEHAVIORS ===

func set_follow_smoothing(smoothing: float):
	"""Set follow smoothing speed"""
	if config_component and config_component.has_method("set_config_value"):
		config_component.set_config_value("camera_smoothing", smoothing)

func set_height_offset(offset: float):
	"""Set camera height offset"""
	if config_component and config_component.has_method("set_config_value"):
		config_component.set_config_value("camera_height_offset", offset)

func enable_look_ahead(enabled: bool):
	"""Enable/disable look-ahead behavior (for future implementation)"""
	# Placeholder for look-ahead following
	if enable_debug_output:
		print("CameraFollowComponent: Look-ahead set to ", enabled)

# === TELEPORT AND SNAP ===

func snap_to_target():
	"""Immediately snap camera to target position"""
	if target_node and camera_rig:
		update_target_position()
		camera_rig.global_position = target_position
		
		if enable_debug_output:
			print("CameraFollowComponent: Snapped to target")

func teleport_to_position(position: Vector3):
	"""Teleport camera to specific position"""
	if camera_rig:
		camera_rig.global_position = position
		
		if enable_debug_output:
			print("CameraFollowComponent: Teleported to ", position)

# === PUBLIC API ===

func get_follow_target() -> Node3D:
	"""Get current follow target"""
	return target_node

func is_following() -> bool:
	"""Check if actively following a target"""
	return follow_active and target_node != null

func get_target_position() -> Vector3:
	"""Get calculated target position"""
	return target_position

func get_distance_to_target() -> float:
	"""Get distance between camera and target"""
	if not camera_rig or not target_node:
		return 0.0
	
	return camera_rig.global_position.distance_to(target_position)

func is_at_target() -> bool:
	"""Check if camera is at target position"""
	return get_distance_to_target() < 0.1

func stop_following():
	"""Stop following current target"""
	set_follow_target(null)

func resume_following():
	"""Resume following if target exists"""
	if target_node:
		follow_active = true

# === CONFIGURATION ===

func get_config_value(property_name: String, default_value):
	"""Get configuration value safely"""
	if config_component and config_component.has_method("get_config_value"):
		return config_component.get_config_value(property_name, default_value)
	return default_value

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get debug information about follow component"""
	return {
		"follow_active": follow_active,
		"has_target": target_node != null,
		"target_name": target_node.name if target_node else "None",
		"target_position": target_position,
		"camera_position": camera_rig.global_position if camera_rig else Vector3.ZERO,
		"distance_to_target": get_distance_to_target(),
		"is_at_target": is_at_target(),
		"smooth_following": enable_smooth_following,
		"height_offset_enabled": enable_height_offset
	}
