# CameraFocusPoint.gd - Decoupled camera target system
extends Node3D
class_name CameraFocusPoint

@export_group("Target Following")
@export var follow_target: Node3D  # Can be character, enemy, object, anything
@export var target_offset = Vector3(0, 1.5, 0)  # Height offset from target
@export var follow_smoothing = 8.0
@export var enabled = true

@export_group("Focus Transitions")
@export var transition_speed = 4.0  # Speed when switching focus targets

# Internal state
var is_transitioning = false
var transition_start_pos = Vector3.ZERO

func _ready():
	if follow_target:
		# Initialize position immediately
		global_position = follow_target.global_position + target_offset

func _physics_process(delta):
	if not enabled:
		return
	
	if follow_target:
		var target_position = follow_target.global_position + target_offset
		
		if is_transitioning:
			# Faster transition when switching focus
			global_position = global_position.lerp(target_position, transition_speed * delta)
			
			# Check if transition is complete
			if global_position.distance_to(target_position) < 0.1:
				is_transitioning = false
		else:
			# Normal smooth following
			global_position = global_position.lerp(target_position, follow_smoothing * delta)

# === PUBLIC API ===

func set_focus_target(new_target: Node3D, new_offset: Vector3 = Vector3.ZERO):
	"""Change what the camera focuses on with smooth transition"""
	if new_target == follow_target:
		return
	
	follow_target = new_target
	if new_offset != Vector3.ZERO:
		target_offset = new_offset
	
	# Start transition
	is_transitioning = true
	transition_start_pos = global_position
	
	print("CameraFocus: Switching to ", new_target.name if new_target else "null")

func focus_on_character(character: Node3D, height_offset: float = 1.5):
	"""Convenience method for focusing on character"""
	set_focus_target(character, Vector3(0, height_offset, 0))

func focus_on_point(world_position: Vector3, transition_time: float = 1.0):
	"""Focus on a specific world position (creates temporary target)"""
	# Create temporary invisible node at position
	var temp_target = Node3D.new()
	get_tree().current_scene.add_child(temp_target)
	temp_target.global_position = world_position
	
	set_focus_target(temp_target, Vector3.ZERO)
	
	# Auto-cleanup after transition
	var cleanup_timer = get_tree().create_timer(transition_time + 1.0)
	cleanup_timer.timeout.connect(func(): temp_target.queue_free())

func get_focus_position() -> Vector3:
	"""Get current focus position"""
	return global_position
