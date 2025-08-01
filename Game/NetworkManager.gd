extends Node

@export var is_server: bool = false
@export var port: int = 4242
@export var knight_scene: PackedScene = preload("res://knightUnitBlue.tscn") # Adjust if needed

var players: Dictionary = {}
var players_units: Dictionary = {}
var next_player_id: int = 1

func _ready():
	if is_server:
		var peer = ENetMultiplayerPeer.new()
		peer.create_server(port)
		multiplayer.multiplayer_peer = peer
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		print("✅ Server started on port %d" % port)
		_start_game()
	else:
		# Client will connect via button
		pass

func connect_to_server(ip: String):
	var peer = ENetMultiplayerPeer.new()
	peer.create_client(ip, port)
	multiplayer.multiplayer_peer = peer
	multiplayer.connection_succeeded.connect(_on_connection_succeeded)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	print("🌐 Trying to connect to server at %s:%d" % [ip, port])

func _on_connection_succeeded():
	print("✅ Connected to server!")

func _on_connection_failed():
	print("❌ Failed to connect to server.")

func _on_server_disconnected():
	print("⚠️ Disconnected from server.")

func _on_peer_connected(id: int):
	print("🔌 Player connected: ID = %d" % id)
	players[id] = {}
	_assign_player_id(id)

func _on_peer_disconnected(id: int):
	print("❌ Player disconnected: ID = %d" % id)
	players.erase(id)
	if players_units.has(id):
		for knight in players_units[id]:
			if is_instance_valid(knight):
				knight.queue_free()
		players_units.erase(id)

func _assign_player_id(id: int):
	rpc_id(id, "assign_player_id", id)

func _start_game():
	for peer_id in multiplayer.get_peers():
		_spawn_initial_knights_for_player(peer_id)
	_spawn_initial_knights_for_player(1) # server (host)

func _spawn_initial_knights_for_player(player_id: int):
	var base_x = 100 + (player_id - 1) * 300
	var base_y = 200

	for i in range(2):
		var knight = knight_scene.instantiate()
		knight.position = Vector2(base_x + i * 40, base_y)
		knight.set_multiplayer_authority(player_id)
		add_child(knight)

		if not players_units.has(player_id):
			players_units[player_id] = []
		players_units[player_id].append(knight)

		rpc_id(player_id, "rpc_spawn_knight", knight.position, player_id)

@rpc("any_peer")
func assign_player_id(id: int):
	self.set("player_id", id)
	print("🎮 Assigned player ID: %d" % id)

@rpc("any_peer")
func rpc_spawn_knight(pos: Vector2, owner_id: int):
	if is_server:
		return
	var knight = knight_scene.instantiate()
	knight.position = pos
	knight.set_multiplayer_authority(owner_id)
	add_child(knight)

	if not players_units.has(owner_id):
		players_units[owner_id] = []
	players_units[owner_id].append(knight)
