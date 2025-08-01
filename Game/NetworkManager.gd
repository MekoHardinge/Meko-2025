extends Node

@export var is_server: bool = false
@export var port: int = 4242
@export var server_ip: String = "10.100.43.210"  # Your actual LAN IP
@export var knight_scene: PackedScene = preload("res://KnightUnitBlue.tscn")  # Make sure this path is valid!

var players: Dictionary = {}
var players_units: Dictionary = {}
var next_player_id: int = 1

func _ready():
	print("[MULTI] MultiplayerManager Ready. is_server =", is_server)

	if is_server:
		var peer = ENetMultiplayerPeer.new()
		var result = peer.create_server(port)
		if result != OK:
			print("[SERVER ERROR] Could not start server on port", port)
			return
		multiplayer.multiplayer_peer = peer
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		print("[SERVER] Server started on port", port)
		_start_game()
	else:
		print("[CLIENT] Attempting to connect to server at", server_ip, "on port", port)
		_connect_to_server(server_ip)

func _connect_to_server(ip: String) -> void:
	var peer = ENetMultiplayerPeer.new()
	var result = peer.create_client(ip, port)
	if result != OK:
		print("[CLIENT ERROR] Could not create client connection to", ip, ":", port)
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.connection_succeeded.connect(_on_connection_succeeded)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	print("[CLIENT] Connection attempt in progress...")

func _on_connection_succeeded():
	print("[CLIENT] Successfully connected to server at", server_ip)

func _on_connection_failed():
	print("[CLIENT ERROR] Failed to connect to server at", server_ip)

func _on_server_disconnected():
	print("[CLIENT WARNING] Disconnected from server.")

func _on_peer_connected(id: int):
	print("[SERVER] Player connected with peer ID:", id)
	players[id] = {}
	_assign_player_id(id)

func _on_peer_disconnected(id: int):
	print("[SERVER] Player disconnected:", id)
	players.erase(id)
	if players_units.has(id):
		for knight in players_units[id]:
			if is_instance_valid(knight):
				print("[SERVER] Removing knight for player", id)
				knight.queue_free()
		players_units.erase(id)

func _assign_player_id(id: int) -> void:
	print("[SERVER] Assigning player ID to peer:", id)
	rpc_id(id, "assign_player_id", id)

func _start_game():
	print("[SERVER] Starting game and spawning units...")
	for peer_id in multiplayer.get_peers():
		print("[SERVER] Spawning knights for peer ID:", peer_id)
		_spawn_initial_knights_for_player(peer_id)

	# Include server’s own peer (ID 1)
	print("[SERVER] Spawning knights for self (peer ID 1)")
	_spawn_initial_knights_for_player(1)

func _spawn_initial_knights_for_player(player_id: int) -> void:
	var base_x = 100 + (player_id - 1) * 300
	var base_y = 200
	print("[SERVER] Spawning knights for player", player_id, "at X:", base_x)

	for i in range(2):
		var knight = knight_scene.instantiate()
		knight.position = Vector2(base_x + i * 40, base_y)
		knight.set_multiplayer_authority(player_id)
		add_child(knight)

		if not players_units.has(player_id):
			players_units[player_id] = []
		players_units[player_id].append(knight)

		print("[SERVER] Knight", i, "spawned for player", player_id, "at", knight.position)
		rpc_id(player_id, "rpc_spawn_knight", knight.get_path(), knight.position, player_id)

@rpc("any_peer")
func assign_player_id(id: int):
	print("[CLIENT] Assigned player ID from server:", id)
	self.set("player_id", id)

@rpc("any_peer")
func rpc_spawn_knight(node_path: NodePath, pos: Vector2, owner_id: int) -> void:
	if is_server:
		print("[SERVER] Ignoring rpc_spawn_knight because I'm the server.")
		return

	print("[CLIENT] Received spawn command for knight at", pos, "for player", owner_id)
	var knight = knight_scene.instantiate()
	knight.position = pos
	knight.set_multiplayer_authority(owner_id)
	add_child(knight)

	if not players_units.has(owner_id):
		players_units[owner_id] = []
	players_units[owner_id].append(knight)
	print("[CLIENT] Knight spawned at", pos, "for player", owner_id)
