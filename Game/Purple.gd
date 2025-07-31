extends Button

func _ready():
	pressed.connect(_on_pressed)

func _on_pressed():
	var peer = ENetMultiplayerPeer.new()
	peer.create_client("10.100.28.43", 4242)
	multiplayer.multiplayer_peer = peer
