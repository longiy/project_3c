# ClickFollowCameraComponent.gd - Click navigation aware camera
class_name ClickFollowCameraComponent
extends CameraComponent

@export_group("Click Follow Settings")
@export var camera_height: float = 1.8
@export var anticipation_strength: float = 0.4
@export var anticipation_distance: float = 2.0

@export_group("Movement Prediction")
@export var predict_movement: bool = true
@export var prediction_smoothing: float = 6.0

# Click navigation tracking
var click_nav_component: Node
var destination_position: Vector3
var has_destination: bool = false

func _ready():
	super._ready()
	mode_name = "click_follow"

func create_default_properties() -> CameraProperties:
	"""Create click follow camera properties"""
	var props = CameraProperties.create_click_follow_preset()
	props.distance = 4.0  # Match follow camera distance
	props.anticipation = anticipation_strength
	return props

func initialize(manager: CameraManager, char: CharacterBody3D, cam: Camera3D, arm: SpringArm3D):
	"""Initialize and find click navigation component"""
	super.initialize(manager, char, cam, arm)
	
	# Find click navigation component
	if character:
		click_nav_component = character.get_node_or_null("ClickNavigationComponent")
		if not click_nav_component:
			push_warning("ClickFollowCamera: No ClickNavigationComponent found")

func update_component(delta: float):
	"""Update click follow camera behavior"""
	update_click_destination()
	update_position_with_anticipation(delta)

func update_click_destination():
	"""Track click navigation destination"""
	if click_nav_component and click_nav_component.has_method("get_debug_info"):
		var debug_info = click_nav_component.get_debug_info()
		has_destination = debug_info.get("has_destination", false)
		destination_position = debug_info.get("current_destination", Vector3.ZERO)

func update_position_with_anticipation(delta: float):
	"""Update camera position with movement anticipation"""
	if not character:
		return
	
	var base_target = character.global_position + Vector3(0, camera_height, 0)
	var final_target = base_target
	
	if predict_movement and has_destination:
		# Calculate anticipation towards destination
		var to_destination = destination_position - character.global_position
		to_destination.y = 0  # Keep on ground plane
		
		if to_destination.length() > 0.5:  # Only anticipate if destination is far enough
			var anticipation_offset = to_destination.normalized() * anticipation_distance
			final_target += anticipation_offset * anticipation_strength
	
	update_follow_position(delta, final_target)

func on_activate():
	"""Called when switching to click follow mode"""
	print("📹 Click follow camera activated")
	
	# Adjust properties for click navigation
	if camera_properties:
		camera_properties.fov = 70.0
		camera_properties.distance = 4.5
		camera_properties.anticipation = anticipation_strength

func on_deactivate():
	"""Called when switching away from click follow mode"""
	print("📹 Click follow camera deactivated")

func on_action_executed(action):
	"""Respond to character actions"""
	match action.name:
		"move_start", "move_update":
			# Update anticipation based on movement vs destination
			update_movement_anticipation(action)

func update_movement_anticipation(action):
	"""Adjust anticipation based on movement direction vs destination"""
	if not has_destination:
		return
	
	var movement_dir = action.get_movement_vector()
	var to_destination = destination_position - character.global_position
	to_destination.y = 0
	
	if movement_dir.length() > 0 and to_destination.length() > 0:
		# Calculate how aligned movement is with destination
		var movement_3d = character.calculate_movement_vector(movement_dir)
		var alignment = movement_3d.dot(to_destination.normalized())
		
		# Stronger anticipation when moving towards destination
		var dynamic_anticipation = anticipation_strength * clamp(alignment, 0.2, 1.0)
		camera_properties.anticipation = dynamic_anticipation

func get_debug_info() -> Dictionary:
	"""Get debug information"""
	var base_info = super.get_debug_info()
	base_info.merge({
		"has_click_nav": click_nav_component != null,
		"has_destination": has_destination,
		"destination": destination_position,
		"anticipation_strength": anticipation_strength
	})
	return base_info
