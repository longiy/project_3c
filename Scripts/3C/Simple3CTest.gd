# Simple3CTest.gd - Attach to any node for basic 3C testing
extends Node

func _ready():
	print("🧪 Simple 3C Test Ready")
	print("Press SPACE to test basic 3C functionality")

func _input(event):
	if event.is_action_pressed("ui_accept"):  # Space bar
		test_basic_3c()

func test_basic_3c():
	print("🧪 Testing 3C Framework...")
	
	# Test 1: Can we create configs?
	var botw_config = TCPresets.get_botw_config()
	if botw_config:
		print("✅ BOTW config created: ", botw_config.config_name)
	else:
		print("❌ Failed to create BOTW config")
		return
	
	# Test 2: Can we create different configs?
	var diablo_config = TCPresets.get_diablo_config()
	if diablo_config:
		print("✅ Diablo config created: ", diablo_config.config_name)
		print("   BOTW walk speed: ", botw_config.walk_speed)
		print("   Diablo walk speed: ", diablo_config.walk_speed)
	
	# Test 3: Find character controller
	var character = get_node("../CHARACTER")
	if character:
		print("✅ Found character controller")
		
		# Test 4: Check if 3C methods exist
		if character.has_method("switch_3c_config"):
			print("✅ Character has 3C methods")
			
			# Test 5: Try switching config
			character.switch_3c_config(diablo_config)
			print("✅ Config switch successful")
			
		else:
			print("❌ Character missing 3C methods - need to update ControllerCharacter.gd")
	else:
		print("❌ No character found at ../CHARACTER")
	
	print("🧪 Basic test complete")
