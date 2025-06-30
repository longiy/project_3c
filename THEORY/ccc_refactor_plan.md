# Complete CCC Framework Refactor Plan

## Current State Analysis

### What We Have
- Complex character controller with state machine
- Camera rig with multiple modes
- Input manager with WASD/click switching
- Animation system
- Movement manager
- Debug UI

### What We Need for CCC Framework
**Target Configuration:** Action-Adventure (Zelda BOTW style)
- **Character:** Avatar (direct character control)
- **Camera:** Orbital (player-controlled 3D camera)
- **Control:** Direct (WASD) + Target-based (click navigation)

## Required CCC Components for Our Project

### Character Axis
- **CCC_CharacterCore** (replaces ControllerCharacter)
- **CCC_AvatarComponent** (direct movement control)
- **CCC_DirectMovementComponent** (WASD physics)
- **CCC_TargetMovementComponent** (click-to-move)

### Camera Axis  
- **CCC_CameraCore** (replaces CameraRig core)
- **CCC_OrbitalCameraComponent** (mouse look)
- **CCC_CameraDistanceComponent** (zoom)
- **CCC_CameraFollowComponent** (smooth following)

### Control Axis
- **CCC_InputManagerComponent** (input routing)
- **CCC_DirectControlComponent** (WASD handling)
- **CCC_TargetControlComponent** (click handling)
- **CCC_KeyboardMouseComponent** (device handling)

### Support Components
- **CCC_AnimationManagerComponent** (replaces AnimationManager)
- **CCC_ConfigComponent** (configuration system)

## Refactor Strategy - Complete Replacement

### Phase 1: Create New CCC Foundation
**Goal:** Replace existing controller with CCC components

**Delete:**
- `Scripts/Controllers/ControllerCharacter.gd`
- `Scripts/Controllers/CameraRig.gd`
- `Scripts/Character/CharacterStateMachine.gd`
- `Scripts/Character/State.gd`
- All existing state scripts
- `Scripts/_Debug/DebugUI.gd`

**Create New Structure:**
```
Scripts/CCC/
├── Core/
│   ├── CCC_CharacterCore.gd
│   └── CCC_CameraCore.gd
├── Character/
│   ├── CCC_AvatarComponent.gd
│   ├── CCC_DirectMovementComponent.gd
│   ├── CCC_TargetMovementComponent.gd
│   └── CCC_AnimationManagerComponent.gd
├── Camera/
│   ├── CCC_OrbitalCameraComponent.gd
│   ├── CCC_CameraDistanceComponent.gd
│   └── CCC_CameraFollowComponent.gd
├── Control/
│   ├── CCC_InputManagerComponent.gd
│   ├── CCC_DirectControlComponent.gd
│   ├── CCC_TargetControlComponent.gd
│   └── CCC_KeyboardMouseComponent.gd
├── Config/
│   ├── CCC_CharacterConfig.gd
│   ├── CCC_Presets.gd
│   └── CCC_ConfigComponent.gd
├── Debug/
│   └── CCC_DebugUI.gd
└── CCC_CharacterController.gd
```

### Phase 2: New Scene Structure
**Replace CHARACTER.tscn completely with SCENE_CCC.tscn:**

```
SCENE_CCC.tscn
CharacterController (Node3D) - CCC_CharacterController.gd
├── CharacterCore (CharacterBody3D) - CCC_CharacterCore.gd
│   ├── MeshInstance3D
│   ├── CollisionShape3D
│   └── AnimationPlayer
├── CharacterComponents (Node3D)
│   ├── CCC_AvatarComponent (Node)
│   ├── CCC_DirectMovementComponent (Node)
│   ├── CCC_TargetMovementComponent (Node)
│   └── CCC_AnimationManagerComponent (Node)
├── CameraRig (Node3D)
│   ├── CameraCore (Camera3D) - CCC_CameraCore.gd
│   └── CameraComponents (Node3D)
│       ├── CCC_OrbitalCameraComponent (Node)
│       ├── CCC_CameraDistanceComponent (Node)
│       └── CCC_CameraFollowComponent (Node)
├── ControlRig (Node3D)
│   └── ControlComponents (Node3D)
│       ├── CCC_InputManagerComponent (Node)
│       ├── CCC_DirectControlComponent (Node)
│       ├── CCC_TargetControlComponent (Node)
│       └── CCC_KeyboardMouseComponent (Node)
├── ConfigRig (Node3D)
│   └── CCC_ConfigComponent (Node)
└── DebugRig (Node3D)
	└── CCC_DebugUI (Control)
```

### Phase 3: Implementation Order

#### Step 1: Core Foundation (Day 1)
1. **CCC_CharacterCore.gd** - Basic CharacterBody3D physics
2. **CCC_CameraCore.gd** - Basic Camera3D mount
3. **CCC_CharacterController.gd** - Main coordinator
4. **Test:** Character exists, camera shows it

