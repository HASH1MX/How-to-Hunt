extends Node
## Multiplayer (autoload "Network"). One player hosts, friends join by IP address.
##
## How it works:
##   - Godot's built-in ENet networking (UDP). The host is also the "server": every
##     other player connects to the host, and the host passes messages between them.
##   - Every player runs their own full copy of the world. The world is built from fixed
##     seeds, so it is identical for everyone. Only players' positions, looks and
##     actions are sent over the network.
##   - Each player controls their own character and tells the others where it is
##     (about 20 times per second). The others show it as a RemotePlayer.
##   - Two ways to connect: over Steam (free relay, no router setup, join by code - the
##     main way to play over the internet) or direct by IP address (same home network,
##     a VPN, or a forwarded port; the host tries UPnP to open the port automatically).
##
## Not done yet (later stages): animals and dropped items are not shared between
## players. See docs/PROGRESS.md.

signal joined_game
signal join_failed(reason: String)
signal player_joined(id: int, player_name: String)
signal player_left(id: int, player_name: String)
signal host_left
signal upnp_finished

const DEFAULT_PORT := 7777
const MAX_PLAYERS := 10
## Bump this when a change makes old and new versions unable to play together.
const PROTOCOL_VERSION := 3
const SEND_RATE := 20.0
const MAIN_MENU := "res://scenes/ui/main_menu/main_menu.tscn"
const SAVE_PATH := "user://multiplayer.cfg"

## This player's name, shown above the character. Saved between sessions.
var player_name := "Hunter"
var last_address := "127.0.0.1"
var last_port := DEFAULT_PORT

## peer id -> name, for every player in the session (including this one).
var players := {}
## Text for the start page to show after being sent back (e.g. "The host closed the game").
var notice := ""
## Result of the router port-opening attempt (hosts only).
var upnp_message := ""
var public_ip := ""

## "steam" or "enet" (direct IP) while in a session.
var transport := ""
## The Steam join code of the game being played (Steam sessions only).
var lobby_code := ""
var steam := SteamLink.new()
## A joined player's saved progress, sent by the host (applied when the game starts).
var my_saved_data := {}

var _world: Node3D
var _remotes := {}
## Host only: peer id -> save key of each joined player (see SaveManager).
var _keys := {}
var _upnp: UPNP
var _upnp_thread: Thread
var _upnp_port := 0
var _connecting := false


func _ready() -> void:
	_load()
	steam.name = "SteamLink"
	steam.protocol = PROTOCOL_VERSION
	add_child(steam)
	steam.lobby_hosted.connect(_on_steam_lobby_hosted)
	steam.lobby_entered.connect(_on_steam_lobby_entered)
	steam.failed.connect(_fail)
	steam.invite_accepted.connect(func(lobby_id): join_steam(str(lobby_id)))
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _exit_tree() -> void:
	leave()


## True while hosting or joined to someone else's game.
func is_online() -> bool:
	var peer := multiplayer.multiplayer_peer
	return peer != null and not peer is OfflineMultiplayerPeer \
			and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func is_host() -> bool:
	return is_online() and multiplayer.is_server()


## The key that this player's progress is stored under in a world save. The host's own
## character is always "host". Joined players use their Steam ID (or name, direct connection).
func get_player_key() -> String:
	if steam.ensure_ready() == "":
		return "steam:%d" % steam.get_steam_id()
	return "name:%s" % player_name


## Another player's character in this world (null for yourself or if not shown yet).
func get_remote_player(id: int) -> RemotePlayer:
	var remote = _remotes.get(id)
	return remote if is_instance_valid(remote) else null


func get_my_id() -> int:
	return multiplayer.get_unique_id() if is_online() else 1


## Everyone's name, in join order (host first).
func get_player_names() -> Array:
	var names := []
	for id in players:
		names.append(players[id])
	return names


# --- Starting and stopping ---------------------------------------------------------

## Starts hosting. Returns "" on success, or an error message.
func host(port: int = DEFAULT_PORT) -> String:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MAX_PLAYERS - 1)
	if error != OK:
		return "Could not host on port %d (is another game already using it?)" % port
	multiplayer.multiplayer_peer = peer
	transport = "enet"
	players = {1: player_name}
	last_port = port
	_save()
	_start_upnp(port)
	joined_game.emit()
	return ""


## Starts joining a game. The result arrives as joined_game or join_failed.
func join(address: String, port: int = DEFAULT_PORT) -> void:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address.strip_edges(), port)
	if error != OK:
		join_failed.emit("That address doesn't look right.")
		return
	multiplayer.multiplayer_peer = peer
	transport = "enet"
	last_address = address.strip_edges()
	last_port = port
	_save()
	_connecting = true
	# ENet can take a long time to give up, so give up ourselves after a few seconds.
	get_tree().create_timer(8.0).timeout.connect(func():
		if _connecting:
			_fail("Could not reach the host. Check the address, and that the host's port is open."))


## Starts hosting a game over Steam. Returns "" if it started (the result arrives as
## joined_game or join_failed), or a message to show.
func host_steam(friends_only: bool) -> String:
	leave()
	var problem := steam.ensure_ready()
	if problem != "":
		return problem
	steam.create_lobby(friends_only, MAX_PLAYERS, player_name)
	return ""


