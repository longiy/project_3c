# CameraInput.gd - Input handling module
extends Node
class_name CameraInput

# === EXPORTS ===
@export_group("Mouse Look")
@export var mouse_sensitivity = 0.002
@export var invert_y = false

@export_group("Zoom")
@export var scroll_zoom_speed = 0.5

# === CONTROLLER REFERENCE ===
var controller: CameraController

func setup_controller_reference(camera_controller: CameraController):
	controller = camera_controller

# === INPUT HANDLING ===

func handle_input(event: InputEvent):
	if not controller or not controller.enable_camera_rig or controller.is_externally_controlled:
		return
	
	# Handle mode switching (right-click)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		controller.toggle_camera_mode()
		return
	
	# Handle input based on current mode
	match controller.current_mode:
		CameraController.CameraMode.ORBIT:
			handle_orbit_input(event)
		CameraController.CameraMode.CLICK_NAVIGATION:
			handle_click_nav_input(event)

func handle_orbit_input(event: InputEvent):
	"""Handle input in orbit mode - mouse look + scroll zoom"""
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		handle_mouse_orbit(event.relative)
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				handle_zoom_direct(-scroll_zoom_speed)
			MOUSE_BUTTON_WHEEL_DOWN:
				handle_zoom_direct(scroll_zoom_speed)

func handle_click_nav_input(event: InputEvent):
	"""Handle input in click navigation mode - scroll zoom only"""
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				handle_zoom_direct(-scroll_zoom_speed)
			MOUSE_BUTTON_WHEEL_DOWN:
				handle_zoom_direct(scroll_zoom_speed)

func handle_mouse_orbit(mouse_delta: Vector2):
	"""Process mouse orbit movement"""
	if controller:
		controller.apply_mouse_orbit(mouse_delta, mouse_sensitivity, invert_y)

func handle_zoom_direct(zoom_delta: float):
	"""Process zoom input"""
	if controller:
		controller.apply_zoom(zoom_delta)
