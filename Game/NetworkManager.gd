extends Node

@export var is_server: bool = false
@export var port: int = 4242
@export var knight_scene: PackedScene = preload("res://knightUnitBlue.tscn")  # Replace with your knight scene path

var players: Dictionary = {}
var players_units: Dictionary = {}

var next_player_id: int = 1

func _ready():
	var ip = IP.get_local_addresses()
	print(ip)
	if is_server:
		var peer = ENetMultiplayerPeer.new()
		peer.create_server(port)
		multiplayer.multiplayer_peer = peer
		multiplayer.connect("peer_connected", Callable(self, "_on_peer_connected"))
		multiplayer.connect("peer_disconnected", Callable(self, "_on_peer_disconnected"))
		print("Server started on port %d" % port)
		_start_game()
	else:
		# For client: call connect_to_server(ip) externally
		pass

func connect_to_server(ip: String) -> void:
	var peer = ENetMultiplayerPeer.new()
	peer.create_client(ip, port)
	multiplayer.multiplayer_peer = peer
	multiplayer.connect("connection_succeeded", Callable(self, "_on_connection_succeeded"))
	multiplayer.connect("connection_failed", Callable(self, "_on_connection_failed"))
	multiplayer.connect("server_disconnected", Callable(self, "_on_server_disconnected"))
	print("Trying to connect to server at %s:%d" % [ip, port])

func _on_connection_succeeded():
	print("Connected to server!")

func _on_connection_failed():
	print("Failed to connect to server")

func _on_server_disconnected():
	print("Disconnected from server")

func _on_peer_connected(id: int):
	print("Player connected with id: ", id)
	players[id] = {}  # Store player info if needed
	_assign_player_id(id)

func _on_peer_disconnected(id: int):
	print("Player disconnected with id: ", id)
	players.erase(id)
	if players_units.has(id):
		for knight in players_units[id]:
			if is_instance_valid(knight):
				knight.queue_free()
		players_units.erase(id)

func _assign_player_id(id: int) -> void:
	# Notify connected client of their player ID
	rpc_id(id, "assign_player_id", id)

func _start_game():
	# Server spawns units for each connected peer (including itself)
	for peer_id in multiplayer.get_peers():
		_spawn_initial_knights_for_player(peer_id)
	# Also spawn for server itself (peer id 1 by default)
	_spawn_initial_knights_for_player(1)

func _spawn_initial_knights_for_player(player_id: int) -> void:
	# Spawn two knights per player, positioned offset so they don't overlap
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

		# Notify client to spawn the knight too
		rpc_id(player_id, "rpc_spawn_knight", knight.get_path(), knight.position, player_id)

@rpc("any_peer")
func assign_player_id(id: int):
	self.set("player_id", id)  # store player id on client if needed
	print("Assigned player ID: ", id)

@rpc("any_peer")
func rpc_spawn_knight(node_path: NodePath, pos: Vector2, owner_id: int) -> void:
	if is_server:
		return  # Server already spawned knights itself, no need to spawn again

	var knight = knight_scene.instantiate()
	knight.position = pos
	knight.set_multiplayer_authority(owner_id)
	add_child(knight)

	if not players_units.has(owner_id):
		players_units[owner_id] = []
	players_units[owner_id].append(knight)