## Joins a game over Steam using its join code. Returns "" if it started, or a message.
func join_steam(code: String) -> String:
	leave()
	var problem := steam.ensure_ready()
	if problem != "":
		return problem
	if not code.strip_edges().is_valid_int():
		return "That code doesn't look right. It is a long number."
	_connecting = true
	steam.join_lobby(code.strip_edges().to_int())
	get_tree().create_timer(15.0).timeout.connect(func():
		if _connecting:
			_fail("Steam took too long to connect. Check the code and try again."))
	return ""


func _on_steam_lobby_hosted(lobby_id: int) -> void:
	var peer := SteamMultiplayerPeer.new()
	if peer.host_with_lobby(lobby_id) != OK:
		_fail("Steam couldn't start the game.")
		return
	multiplayer.multiplayer_peer = peer
	transport = "steam"
	lobby_code = str(lobby_id)
	players = {1: player_name}
	joined_game.emit()


func _on_steam_lobby_entered(lobby_id: int) -> void:
	var peer := SteamMultiplayerPeer.new()
	if peer.connect_to_lobby(lobby_id) != OK:
		_fail("Couldn't connect to that game through Steam.")
		return
	multiplayer.multiplayer_peer = peer
	transport = "steam"
	lobby_code = str(lobby_id)
	# From here it is the same as any join: connected_to_server, then the handshake.


## Leaves the session (or stops hosting) and goes back to being offline.
func leave() -> void:
	_connecting = false
	_stop_upnp()
	steam.leave_lobby()
	transport = ""
	lobby_code = ""
	_keys.clear()
	my_saved_data = {}
	if multiplayer.multiplayer_peer != null and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	for remote in _remotes.values():
		if is_instance_valid(remote):
			remote.queue_free()
	_remotes.clear()
	players.clear()
	_world = null


func set_player_name(value: String) -> void:
	value = value.strip_edges().left(16)
	player_name = value if value != "" else "Hunter"
	_save()


# --- The world ---------------------------------------------------------------------

## Called by the level when the game starts, so other players can appear in it.
func world_ready(world: Node3D) -> void:
	_world = world
	for id in players:
		if id != get_my_id():
			_spawn_remote(id)


func _spawn_remote(id: int) -> void:
	if _world == null or _remotes.has(id) or not players.has(id):
		return
	var remote := RemotePlayer.new()
	remote.name = "Player_%d" % id
	remote.peer_id = id
	remote.player_name = players[id]
	_world.add_child(remote)
	_remotes[id] = remote


func _remove_remote(id: int) -> void:
	if _remotes.has(id):
		if is_instance_valid(_remotes[id]):
			_remotes[id].queue_free()
		_remotes.erase(id)


# --- Messages between players --------------------------------------------------------

## Sent about 20 times a second by the player who owns the character.
func send_state(position: Vector3, yaw: float, pitch: float, flags: int) -> void:
	if is_online() and players.size() > 1:
		_state.rpc(position, yaw, pitch, flags)


## A joined player sends their progress to the host, who keeps it in the world save.
func send_progress(progress: Dictionary) -> void:
	if is_online() and not multiplayer.is_server():
		_progress.rpc_id(1, progress)


@rpc("any_peer", "call_remote", "reliable")
func _progress(progress: Dictionary) -> void:
	var key: String = _keys.get(multiplayer.get_remote_sender_id(), "")
	if key != "" and multiplayer.is_server():
		SaveManager.set_player_data(key, progress)


func send_punch() -> void:
	if is_online() and players.size() > 1:
		_punched.rpc()


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _state(position: Vector3, yaw: float, pitch: float, flags: int) -> void:
	var remote: RemotePlayer = _remotes.get(multiplayer.get_remote_sender_id())
	if remote != null:
		remote.push_state(position, yaw, pitch, flags)


@rpc("any_peer", "call_remote", "reliable")
func _punched() -> void:
	var remote: RemotePlayer = _remotes.get(multiplayer.get_remote_sender_id())
	if remote != null:
		remote.punch()


# --- Joining handshake -----------------------------------------------------------------

func _on_connected_to_server() -> void:
	# Connected: introduce ourselves to the host.
	_register.rpc_id(1, PROTOCOL_VERSION, player_name, get_player_key())