#### Step 2: Basic Movement (Day 1)
1. **CCC_AvatarComponent.gd** - Character type logic
2. **CCC_DirectMovementComponent.gd** - WASD movement
3. **CCC_DirectControlComponent.gd** - Input processing
4. **CCC_InputManagerComponent.gd** - Input routing
5. **Test:** WASD movement works

#### Step 3: Camera Controls (Day 2)
1. **CCC_OrbitalCameraComponent.gd** - Mouse look
2. **CCC_CameraDistanceComponent.gd** - Zoom
3. **CCC_CameraFollowComponent.gd** - Smooth following
4. **Test:** Full camera control

#### Step 4: Click Navigation (Day 2)
1. **CCC_TargetMovementComponent.gd** - Pathfinding movement
2. **CCC_TargetControlComponent.gd** - Click detection
3. **Enhanced InputManager** - Mode switching
4. **Test:** Both input methods work

#### Step 5: Animation & Polish (Day 3)
1. **CCC_AnimationManagerComponent.gd** - Animation control
2. **CCC_ConfigComponent.gd** - Configuration system
3. **CCC_Presets.gd** - Preset configurations
4. **CCC_DebugUI.gd** - Debug interface
5. **Test:** Complete experience

## Key Refactor Principles

### 1. Signal-Based Communication
```gdscript
# Replace direct dependencies with signals
signal movement_input_received(direction: Vector2)
signal camera_mode_changed(mode: String)
signal character_state_changed(state: String)
```

### 2. Configuration-Driven
```gdscript
# All parameters come from CCC config
func configure_from_ccc(config: CCC_CharacterConfig):
	walk_speed = config.walk_speed
	mouse_sensitivity = config.mouse_sensitivity
	camera_distance = config.camera_distance
```

### 3. Component Independence
- Each component works alone
- Removing a component doesn't break others
- Components communicate via signals only

### 4. Modular Testing
- Each component gets its own test scene
- Test individual components before integration
- Verify component independence

## Migration Strategy

### Preserve Existing Assets
- Keep character model and animations
- Keep AnimationTree resources
- Keep scene environment (GROUND, obstacles)

### Data Migration
- Export current parameter values
- Create equivalent CCC configuration
- Test parity between old and new

### Gradual Replacement
1. Create new CCC system alongside old
2. Test new system thoroughly
3. Switch scene to use new system
4. Delete old scripts after verification

## Testing Checkpoints

### Checkpoint 1: Core Works
- Character spawns and has physics
- Camera shows character
- No errors in console

### Checkpoint 2: Basic Movement
- WASD moves character
- Mouse rotates camera
- Character animates properly

### Checkpoint 3: Full Controls
- Scroll wheel zooms
- Camera follows smoothly
- Click navigation works

### Checkpoint 4: Configuration
- CCC presets switch correctly
- All parameters exposed
- Debug UI shows live values

### Checkpoint 5: Final Verification
- All original functionality preserved
- Better modularity achieved
- Performance maintained or improved

## Implementation Files to Create

### Core Files (Create First)
1. `CCC_CharacterController.gd` - Main coordinator
2. `CCC_CharacterCore.gd` - Physics foundation
3. `CCC_CameraCore.gd` - Camera mount
4. `CCC_CharacterConfig.gd` - Configuration class

### Component Files (Create Second)
1. `CCC_AvatarComponent.gd`
2. `CCC_DirectMovementComponent.gd` 
3. `CCC_OrbitalCameraComponent.gd`
4. `CCC_InputManagerComponent.gd`
5. `CCC_DirectControlComponent.gd`

### Integration Files (Create Third)
1. `CCC_ConfigComponent.gd`
2. `CCC_Presets.gd`
3. `CCC_AnimationManagerComponent.gd`

### Advanced Files (Create Last)
1. `CCC_TargetMovementComponent.gd`
2. `CCC_TargetControlComponent.gd`
3. `CCC_CameraDistanceComponent.gd`
4. `CCC_CameraFollowComponent.gd`

## Success Metrics

### Functionality Parity
- [ ] WASD movement identical to current
- [ ] Mouse camera control identical
- [ ] Animation blending preserved
- [ ] Click navigation works
- [ ] Performance maintained

### Framework Benefits
- [ ] Components can be removed independently
- [ ] CCC presets switch game feel instantly
- [ ] New camera behaviors easy to add
- [ ] Debug interface shows all CCC parameters
- [ ] Code base 50% smaller than current

## CCC Axis Organization

### Character Axis (CharacterComponents/)
- Controls character physics and behavior
- Manages movement types (direct, target-based)
- Handles character representation (avatar, controller, etc.)

### Camera Axis (CameraRig/CameraComponents/)
- Controls camera positioning and behavior
- Manages camera types (orbital, following, fixed)
- Handles camera responsiveness and smoothing

### Control Axis (ControlRig/ControlComponents/)
- Manages input processing and routing
- Handles different control schemes (direct, target-based)
- Device-specific input handling

This complete refactor transforms the existing character controller into a true CCC framework while preserving all current functionality and adding clear modular organization.
