extends Button

func _ready():
	print("🔘 ConnectButton is ready.")
	pressed.connect(_on_button_pressed)

func _on_button_pressed():
	print("📡 Connect button pressed.")
	var game_manager = get_tree().get_root().get_node($"../../../../Multiplayer")
	if game_manager:
		print("✅ Found MultiplayerGameManager node.")
		game_manager.connect_to_server("10.100.43.210")  # Replace with your actual server IP
	else:
		print("❌ MultiplayerGameManager not found!")
