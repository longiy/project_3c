# InputVisualFeedback.gd
# Visual feedback system for input method switching
# PHASE 4: Updated to reference InputCore directly, removed InputPriorityManager dependency

extends Control
class_name InputVisualFeedback

# UPDATED: Export reference to InputCore instead of InputPriorityManager
@export var input_core: InputCore

@export_group("UI References")
@export var input_method_label: Label
@export var transition_progress: ProgressBar

@export_group("Visual Settings")
@export var fade_duration: float = 3.0
@export var auto_hide: bool = true

# UPDATED: Color themes for different input types (using InputCore.InputType)
var input_colors: Dictionary = {
	InputCore.InputType.DIRECT: Color.CYAN,
	InputCore.InputType.TARGET: Color.ORANGE, 
	InputCore.InputType.GAMEPAD: Color.GREEN
}

var current_alpha: float = 1.0
var fade_timer: float = 0.0
var is_visible_state: bool = false

func _ready():
	if not input_core:
		push_error("InputVisualFeedback: Please assign InputCore in the Inspector")
		return
	
	connect_to_input_signals()
	setup_ui_elements()
	
	if auto_hide:
		hide_feedback()

func connect_to_input_signals():
	if not input_core:
		return
	
	# UPDATED: Connect to InputCore signals (if they exist)
	if input_core.has_signal("input_method_changed"):
		input_core.input_method_changed.connect(_on_input_method_changed)
	
	if input_core.has_signal("transition_started"):
		input_core.transition_started.connect(_on_transition_started)
	
	if input_core.has_signal("transition_completed"):
		input_core.transition_completed.connect(_on_transition_completed)

func setup_ui_elements():
	# Setup input method label
	if input_method_label:
		input_method_label.text = "DIRECT"
		input_method_label.modulate = input_colors[InputCore.InputType.DIRECT]
	
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
	
	# Update display based on current input
	update_input_display()

func update_input_display():
	if not input_core or not input_method_label:
		return
	
	# Get current input type from InputCore
	var current_input_type = input_core.get_active_input_type()
	var type_name = input_core.get_input_type_name(current_input_type)
	
	# Update display if changed
	if input_method_label.text != type_name:
		input_method_label.text = type_name
		input_method_label.modulate = input_colors[current_input_type]
		show_feedback()

func _on_input_method_changed(new_type: InputCore.InputType, _old_type: InputCore.InputType):
	# UPDATED: Handle InputCore.InputType instead of InputPriorityManager.InputType
	if input_method_label:
		input_method_label.text = input_core.get_input_type_name(new_type)
		input_method_label.modulate = input_colors[new_type]
	
	# Show feedback
	show_feedback()
	fade_timer = 0.0

func _on_transition_started(_from_type: InputCore.InputType, _to_type: InputCore.InputType):
	# Show transition progress
	if transition_progress:
		transition_progress.visible = true
		transition_progress.value = 0.0
	
	show_feedback()

func _on_transition_completed(_final_type: InputCore.InputType):
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

# UPDATED: Update from external source using InputCore types
func update_input_method(input_type: InputCore.InputType):
	if input_method_label:
		input_method_label.text = input_core.get_input_type_name(input_type)
		input_method_label.modulate = input_colors[input_type]
	show_feedback()
