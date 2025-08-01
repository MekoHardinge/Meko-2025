extends Button

func _ready():
	pressed.connect(_on_pressed)

func _on_pressed():
	print("Attempting to connect to server...")
	var peer = ENetMultiplayerPeer.new()
	peer.create_client("10.100.28.43", 4242)
	multiplayer.multiplayer_peer = peer

	multiplayer.connect("connection_succeeded", Callable(self, "_on_connection_succeeded"))
	multiplayer.connect("connection_failed", Callable(self, "_on_connection_failed"))
	multiplayer.connect("server_disconnected", Callable(self, "_on_server_disconnected"))

func _on_connection_succeeded():
	print("✅ Connected to server!")

func _on_connection_failed():
	print("❌ Failed to connect to server.")

func _on_server_disconnected():
	print("🔌 Disconnected from server.")
