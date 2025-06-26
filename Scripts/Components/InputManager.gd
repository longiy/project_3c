# InputManager.gd - FIXED: Prevent aggressive click nav cancellation
extends Node
class_name InputManager

@export_group("Input Settings")
@export var input_deadzone = 0.05
@export var movement_update_frequency = 60

var action_system: ActionSystem
var character: CharacterBody3D
var camera_rig: CameraRig

var current_raw_input = Vector2.ZERO
var last_sent_input = Vector2.ZERO
var movement_active = false
var movement_start_time = 0.0

@export var input_component_priority: Array[String] = ["ClickNavigation", "Gamepad"]
var input_components: Array[Node] = []

var movement_update_timer = 0.0
var movement_update_interval: float

signal click_input_received(event_type: String, event_data: Dictionary)

func _ready():
	character = get_parent() as CharacterBody3D
	if not character:
		push_error("InputManager must be child of CharacterBody3D")
		return
	
	movement_update_interval = 1.0 / movement_update_frequency
	
	action_system = character.get_node_or_null("ActionSystem")
	if not action_system:
		push_error("InputManager requires ActionSystem as sibling")
		return
	
	camera_rig = get_node_or_null("../../CAMERARIG") as CameraRig
	if not camera_rig:
		push_warning("No CameraRig found - click navigation may not work")
	
	call_deferred("find_input_components")

func _input(event):
	if handle_discrete_input(event):
		return
	
	if camera_rig:
		if camera_rig.is_in_click_navigation_mode():
			handle_click_navigation_input(event)

func _physics_process(delta):
	handle_movement_input(delta)

func handle_discrete_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				action_system.request_action("jump")
				return true
			KEY_ENTER when Input.is_action_pressed("reset"):
				action_system.request_action("reset")
				return true
	
	if event.is_action_pressed("sprint"):
		action_system.request_action("sprint_start")
		return true
	elif event.is_action_released("sprint"):
		action_system.request_action("sprint_end")
		return true
	
	if event.is_action_pressed("walk"):
		action_system.request_action("slow_walk_start")
		return true
	elif event.is_action_released("walk"):
		action_system.request_action("slow_walk_end")
		return true
	
	return false

func handle_click_navigation_input(event: InputEvent):
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				var event_type = "left_click_pressed" if event.pressed else "left_click_released"
				var event_data = {"position": event.position}
				click_input_received.emit(event_type, event_data)
				print("📝 Click nav: ", event_type, " at ", event.position)
	
	elif event is InputEventMouseMotion:
		var event_data = {"position": event.position, "relative": event.relative}
		click_input_received.emit("mouse_motion", event_data)

func handle_movement_input(delta: float):
	movement_update_timer += delta
	
	var new_input = get_current_movement_input()
	var input_magnitude = new_input.length()
	var has_input = input_magnitude > input_deadzone
	
	if not has_input:
		new_input = Vector2.ZERO
	
	var was_moving = movement_active
	var is_moving = has_input
	
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
	
	elif not is_moving and was_moving:
		movement_active = false
		current_raw_input = Vector2.ZERO
		last_sent_input = Vector2.ZERO
		
		action_system.request_action("move_end")
		print("📝 Movement ended")
	
	elif is_moving and movement_update_timer >= movement_update_interval:
		if new_input.distance_to(last_sent_input) > 0.1:
			current_raw_input = new_input
			last_sent_input = new_input
			
			action_system.request_action("move_update", {
				"direction": new_input,
				"magnitude": input_magnitude,
				"duration": get_movement_duration()
			})
		
		movement_update_timer = 0.0

func get_current_movement_input() -> Vector2:
	"""FIXED: Less aggressive component cancellation"""
	
	# WASD always has highest priority
	var wasd_input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if wasd_input.length() > input_deadzone:
		# FIXED: Only cancel components if WASD is actually being used
		cancel_all_input_components()
		print("📝 Using WASD input: ", wasd_input)
		return wasd_input
	
	# Check input components by priority (only in click nav mode)
	if camera_rig and camera_rig.is_in_click_navigation_mode():
		for component_name in input_component_priority:
			var component = get_component_by_name(component_name)
			if component and is_component_active(component):
				var component_input = component.get_movement_input()
				if component_input and component_input.length() > input_deadzone:
					print("📝 Using ", component_name, " input: ", component_input)
					return component_input
	
	return Vector2.ZERO

func get_component_by_name(component_name: String) -> Node:
	for component in input_components:
		if component.name.contains(component_name):
			return component
	return null

func is_component_active(component: Node) -> bool:
	if not is_instance_valid(component):
		return false
	
	if component.has_method("is_active"):
		return component.is_active()
	
	return false

func cancel_all_input_components():
	"""FIXED: Only cancel when WASD is actually active"""
	print("📝 Cancelling all input components due to WASD usage")
	for component in input_components:
		if component and component.has_method("cancel_input"):
			component.cancel_input()

func find_input_components():
	input_components.clear()
	
	for child in character.get_children():
		if child == self:
			continue
		if child.has_method("get_movement_input"):
			input_components.append(child)
			print("📝 InputManager: Found input component: ", child.name)
	
	print("📝 InputManager: Total input components: ", input_components.size())

func get_movement_duration() -> float:
	if movement_active:
		return (Time.get_ticks_msec() / 1000.0) - movement_start_time
	return 0.0

func is_movement_active() -> bool:
	return movement_active

func get_current_input_direction() -> Vector2:
	return current_raw_input

func get_debug_info() -> Dictionary:
	return {
		"movement_active": movement_active,
		"current_input": current_raw_input,
		"movement_duration": get_movement_duration(),
		"component_count": input_components.size(),
		"active_components": get_active_components(),
		"action_system_connected": action_system != null,
		"camera_mode": camera_rig.get_mode_name(camera_rig.get_current_mode()) if camera_rig else "unknown",
		"click_nav_available": camera_rig and camera_rig.is_in_click_navigation_mode()
	}

func get_active_components() -> Array[String]:
	var active: Array[String] = []
	for component in input_components:
		if is_component_active(component):
			active.append(component.name)
	return active
