# 3C Framework Refactor for Your Godot Project X

Looking at your current project structure and the 3C framework we've developed, here's how to refactor your character controller to explicitly use the 3C architecture:

## Current State Analysis

What you already have:

- **Character**: ControllerCharacter.gd with MovementManager, state machine
- **Camera**: CameraRig with ORBIT/CLICK_NAVIGATION modes  
- **Control**: InputManager with movement/click handling

The good news: Your project already follows 3C principles intuitively! The refactor is about making it explicit and configurable.

## Proposed 3C Refactor Structure

### Core 3C Configuration System

```
CHARACTER/
├── ControllerCharacter.gd (main coordinator)
├── CharacterConfig.gd (3C configuration resource)
├── CharacterComponent/ (Character axis)
│   ├── AvatarComponent.gd
│   ├── ObserverComponent.gd
│   └── ControllerComponent.gd
├── CameraComponent/ (Camera axis)
│   ├── OrbitalCamera.gd
│   ├── FollowingCamera.gd
│   ├── FixedCamera.gd
│   └── FirstPersonCamera.gd
└── ControlComponent/ (Control axis)
    ├── DirectControl.gd
    ├── TargetBasedControl.gd
    ├── GuidedControl.gd
    └── ConstructiveControl.gd
```

## Phase 1: Create 3C Configuration Resource

### CharacterConfig.gd

```gdscript
extends Resource
class_name CharacterConfig

enum CharacterType { AVATAR, OBSERVER, CONTROLLER, COLLABORATOR }
enum CameraType { ORBITAL, FOLLOWING, FIXED, FIRST_PERSON, RESPONSIVE }
enum ControlType { DIRECT, TARGET_BASED, GUIDED, CONSTRUCTIVE }

@export var config_name: String = "Default 3C Config"

@export_group("Character Axis")
@export var character_type: CharacterType = CharacterType.AVATAR
@export var character_responsiveness: float = 1.0
@export var character_embodiment_quality: float = 1.0

@export_group("Camera Axis")
@export var camera_type: CameraType = CameraType.ORBITAL
@export var camera_distance: float = 4.0
@export var camera_smoothing: float = 8.0
@export var camera_fov: float = 75.0

@export_group("Control Axis")
@export var control_type: ControlType = ControlType.DIRECT
@export var control_precision: float = 1.0
@export var control_complexity: float = 1.0

@export_group("Temporal Context")
@export var temporal_scope_description: String = "Minute-to-minute gameplay"
@export var experience_duration_target: float = 300.0  # 5 minutes default
```

## Phase 2: Refactor Existing Components

### Character Axis Refactor

#### AvatarComponent.gd (your current character behavior)

```gdscript
extends Node
class_name AvatarComponent

@export var config: CharacterConfig

func configure_from_3c(config: CharacterConfig):
	# Apply character axis configuration
	match config.character_type:
		CharacterConfig.CharacterType.AVATAR:
			setup_avatar_behavior()
		CharacterConfig.CharacterType.CONTROLLER:
			setup_controller_behavior()
		# etc.

func setup_avatar_behavior():
	# Your current MovementManager logic
	pass
```

### Camera Axis Refactor

#### CameraRig.gd - Updated (your existing CameraRig becomes the coordinator)

```gdscript
func configure_from_3c(config: CharacterConfig):
	match config.camera_type:
		CharacterConfig.CameraType.ORBITAL:
			set_camera_mode(CameraMode.ORBIT)
		CharacterConfig.CameraType.FIXED:
			setup_fixed_camera_mode()
		# etc.
	
	# Apply camera parameters
	target_distance = config.camera_distance
	follow_smoothing = config.camera_smoothing
	default_fov = config.camera_fov
```

### Control Axis Refactor

#### DirectControlComponent.gd (your current input handling)

```gdscript
extends Node
class_name DirectControlComponent

func configure_from_3c(config: CharacterConfig):
	match config.control_type:
		CharacterConfig.ControlType.DIRECT:
			setup_direct_input()  # Your current WASD
		CharacterConfig.ControlType.TARGET_BASED:
			setup_click_navigation()  # Your current click-to-move
		# etc.
```

## Phase 3: Add 3C Presets

### Create preset configurations for different game styles:

#### 3CPresets.gd

