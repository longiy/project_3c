# CharacterSignals.gd - Character signal coordination module
extends Node
class_name CharacterSignals

# === SIGNALS ===
signal system_connected(system_name: String)
signal system_disconnected(system_name: String)

# === CHARACTER REFERENCE ===
var character: CharacterBody3D

# === CONNECTED SYSTEMS ===
var connected_systems: Dictionary = {}
var signal_connections: Array[Dictionary] = []

func setup_character_reference(char: CharacterBody3D):
	"""Setup character reference"""
	character = char
	print("✅ CharacterSignals: Ready for signal coordination")

# === INPUT SYSTEM INTEGRATION ===

func connect_input_system(input_controller: InputController, movement_manager: MovementManager):
	"""Connect input controller to movement manager through signal coordination"""
	if not input_controller or not movement_manager:
		push_error("CharacterSignals: Missing input_controller or movement_manager")
		return
	
	# Connect input signals to movement manager
	var connections = [
		{
			"source": input_controller,
			"signal": "movement_started",
			"target": self,
			"method": "_on_movement_started"
		},
		{
			"source": input_controller,
			"signal": "movement_updated", 
			"target": self,
			"method": "_on_movement_updated"
		},
		{
			"source": input_controller,
			"signal": "movement_stopped",
			"target": self,
			"method": "_on_movement_stopped"
		},
		{
			"source": input_controller,
			"signal": "sprint_started",
			"target": self,
			"method": "_on_sprint_started"
		},
		{
			"source": input_controller,
			"signal": "sprint_stopped",
			"target": self,
			"method": "_on_sprint_stopped"
		},
		{
			"source": input_controller,
			"signal": "slow_walk_started",
			"target": self,
			"method": "_on_slow_walk_started"
		},
		{
			"source": input_controller,
			"signal": "slow_walk_stopped",
			"target": self,
			"method": "_on_slow_walk_stopped"
		},
		{
			"source": input_controller,
			"signal": "jump_pressed",
			"target": self,
			"method": "_on_jump_pressed"
		},
		{
			"source": input_controller,
			"signal": "reset_pressed",
			"target": self,
			"method": "_on_reset_pressed"
		}
	]
	
	# Establish connections
	for connection in connections:
		if connection.source.has_signal(connection.signal):
			connection.source.connect(connection.signal, connection.target[connection.method])
			signal_connections.append(connection)
	
	# Store references
	connected_systems["input_controller"] = input_controller
	connected_systems["movement_manager"] = movement_manager
	
	system_connected.emit("input_system")
	print("✅ CharacterSignals: Connected input system with ", signal_connections.size(), " signals")

# === ANIMATION SYSTEM INTEGRATION ===

func connect_animation_system(animation_controller: AnimationManager):
	"""Connect movement manager to animation controller"""
	if not animation_controller:
		push_warning("CharacterSignals: No animation controller provided")
		return
	
	var movement_manager = connected_systems.get("movement_manager")
	if not movement_manager:
		push_warning("CharacterSignals: Movement manager not connected yet")
		return
	
	# Connect movement manager signals to animation controller
	var anim_connections = [
		{
			"source": movement_manager,
			"signal": "movement_changed",
			"target": animation_controller,
			"method": "_on_movement_changed"
		},
		{
			"source": movement_manager,
			"signal": "mode_changed",
			"target": animation_controller,
			"method": "_on_mode_changed"
		}
	]
	
	# Establish animation connections
	for connection in anim_connections:
		if connection.source.has_signal(connection.signal):
			connection.source.connect(connection.signal, connection.target[connection.method])
			signal_connections.append(connection)
	
	connected_systems["animation_controller"] = animation_controller
	system_connected.emit("animation_system")
	print("✅ CharacterSignals: Connected animation system")

# === SIGNAL HANDLERS (Input → Movement) ===

func _on_movement_started(direction: Vector2, magnitude: float):
	"""Route movement start to movement manager"""
	var movement_manager = connected_systems.get("movement_manager")
	if movement_manager:
		movement_manager.handle_movement_action("move_start", {"direction": direction, "magnitude": magnitude})

