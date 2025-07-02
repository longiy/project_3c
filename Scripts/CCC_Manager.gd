# CCC_Manager.gd
# Central coordinator for CHARACTER, CAMERA, CONTROL systems
# Root node that manages the CCC framework architecture

extends Node3D
class_name CCC_Manager

# System references
@onready var character_system = $CHARACTER
@onready var camera_system = $CAMERA
@onready var control_system = $CONTROL

# Scene references for quick access
@onready var character_core: CharacterBody3D = $CHARACTER/CharacterCore
@onready var spring_arm: SpringArm3D = $CAMERA/SpringArm3D
@onready var camera_core: Camera3D = $CAMERA/SpringArm3D/Camera3D

# Basic properties
@export var debug_mode: bool = false

func _ready():
	# Verify scene structure
	if not verify_scene_structure():
		push_error("ControlManager: Scene structure invalid - check CCC hierarchy")
		return
	
	# Initialize systems
	initialize_systems()
	
	if debug_mode:
		print("ControlManager: CCC Framework initialized successfully")

func _input(event):
	# Route all input to CONTROL system for processing
	if control_system and control_system.has_method("process_input"):
		control_system.process_input(event)

func _unhandled_input(event):
	# Fallback input handling
	if control_system and control_system.has_method("process_unhandled_input"):
		control_system.process_unhandled_input(event)

func verify_scene_structure() -> bool:
	# Check required nodes exist
	var required_nodes = [
		$CHARACTER,
		$CAMERA, 
		$CONTROL,
		$CHARACTER/CharacterCore,
		$CAMERA/SpringArm3D,
		$CAMERA/SpringArm3D/Camera3D
	]
	
	for node in required_nodes:
		if not node:
			push_error("CCC_Manager: Missing required node - " + str(node))
			return false
	
	# Verify core node types
	if not character_core is CharacterBody3D:
		push_error("CCC_Manager: CharacterCore must be CharacterBody3D")
		return false
		
	if not camera_core is Camera3D:
		push_error("CCC_Manager: Camera3D must be in SpringArm3D/Camera3D")
		return false
		
	if not spring_arm is SpringArm3D:
		push_error("CCC_Manager: SpringArm3D required for camera system")
		return false
	
	return true

func initialize_systems():
	# Set up system cross-references if needed
	if character_system.has_method("set_manager"):
		character_system.set_manager(self)
		
	if camera_system.has_method("set_manager"):
		camera_system.set_manager(self)
		
	if control_system.has_method("set_manager"):
		control_system.set_manager(self)

# Public API for system access
func get_character_core() -> CharacterBody3D:
	return character_core

func get_spring_arm() -> SpringArm3D:
	return spring_arm

func get_camera_core() -> Camera3D:
	return camera_core

func get_camera_system() -> CameraSystem:
	return camera_system

func get_character_system() -> CharacterSystem:
	return character_system

func get_control_system() -> ControlSystem:
	return control_system

# Camera control API for components
func set_camera_target(target: Node3D):
	# Position camera system to follow target
	if target:
		global_position = target.global_position

func apply_camera_rotation(yaw: float, pitch: float):
	# Delegate to camera system
	if camera_system:
		camera_system.apply_rotation(yaw, pitch)