```gdscript
extends Resource
class_name TCPresets

static func get_botw_config() -> CharacterConfig:
	var config = CharacterConfig.new()
	config.config_name = "BOTW Style"
	config.character_type = CharacterConfig.CharacterType.AVATAR
	config.camera_type = CharacterConfig.CameraType.ORBITAL
	config.control_type = CharacterConfig.ControlType.DIRECT
	return config

static func get_diablo_config() -> CharacterConfig:
	var config = CharacterConfig.new()
	config.config_name = "Diablo Style"
	config.character_type = CharacterConfig.CharacterType.CONTROLLER
	config.camera_type = CharacterConfig.CameraType.FOLLOWING
	config.control_type = CharacterConfig.ControlType.TARGET_BASED
	return config

static func get_dark_souls_config() -> CharacterConfig:
	var config = CharacterConfig.new()
	config.config_name = "Dark Souls Style"
	config.character_type = CharacterConfig.CharacterType.AVATAR
	config.camera_type = CharacterConfig.CameraType.ORBITAL
	config.control_type = CharacterConfig.ControlType.DIRECT
	# Different parameters than BOTW for more deliberate feel
	return config
```

## Phase 4: Update Main Character Controller

### ControllerCharacter.gd - 3C Framework Integration

```gdscript
extends CharacterBody3D

@export var active_3c_config: CharacterConfig
@export var available_presets: Array[CharacterConfig] = []

# Your existing components
var character_component: Node
var camera_component: CameraRig
var control_component: Node

func _ready():
	if not active_3c_config:
		active_3c_config = TCPresets.get_botw_config()
	configure_3c_system()
	setup_existing_functionality() # This function needs to be implemented to set up existing node references.

func configure_3c_system():
	"""Apply 3C configuration to all systems"""
	# Configure character axis
	if character_component and character_component.has_method("configure_from_3c"):
		character_component.configure_from_3c(active_3c_config)

	# Configure camera axis
	if camera_component and camera_component.has_method("configure_from_3c"):
		camera_component.configure_from_3c(active_3c_config)

	# Configure control axis
	if control_component and control_component.has_method("configure_from_3c"):
		control_component.configure_from_3c(active_3c_config)

func switch_3c_config(new_config: CharacterConfig):
	"""Runtime 3C configuration switching"""
	active_3c_config = new_config
	configure_3c_system()
	print("Switched to 3C config: ", new_config.config_name)

# Placeholder for your existing setup that links node references
func setup_existing_functionality():
	# Example:
	# character_component = $PathToYourCharacterComponent
	# camera_component = $PathToYourCameraRig
	# control_component = $PathToYourControlComponent
	pass
```

## Phase 5: Add 3C Debug/Testing UI

### 3CDebugUI.gd

```gdscript
extends Control

@export var character_controller: ControllerCharacter

func _ready():
	create_preset_buttons()
	create_axis_sliders()

func create_preset_buttons():
	var presets = [
		TCPresets.get_botw_config(),
		TCPresets.get_diablo_config(),
		TCPresets.get_dark_souls_config()
	]

	for preset in presets:
		var button = Button.new()
		button.text = preset.config_name
		button.pressed.connect(func(): character_controller.switch_3c_config(preset))
		add_child(button)

func create_axis_sliders():
	# Real-time 3C parameter adjustment sliders
	# Camera distance, control sensitivity, etc.
	pass
```

## Implementation Priority

### Week 1: Core Infrastructure
- Create CharacterConfig resource
- Add 3C configuration methods to existing CameraRig
- Create basic presets (BOTW, Diablo styles)

### Week 2: Component Integration
- Refactor MovementManager to use 3C config
- Update InputManager to switch between control types
- Test runtime configuration switching

### Week 3: Polish & Extension
- Add debug UI for testing different configs
- Create additional presets (FPS, RTS styles)
- Fine-tune parameter relationships

## Benefits of This Refactor

### Immediate Value
- **Current functionality preserved** - everything still works
- **Systematic organization** - clear separation of 3C concerns
- **Runtime experimentation** - test different game feels instantly

### Future Expansion
- **Easy preset creation** - new game styles as simple configs
- **Designer-friendly** - non-programmers can create configurations
- **Research platform** - systematic exploration of interaction design

### Educational Value
- **Living framework demonstration** - theory applied to real project
- **Portfolio showcase** - sophisticated understanding of character controller design
- **Cross-genre learning** - experience different game paradigms

This refactor transforms your character controller from "WASD + click movement" into a systematic 3C research and design platform while maintaining all your current functionality.