# FollowCameraComponent.gd - Standard WASD follow camera
class_name FollowCameraComponent
extends CameraComponent

@export_group("Follow Settings")
@export var camera_height: float = 1.6
@export var follow_smoothing: float = 8.0

@export_group("Mouse Look")
@export var mouse_sensitivity: float = 0.002
@export var pitch_min: float = -80.0
@export var pitch_max: float = 50.0

@export_group("Character State Response")
@export var respond_to_states: bool = true
@export var state_transition_speed: float = 0.3

func _ready():
	super._ready()
	mode_name = "follow"

func create_default_properties() -> CameraProperties:
	"""Create follow camera properties"""
	var props = CameraProperties.create_follow_preset()
	props.follow_speed = follow_smoothing
	props.mouse_sensitivity = mouse_sensitivity
	props.pitch_limits = Vector2(pitch_min, pitch_max)
	return props

func update_component(delta: float):
	"""Update follow camera behavior"""
	update_position(delta)
	handle_input()

func update_position(delta: float):
	"""Update camera position to follow character"""
	if not character:
		return
	
	var target_pos = character.global_position + Vector3(0, camera_height, 0)
	update_follow_position(delta, target_pos)

func handle_input():
	"""Handle mouse look input"""
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Mouse delta is handled by action system, we get it from last executed action
		var action_system = character.get_node_or_null("ActionSystem")
		if action_system and action_system.executed_actions.size() > 0:
			var last_action = action_system.executed_actions[-1]
			if last_action.name == "look_delta":
				var mouse_delta = last_action.get_look_delta()
				handle_mouse_look(mouse_delta)

func on_character_state_changed(old_state: String, new_state: String):
	"""Respond to character state changes"""
	if not respond_to_states:
		return
	
	# Update camera properties based on state
	var state_props = CameraProperties.create_state_preset(new_state)
	state_props.follow_speed = follow_smoothing
	state_props.mouse_sensitivity = mouse_sensitivity
	state_props.pitch_limits = Vector2(pitch_min, pitch_max)
	
	# Blend to new properties
	if camera_manager:
		camera_properties = state_props
		print("📹 Follow camera responding to state: ", new_state)

func on_action_executed(action):
	"""Respond to character actions"""
	match action.name:
		"look_delta":
			# Mouse look is handled in update_component
			pass
		"move_start", "move_update":
			# Could add subtle camera anticipation here
			if camera_properties.anticipation > 0:
				modify_anticipation_for_movement(action)

func modify_anticipation_for_movement(action):
	"""Adjust camera anticipation based on movement"""
	var direction = action.get_movement_vector()
	if direction.length() > 0:
		# Slightly anticipate movement direction
		camera_properties.anticipation = 0.1
	else:
		camera_properties.anticipation = 0.0
