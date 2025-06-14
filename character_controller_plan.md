# 3D Character Controller Project Plan

## Project Brief
Creating a robust, reusable 3D character controller in Godot that supports both traditional WASD movement and Diablo-style point-and-click navigation. The controller will be designed as a drag-and-drop component using composition architecture, with modular input systems and polished 3C (Character, Camera, Controls) integration.

**Target User:** Artist with Unity background, proficient in Blender, limited C# knowledge
**Architecture:** Composition over inheritance using Godot's node system
**Input Modes:** WASD + mouse look, point-and-click navigation, hybrid mode support

## Development Phases

### Phase 1: Basic Movement Foundation
**Goal:** Get a capsule moving reliably in 3D space
- [ ] CharacterBody3D setup with basic WASD movement
- [ ] Implement gravity and ground detection
- [ ] Basic collision shape (capsule)
- [ ] Movement using move_and_slide()
- [ ] Test with placeholder mesh (capsule or basic model)

**Key Variables:**
- Movement speed
- Gravity strength
- Ground detection distance

### Phase 2: Camera Basics
**Goal:** Functional third-person camera that follows character
- [ ] Camera3D node setup as child of character
- [ ] Mouse look rotation around character
- [ ] Basic follow behavior with fixed distance/offset
- [ ] Camera collision avoidance (pull closer when hitting walls)
- [ ] Mouse capture/release handling

**Key Variables:**
- Camera distance from character
- Height offset
- Rotation sensitivity
- Collision detection range

### Phase 3: Core Animation Integration
**Goal:** Character visually responds to movement
- [ ] Import 3D character model with animations
- [ ] AnimationPlayer setup with idle/walk animations
- [ ] Connect movement speed to animation playback
- [ ] Basic blend between idle and walking states
- [ ] Ensure animations match movement speed

**Required Animations:**
- Idle
- Walk/Run cycle
- Jump (start/loop/land)

### Phase 4: Enhanced Movement
**Goal:** Complete movement feature set
- [ ] Jump mechanics with proper physics
- [ ] Run/sprint speed variations
- [ ] Improved ground detection and slope handling
- [ ] Coyote time for jump buffering
- [ ] Movement state tracking (idle/walk/run/jump/fall)
- [ ] Air control during jumps

**Key Variables:**
- Jump height
- Sprint multiplier
- Max slope angle
- Coyote time duration
- Air control strength

### Phase 5: Advanced Animation System
**Goal:** Professional animation blending and state management
- [ ] AnimationTree with AnimationNodeStateMachine
- [ ] State machine setup (idle/walk/run/jump/fall states)
- [ ] Blend spaces for directional movement
- [ ] Transition conditions based on movement states
- [ ] Root motion integration (if required)

**Animation States:**
- Idle
- Walk
- Run
- Jump Start
- Jump Loop
- Jump Land
- Fall

### Phase 6: Camera Polish
**Goal:** Cinematic camera behavior with smooth transitions
- [ ] Smoothing and lag parameters for camera follow
- [ ] FOV adjustments for different movement states
- [ ] Camera shake system for impacts/actions
- [ ] Zoom states (normal/aim/sprint modes)
- [ ] Look-ahead prediction for fast movement

**Key Variables:**
- Follow smoothness (position/rotation lag)
- FOV base value + state modifiers
- Shake intensity curves
- Zoom transition speeds

### Phase 7: Point-and-Click Input System
**Goal:** Diablo-style navigation alongside WASD controls
- [ ] Mouse click to ground detection with raycasting
- [ ] Pathfinding to clicked location
- [ ] Visual feedback for click destination
- [ ] Input mode switching (WASD/Point-Click/Hybrid)
- [ ] WASD override during pathfinding

**Components:**
- PointClickInputComponent
- Pathfinding system (NavMesh or A*)
- Destination marker visual

### Phase 8: Control Refinement
**Goal:** Professional input handling and responsiveness
- [ ] Input smoothing and acceleration curves
- [ ] Sensitivity settings for different input types
- [ ] Deadzone handling for gamepad support
- [ ] Input buffering for actions (jump queuing)
- [ ] Context-sensitive interaction prompts

**Key Variables:**
- Mouse sensitivity (horizontal/vertical)
- Input smoothing strength
- Buffer window timing
- Deadzone thresholds

### Phase 9: Component Architecture Refactor
**Goal:** Reusable, modular character controller
- [ ] Separate components into individual scripts
- [ ] MovementComponent for physics handling
- [ ] InputComponent base class with WASD/PointClick variants
- [ ] AnimationComponent for state management
- [ ] CameraComponent for follow behavior
- [ ] Export key parameters for easy tweaking

**Component Structure:**
```
CharacterController (main scene)
├── MovementComponent
├── InputComponent (KeyboardInput or PointClickInput)
├── AnimationComponent
├── CameraComponent
└── MeshInstance3D + CollisionShape3D
```

### Phase 10: Final Polish and Testing
**Goal:** Production-ready character controller
- [ ] Comprehensive parameter exposure via @export
- [ ] Scene setup as drag-and-drop prefab
- [ ] Performance optimization
- [ ] Edge case testing (slopes, tight spaces, etc.)
- [ ] Documentation for parameters and usage

## Core 3C Parameters

### Character
- Movement speeds (walk/run/sprint multipliers)
- Acceleration/deceleration curves
- Jump height and gravity multiplier
- Ground friction and air control
- Slope handling (max angle, slide threshold)
- Physics collision layers

### Camera
- FOV (base + state modifiers)
- Follow distance and height offset
- Smoothing parameters (position/rotation lag)
- Collision avoidance settings
- Shake system parameters
- Zoom state values

### Controls
- Input sensitivity (mouse/gamepad)
- Deadzone thresholds
- Input smoothing curves
- Buffer timing windows
- Remapping support
- Mode switching (WASD/Point-Click/Hybrid)

## Success Criteria
- [ ] Smooth, responsive character movement in both input modes
- [ ] Professional animation blending that matches movement
- [ ] Cinematic camera behavior with no jarring transitions
- [ ] Drag-and-drop functionality in new scenes
- [ ] Easily tweakable parameters exposed in editor
- [ ] Stable performance with no physics glitches
- [ ] Support for both keyboard/mouse and gamepad input

## Technical Notes
- Use CharacterBody3D for movement physics
- Implement composition pattern with component nodes
- Separate input handling from movement logic
- Use AnimationTree for complex state management
- Implement proper pathfinding for point-and-click mode
- Export all tuning parameters for designer accessibility