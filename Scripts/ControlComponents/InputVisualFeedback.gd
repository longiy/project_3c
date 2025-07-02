# InputVisualFeedback.gd
# Visual feedback system for input method switching
# Fixed: Removed dependency on missing methods, simplified

extends Control
class_name InputVisualFeedback

# Export reference instead of onready
@export var input_priority_manager: InputPriorityManager

@export_group("UI References")
@export var input_method_label: Label
@export var transition_progress: ProgressBar

@export_group("Visual Settings")
@export var fade_duration: float = 3.0
@export var auto_hide: bool = true

# Color themes for different input types
var input_colors: Dictionary = {
	InputPriorityManager.InputType.DIRECT: Color.CYAN,
	InputPriorityManager.InputType.TARGET: Color.ORANGE, 
	InputPriorityManager.InputType.GAMEPAD: Color.GREEN
}

var current_alpha: float = 1.0
var fade_timer: float = 0.0
var is_visible_state: bool = false

func _ready():
	if not input_priority_manager:
		push_error("InputVisualFeedback: Please assign InputPriorityManager in the Inspector")
		return
	
	connect_to_input_signals()
	setup_ui_elements()
	
	if auto_hide:
		hide_feedback()

func connect_to_input_signals():
	if not input_priority_manager:
		return
	
	# Connect to available signals
	if input_priority_manager.has_signal("input_method_changed"):
		input_priority_manager.input_method_changed.connect(_on_input_method_changed)
	
	if input_priority_manager.has_signal("transition_started"):
		input_priority_manager.transition_started.connect(_on_transition_started)
	
	if input_priority_manager.has_signal("transition_completed"):
		input_priority_manager.transition_completed.connect(_on_transition_completed)

func setup_ui_elements():
	# Setup input method label
	if input_method_label:
		input_method_label.text = "DIRECT"
		input_method_label.modulate = input_colors[InputPriorityManager.InputType.DIRECT]
	
	# Setup transition progress bar
	if transition_progress:
		transition_progress.visible = false
		transition_progress.value = 0.0

func _process(delta):
	# Handle auto-hide timing
	if auto_hide and is_visible_state:
		fade_timer += delta
		if fade_timer > fade_duration:
			hide_feedback()
	
	# Update transition progress if available
	update_transition_display()

func update_transition_display():
	if not transition_progress or not input_priority_manager:
		return
	
	# Get transition info if method exists
	if input_priority_manager.has_method("get_transition_progress"):
		var progress = input_priority_manager.get_transition_progress()
		transition_progress.value = progress

func _on_input_method_changed(new_type: InputPriorityManager.InputType, _old_type: InputPriorityManager.InputType):
	# Update input method display
	if input_method_label:
		input_method_label.text = input_priority_manager.get_input_type_name(new_type)
		input_method_label.modulate = input_colors[new_type]
	
	# Show feedback
	show_feedback()
	fade_timer = 0.0

func _on_transition_started(_from_type: InputPriorityManager.InputType, _to_type: InputPriorityManager.InputType):
	# Show transition progress
	if transition_progress:
		transition_progress.visible = true
		transition_progress.value = 0.0
	
	show_feedback()

func _on_transition_completed(_final_type: InputPriorityManager.InputType):
	# Hide transition progress
	if transition_progress:
		transition_progress.visible = false
	
	# Start fade timer
	fade_timer = 0.0

func show_feedback():
	if not is_visible_state:
		is_visible_state = true
		visible = true
		
		# Animate appearance
		var tween = create_tween()
		modulate.a = 0.0
		tween.tween_property(self, "modulate:a", 1.0, 0.2)

func hide_feedback():
	if is_visible_state:
		is_visible_state = false
		
		# Animate disappearance
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.3)
		tween.tween_callback(func(): visible = false)

# Manual control API
func force_show():
	auto_hide = false
	show_feedback()

func force_hide():
	auto_hide = false
	hide_feedback()

func set_auto_hide(enabled: bool):
	auto_hide = enabled
	fade_timer = 0.0

# Update from external source
func update_input_method(input_type: InputPriorityManager.InputType):
	if input_method_label:
		input_method_label.text = input_priority_manager.get_input_type_name(input_type)
		input_method_label.modulate = input_colors[input_type]
	show_feedback()
