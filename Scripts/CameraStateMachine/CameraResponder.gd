# CameraResponder.gd - Replaces the camera state machine with simple tweening
extends Node
class_name CameraResponder

@export_group("References")
@export var camera_controller: Node3D  # Your CAMERARIG node
@export var character: CharacterBody3D
@export var camera: Camera3D
@export var spring_arm: SpringArm3D

@export_group("Camera Presets")
@export var default_fov = 75.0
@export var default_distance = 4.0

@export_group("Transition Settings")
@export var transition_speed = 0.3
@export var fast_transition_speed = 0.1

# Current tween reference (to stop previous tweens)
var current_tween: Tween

func _ready():
	# Auto-find references if not assigned
	if not camera_controller:
		camera_controller = get_parent()
	
	if not character:
		character = get_node("../../CHARACTER") as CharacterBody3D
	
	if not camera:
		camera = camera_controller.get_node("SpringArm3D/Camera3D")
	
	if not spring_arm:
		spring_arm = camera_controller.get_node("SpringArm3D")
	
	# Connect to character state changes
	if character and character.state_machine:
		character.state_machine.state_changed.connect(_on_character_state_changed)
		print("✅ CameraResponder: Connected to character state machine")
	else:
		push_error("CameraResponder: Could not find character or state machine")

func _on_character_state_changed(old_state: String, new_state: String):
	"""Respond to character state changes with camera tweening"""
	respond_to_state(new_state)

func respond_to_state(state_name: String):
	"""Main camera response logic - customize this for your needs"""
	
	# Stop any existing tween
	if current_tween:
		current_tween.kill()
	
	# Create new tween
	current_tween = create_tween()
	current_tween.set_parallel(true)  # Allow multiple properties to tween simultaneously
	
	# Define camera responses for each state
	match state_name:
		"idle":
			tween_camera_properties(65.0, 4.0, Vector3.ZERO, transition_speed)
		
		"walking":
			tween_camera_properties(70.0, 4.2, Vector3(0, 0.1, 0), transition_speed)
		
		"running":
			tween_camera_properties(80.0, 4.5, Vector3(0, 0.2, 0), transition_speed, Tween.EASE_OUT)
		
		"jumping":
			tween_camera_properties(85.0, 4.8, Vector3(0, 0.3, 0), fast_transition_speed)
		
		"airborne":
			tween_camera_properties(90.0, 5.0, Vector3(0, 0.4, 0), transition_speed)
		
		"landing":
			tween_camera_properties(75.0, 4.0, Vector3(0, 0.1, 0), fast_transition_speed, Tween.EASE_IN)
		
		_:
			# Default/fallback
			tween_camera_properties(default_fov, default_distance, Vector3.ZERO, transition_speed)

func tween_camera_properties(fov: float = -1, distance: float = -1, offset: Vector3 = Vector3.INF, duration: float = 0.3, ease: Tween.EaseType = Tween.EASE_OUT):
	"""Helper function to tween multiple camera properties"""
	
	if fov > 0:
		current_tween.tween_property(camera, "fov", fov, duration).set_ease(ease)
	
	if distance > 0:
		current_tween.tween_property(spring_arm, "spring_length", distance, duration).set_ease(ease)
	
	if offset != Vector3.INF:
		current_tween.tween_property(camera_controller, "camera_offset", offset, duration).set_ease(ease)

# === SPECIAL CAMERA EFFECTS (for fighting game moments) ===

func camera_dramatic_zoom(target_fov: float, hold_duration: float = 0.5, return_duration: float = 0.3):
	"""Dramatic zoom effect for special moves/impacts"""
	if current_tween:
		current_tween.kill()
	
	var original_fov = camera.fov
	current_tween = create_tween()
	
	# Quick zoom
	current_tween.tween_property(camera, "fov", target_fov, 0.1)
	# Hold
	current_tween.tween_delay(hold_duration)
	# Return
	current_tween.tween_property(camera, "fov", original_fov, return_duration).set_ease(Tween.EASE_OUT)

func camera_impact_shake(intensity: float = 0.5, duration: float = 0.2):
	"""Screen shake for impacts - can be called directly from character states"""
	# Implementation depends on your shake system
	# This is a placeholder
	print("📹 Camera shake: intensity=", intensity, " duration=", duration)

func camera_follow_projectile(projectile: Node3D, return_speed: float = 1.0):
	"""Follow a projectile then return to character"""
	if current_tween:
		current_tween.kill()
	
	current_tween = create_tween()
	# This would need more complex logic to actually follow the projectile
	# Placeholder for the concept
	print("📹 Following projectile")

# === DEBUG/TESTING FUNCTIONS ===

func test_all_states():
	"""Test camera responses for all states"""
	var states = ["idle", "walking", "running", "jumping", "airborne", "landing"]
	for state in states:
		await get_tree().create_timer(1.0).timeout
		respond_to_state(state)
		print("🧪 Testing camera for state: ", state)

func get_debug_info() -> Dictionary:
	"""Get debug information"""
	return {
		"current_fov": camera.fov if camera else 0.0,
		"current_distance": spring_arm.spring_length if spring_arm else 0.0,
		"current_offset": camera_controller.camera_offset if camera_controller else Vector3.ZERO,
		"has_active_tween": current_tween != null and current_tween.is_valid()
	}
