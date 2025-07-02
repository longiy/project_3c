# InputVisualFeedback.gd
# Visual feedback system for input method switching
# Displays active input method and transition states

extends Control
class_name InputVisualFeedback

# UI elements
@onready var input_method_label: Label = $VBoxContainer/InputMethodLabel
@onready var activity_bars: VBoxContainer = $VBoxContainer/ActivityBars
@onready var transition_progress: ProgressBar = $VBoxContainer/TransitionProgress
@onready var status_panel: Panel = $StatusPanel

# Visual feedback settings
@export_group("Visual Settings")
@export var fade_duration: float = 3.0
@export var show_activity_bars: bool = true
@export var show_transition_progress: bool = true
@export var auto_hide: bool = true

# Color themes for different input types
var input_colors: Dictionary = {
	InputPriorityManager.InputType.DIRECT: Color.CYAN,
	InputPriorityManager.InputType.TARGET: Color.ORANGE, 
	InputPriorityManager.InputType.GAMEPAD: Color.GREEN
}

@export var input_priority_manager: InputPriorityManager
var current_alpha: float = 1.0
var fade_timer: float = 0.0
var is_visible_state: bool = false

# Activity tracking
var activity_bar_nodes: Dictionary = {}

func _ready():
	# Check if InputPriorityManager is assigned
	if not input_priority_manager:
		push_error("InputVisualFeedback: Please assign InputPriorityManager in the Inspector")
		return
	
	# Connect to InputPriorityManager signals
	connect_to_input_signals()
	
	# Setup UI elements
	setup_ui_elements()
	
	# Initially hidden
	if auto_hide:
		hide_feedback()

func connect_to_input_signals():
	if not input_priority_manager:
		return
	
	# Connect to priority manager signals
	input_priority_manager.input_method_changed.connect(_on_input_method_changed)
	input_priority_manager.input_activity_detected.connect(_on_input_activity_detected)
	input_priority_manager.transition_started.connect(_on_transition_started)
	input_priority_manager.transition_completed.connect(_on_transition_completed)

func setup_ui_elements():
	# Setup input method label
	if input_method_label:
		input_method_label.text = "DIRECT"
		input_method_label.modulate = input_colors[InputPriorityManager.InputType.DIRECT]
	
	# Setup activity bars
	if activity_bars and show_activity_bars:
		create_activity_bars()
	
	# Setup transition progress bar
	if transition_progress:
		transition_progress.visible = show_transition_progress
		transition_progress.value = 0.0

func create_activity_bars():
	# Create activity bars for each input type
	var input_types = [
		InputPriorityManager.InputType.DIRECT,
		InputPriorityManager.InputType.TARGET,
		InputPriorityManager.InputType.GAMEPAD
	]
	
	for input_type in input_types:
		var container = HBoxContainer.new()
		activity_bars.add_child(container)
		
		var label = Label.new()
		label.text = input_priority_manager.get_input_type_name(input_type)
		label.custom_minimum_size.x = 80
		container.add_child(label)
		
		var progress_bar = ProgressBar.new()
		progress_bar.custom_minimum_size.x = 100
		progress_bar.custom_minimum_size.y = 20
		progress_bar.max_value = 1.0
		progress_bar.value = 0.0
		progress_bar.modulate = input_colors[input_type]
		container.add_child(progress_bar)
		
		activity_bar_nodes[input_type] = progress_bar

func _process(delta):
	# Handle auto-hide timing
	if auto_hide and is_visible_state:
		fade_timer += delta
		if fade_timer > fade_duration:
			hide_feedback()
	
	# Update activity bars
	if show_activity_bars:
		update_activity_bars()

func update_activity_bars():
	if not input_priority_manager:
		return
	
	var activity_levels = input_priority_manager.get_all_activity_levels()
	
	for input_type in activity_bar_nodes:
		var bar = activity_bar_nodes[input_type]
		var type_name = input_priority_manager.get_input_type_name(input_type)
		var activity_level = activity_levels.get(type_name, 0.0)
		
		# Smooth bar animation
		bar.value = lerp(bar.value, activity_level, 0.1)

func _on_input_method_changed(new_type: InputPriorityManager.InputType, old_type: InputPriorityManager.InputType):
	# Update input method display
	if input_method_label:
		input_method_label.text = input_priority_manager.get_input_type_name(new_type)
		input_method_label.modulate = input_colors[new_type]
	
	# Show feedback
	show_feedback()
	
	# Reset fade timer
	fade_timer = 0.0

func _on_input_activity_detected(input_type: InputPriorityManager.InputType, activity_level: float):
	# Show brief activity feedback
	if activity_level > 0.5:  # Only show for significant activity
		show_feedback()
		fade_timer = max(fade_timer - 0.5, 0.0)  # Extend visibility

func _on_transition_started(from_type: InputPriorityManager.InputType, to_type: InputPriorityManager.InputType):
	# Show transition progress
	if transition_progress and show_transition_progress:
		transition_progress.visible = true
		transition_progress.value = 0.0
	
	show_feedback()

func _on_transition_completed(final_type: InputPriorityManager.InputType):
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

# Update transition progress from external source
func update_transition_progress(progress: float):
	if transition_progress and show_transition_progress:
		transition_progress.value = progress