## Host: a new player says hello.
@rpc("any_peer", "call_remote", "reliable")
func _register(version: int, requested_name: String, save_key: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	if version != PROTOCOL_VERSION:
		_rejected.rpc_id(id, "Different game version. Everyone needs the same version of the game.")
		_kick_later(id)
		return
	if players.size() >= MAX_PLAYERS:
		_rejected.rpc_id(id, "The game is full.")
		_kick_later(id)
		return
	var final_name := _unique_name(requested_name.strip_edges().left(16))
	players[id] = final_name
	# Their saved progress in this world is looked up by key. If someone with the same
	# key is already playing (e.g. two copies on one account), the newcomer starts fresh.
	save_key = save_key.left(40)
	if save_key == "" or _keys.values().has(save_key) or save_key == SaveManager.HOST_KEY:
		save_key = "%s#%d" % [save_key, id]
	_keys[id] = save_key
	# Tell the new player who is here (and their saved progress), and everyone else that they arrived.
	_welcome.rpc_id(id, players, final_name, SaveManager.get_player_data(save_key))
	for other in players:
		if other != 1 and other != id:
			_player_added.rpc_id(other, id, final_name)
	player_joined.emit(id, final_name)
	_spawn_remote(id)


@rpc("authority", "call_remote", "reliable")
func _welcome(all_players: Dictionary, my_name: String, saved: Dictionary) -> void:
	_connecting = false
	players = all_players
	player_name = my_name
	my_saved_data = saved
	joined_game.emit()


@rpc("authority", "call_remote", "reliable")
func _rejected(reason: String) -> void:
	_fail(reason)


@rpc("authority", "call_remote", "reliable")
func _player_added(id: int, new_name: String) -> void:
	players[id] = new_name
	player_joined.emit(id, new_name)
	_spawn_remote(id)


@rpc("authority", "call_remote", "reliable")
func _player_removed(id: int) -> void:
	_forget_player(id)


func _kick_later(id: int) -> void:
	get_tree().create_timer(0.5).timeout.connect(func():
		if is_online() and multiplayer.get_peers().has(id):
			multiplayer.multiplayer_peer.disconnect_peer(id))


func _unique_name(wanted: String) -> String:
	if wanted == "":
		wanted = "Hunter"
	var taken := get_player_names()
	if not taken.has(wanted):
		return wanted
	var n := 2
	while taken.has("%s %d" % [wanted, n]):
		n += 1
	return "%s %d" % [wanted, n]


func _forget_player(id: int) -> void:
	if not players.has(id):
		return
	var left_name: String = players[id]
	players.erase(id)
	_keys.erase(id)
	if multiplayer.is_server():
		SaveManager.save_world_file()
	_remove_remote(id)
	player_left.emit(id, left_name)


func _on_peer_connected(_id: int) -> void:
	pass # The player is added when they introduce themselves (see _register).


func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server() and players.has(id):
		_forget_player(id)
		for other in players:
			if other != 1:
				_player_removed.rpc_id(other, id)


func _on_connection_failed() -> void:
	_fail("Could not connect to the host.")


func _on_server_disconnected() -> void:
	leave()
	notice = "The host closed the game."
	host_left.emit()
	get_tree().change_scene_to_file(MAIN_MENU)


func _fail(reason: String) -> void:
	_connecting = false
	leave()
	join_failed.emit(reason)


# --- Opening the port on the router (UPnP) ---------------------------------------------

func _start_upnp(port: int) -> void:
	upnp_message = "Trying to open port %d on your router..." % port
	public_ip = ""
	_upnp_port = port
	_upnp_thread = Thread.new()
	_upnp_thread.start(_upnp_work.bind(port))


func _upnp_work(port: int) -> void:
	var upnp := UPNP.new()
	var message := ""
	var ip := ""
	var result := upnp.discover(2000)
	if result != UPNP.UPNP_RESULT_SUCCESS or upnp.get_gateway() == null or not upnp.get_gateway().is_valid_gateway():
		message = "Your router didn't answer (UPnP is off or not supported). Friends outside your home network need port %d forwarded manually, or a VPN like Radmin/ZeroTier." % port
	else:
		var mapped := upnp.add_port_mapping(port, port, "How to Hunt", "UDP")
		if mapped == UPNP.UPNP_RESULT_SUCCESS:
			ip = upnp.query_external_address()
			message = "Port %d is open on your router." % port
			_upnp = upnp
		else:
			message = "Your router refused to open port %d (error %d). Forward it manually." % [port, mapped]
	_upnp_done.call_deferred(message, ip)


func _upnp_done(message: String, ip: String) -> void:
	upnp_message = message
	public_ip = ip
	upnp_finished.emit()


func _stop_upnp() -> void:
	if _upnp_thread != null:
		_upnp_thread.wait_to_finish()
		_upnp_thread = null
	if _upnp != null:
		_upnp.delete_port_mapping(_upnp_port, "UDP")
		_upnp = null


## This computer's addresses on the home network (what friends on the same Wi-Fi use).
func get_local_addresses() -> Array:
	var found := []
	for address in IP.get_local_addresses():
		if address.count(".") == 3 and not address.begins_with("127.") and not address.begins_with("169.254."):
			found.append(address)
	return found


# --- Saving ---------------------------------------------------------------------------

func _load() -> void:
	var file := ConfigFile.new()
	if file.load(SAVE_PATH) != OK:
		return
	player_name = file.get_value("multiplayer", "name", player_name)
	last_address = file.get_value("multiplayer", "address", last_address)
	last_port = file.get_value("multiplayer", "port", last_port)


func _save() -> void:
	var file := ConfigFile.new()
	file.set_value("multiplayer", "name", player_name)
	file.set_value("multiplayer", "address", last_address)
	file.set_value("multiplayer", "port", last_port)
	file.save(SAVE_PATH)