func _on_movement_updated(direction: Vector2, magnitude: float):
	"""Route movement update to movement manager"""
	var movement_manager = connected_systems.get("movement_manager")
	if movement_manager:
		movement_manager.handle_movement_action("move_update", {"direction": direction, "magnitude": magnitude})

func _on_movement_stopped():
	"""Route movement stop to movement manager"""
	var movement_manager = connected_systems.get("movement_manager")
	if movement_manager:
		movement_manager.handle_movement_action("move_end")

func _on_sprint_started():
	"""Route sprint start to movement manager"""
	var movement_manager = connected_systems.get("movement_manager")
	if movement_manager:
		movement_manager.handle_mode_action("sprint_start")

func _on_sprint_stopped():
	"""Route sprint stop to movement manager"""
	var movement_manager = connected_systems.get("movement_manager")
	if movement_manager:
		movement_manager.handle_mode_action("sprint_end")

func _on_slow_walk_started():
	"""Route slow walk start to movement manager"""
	var movement_manager = connected_systems.get("movement_manager")
	if movement_manager:
		movement_manager.handle_mode_action("slow_walk_start")

func _on_slow_walk_stopped():
	"""Route slow walk stop to movement manager"""
	var movement_manager = connected_systems.get("movement_manager")
	if movement_manager:
		movement_manager.handle_mode_action("slow_walk_end")

func _on_jump_pressed():
	"""Route jump input to character actions"""
	var actions_module = character.get_node_or_null("CharacterActions") as CharacterActions
	if actions_module and actions_module.can_jump_at_all():
		actions_module.perform_jump()
		
		# Transition to jumping state
		var state_module = character.get_node_or_null("CharacterState") as CharacterState
		if state_module:
			state_module.change_state("jumping")

func _on_reset_pressed():
	"""Route reset to character controller"""
	if character and character.has_method("reset_character"):
		character.reset_character()

# === SYSTEM DISCONNECTION ===

func disconnect_system(system_name: String):
	"""Disconnect a system and its signals"""
	if not connected_systems.has(system_name):
		push_warning("CharacterSignals: System not connected: ", system_name)
		return
	
	# Disconnect related signals
	var disconnected_count = 0
	for i in range(signal_connections.size() - 1, -1, -1):
		var connection = signal_connections[i]
		var system = connected_systems[system_name]
		
		if connection.source == system or connection.target == system:
			if connection.source.is_connected(connection.signal, connection.target[connection.method]):
				connection.source.disconnect(connection.signal, connection.target[connection.method])
			signal_connections.remove_at(i)
			disconnected_count += 1
	
	connected_systems.erase(system_name)
	system_disconnected.emit(system_name)
	print("🔌 CharacterSignals: Disconnected ", system_name, " (", disconnected_count, " signals)")

func disconnect_all_systems():
	"""Disconnect all connected systems"""
	for system_name in connected_systems.keys():
		disconnect_system(system_name)

# === SIGNAL MONITORING ===

func get_signal_health() -> Dictionary:
	"""Check health of all signal connections"""
	var health = {
		"total_connections": signal_connections.size(),
		"active_connections": 0,
		"broken_connections": 0,
		"connected_systems": connected_systems.keys()
	}
	
	for connection in signal_connections:
		if connection.source and connection.target:
			if connection.source.is_connected(connection.signal, connection.target[connection.method]):
				health.active_connections += 1
			else:
				health.broken_connections += 1
		else:
			health.broken_connections += 1
	
	return health

# === DEBUG INFO ===

func get_debug_info() -> Dictionary:
	"""Get signal coordination debug information"""
	var signal_health = get_signal_health()
	
	return {
		"connected_systems": connected_systems.keys(),
		"total_systems": connected_systems.size(),
		"signal_connections": signal_connections.size(),
		"active_connections": signal_health.active_connections,
		"broken_connections": signal_health.broken_connections,
		"connection_health": "healthy" if signal_health.broken_connections == 0 else "degraded",
		"systems_status": get_systems_status()
	}

func get_systems_status() -> Dictionary:
	"""Get status of all connected systems"""
	var status = {}
	
	for system_name in connected_systems.keys():
		var system = connected_systems[system_name]
		status[system_name] = {
			"valid": system != null and is_instance_valid(system),
			"node_name": system.name if system else "invalid"
		}
	
	return status
