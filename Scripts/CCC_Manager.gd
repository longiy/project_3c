# CCC_Manager.gd
# Central coordinator for CHARACTER, CAMERA, CONTROL systems
# Refactored: Export variables instead of absolute paths

extends Node3D
class_name CCC_Manager

# Export references - assign in inspector for modularity
@export_group("System References")
@export var character_system: CharacterSystem
@export var camera_system: CameraSystem
@export var control_system: ControlSystem

@export_group("Core Node References")
@export var character_core: CharacterBody3D
@export var spring_arm: SpringArm3D
@export var camera_core: Camera3D

@export_group("Debug")
@export var debug_mode: bool = false
@export var debug_label: Label

func _ready():
	if not verify_references():
		return
	
	initialize_systems()
	
	if debug_mode:
		set_process(true)

func _process(_delta):
	if debug_mode and debug_label:
		update_debug_display()

func _input(event):
	if control_system:
		control_system.process_input(event)

func _unhandled_input(event):
	if control_system:
		control_system.process_unhandled_input(event)

func verify_references() -> bool:
	var missing_refs = []
	
	if not character_system: missing_refs.append("character_system")
	if not camera_system: missing_refs.append("camera_system")
	if not control_system: missing_refs.append("control_system")
	if not character_core: missing_refs.append("character_core")
	if not spring_arm: missing_refs.append("spring_arm")
	if not camera_core: missing_refs.append("camera_core")
	
	if missing_refs.size() > 0:
		push_error("CCC_Manager: Missing references: " + str(missing_refs))
		return false
	
	# Verify node types
	if not character_core is CharacterBody3D:
		push_error("CCC_Manager: character_core must be CharacterBody3D")
		return false
	
	if not camera_core is Camera3D:
		push_error("CCC_Manager: camera_core must be Camera3D")
		return false
	
	if not spring_arm is SpringArm3D:
		push_error("CCC_Manager: spring_arm must be SpringArm3D")
		return false
	
	return true

func initialize_systems():
	# Set manager references
	if character_system and character_system.has_method("set_manager"):
		character_system.set_manager(self)
	
	if camera_system and camera_system.has_method("set_manager"):
		camera_system.set_manager(self)
	
	if control_system and control_system.has_method("set_manager"):
		control_system.set_manager(self)

func update_debug_display():
	var debug_text = ""
	debug_text += "CHARACTER: " + ("✓" if character_system else "✗") + "\n"
	debug_text += "CAMERA: " + ("✓" if camera_system else "✗") + "\n"
	debug_text += "CONTROL: " + ("✓" if control_system else "✗") + "\n"
	
	# Input system status
	if control_system and control_system.input_core:
		var priority_mgr = control_system.input_core.input_priority_manager
		if priority_mgr:
			var input_type = priority_mgr.get_active_input_type()
			debug_text += "Input: " + priority_mgr.get_input_type_name(input_type) + "\n"
	
	debug_label.text = debug_text
