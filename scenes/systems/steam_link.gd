class_name SteamLink
extends Node
## Talks to Steam for multiplayer over the internet, through Steam's free relay network.
## No router setup is needed: players find each other through a Steam "lobby" (a join
## code), and the game data travels over Valve's servers.
##
## Uses the GodotSteam extension (addons/godotsteam). For now the game runs as Valve's
## free test app "Spacewar" (app id 480), so Steam shows it as Spacewar and everyone
## who plays needs Steam running. Later the app id can be swapped for our own.
## The Steam singleton is looked up by name so the game still starts if the extension
## is missing.

signal lobby_hosted(lobby_id: int)
signal lobby_entered(lobby_id: int)
signal failed(reason: String)
signal games_listed(games: Array)
## A friend sent an invite (or used "Join Game") while we are running.
signal invite_accepted(lobby_id: int)

## Valve's free test app. Needs steam_appid.txt next to the game with this number.
const APP_ID := 480
## Marks lobbies as ours, so the list only shows How to Hunt games.
const GAME_KEY := "HowToHunt"
const LOBBY_PUBLIC := 2
const LOBBY_FRIENDS_ONLY := 1
const ENTER_SUCCESS := 1

var _steam: Object
var _ready_to_use := false
var _init_error := ""
var _current_lobby := 0
## Game version number (set by Network): only matching versions are shown as joinable.
var protocol := 1
var _pending_name := ""


func _ready() -> void:
	if Engine.has_singleton("Steam"):
		_steam = Engine.get_singleton("Steam")


func is_extension_loaded() -> bool:
	return _steam != null


func get_lobby_id() -> int:
	return _current_lobby


## Starts Steam (once). Returns "" when ready, otherwise a message to show the player.
func ensure_ready() -> String:
	if _ready_to_use:
		return ""
	if _steam == null:
		return "The Steam add-on isn't installed in this build of the game."
	var result: Dictionary = _steam.steamInitEx(APP_ID, true)
	if result.get("status", 1) != 0:
		_init_error = "Couldn't connect to Steam. Start the Steam app, log in, then try again. (%s)" % result.get("verbal", "unknown error")
		return _init_error
	_ready_to_use = true
	_steam.lobby_created.connect(_on_lobby_created)
	_steam.lobby_joined.connect(_on_lobby_joined)
	_steam.lobby_match_list.connect(_on_match_list)
	_steam.join_requested.connect(func(lobby_id, _friend): invite_accepted.emit(lobby_id))
	return ""


func get_steam_id() -> int:
	return _steam.getSteamID() if _ready_to_use else 0


## The player's Steam name, used as the default player name.
func get_persona_name() -> String:
	return _steam.getPersonaName() if _ready_to_use else ""


func create_lobby(friends_only: bool, max_players: int, host_name: String) -> void:
	_steam.createLobby(LOBBY_FRIENDS_ONLY if friends_only else LOBBY_PUBLIC, max_players)
	_pending_name = host_name


func _on_lobby_created(result: int, lobby_id: int) -> void:
	if result != 1:
		failed.emit("Steam couldn't create the game (error %d)." % result)
		return
	_current_lobby = lobby_id
	_steam.setLobbyData(lobby_id, "game", GAME_KEY)
	_steam.setLobbyData(lobby_id, "protocol", str(protocol))
	_steam.setLobbyData(lobby_id, "host", _pending_name)
	_steam.setLobbyJoinable(lobby_id, true)
	lobby_hosted.emit(lobby_id)


func join_lobby(lobby_id: int) -> void:
	_steam.joinLobby(lobby_id)


func _on_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != ENTER_SUCCESS:
		failed.emit(_enter_error(response))
		return
	# Hosting also triggers this (the host enters its own lobby); ignore that one.
	if _current_lobby == lobby_id and _steam.getLobbyOwner(lobby_id) == _steam.getSteamID():
		return
	_current_lobby = lobby_id
	lobby_entered.emit(lobby_id)


func _enter_error(response: int) -> String:
	match response:
		2: return "That game doesn't exist (check the code)."
		3: return "You're not allowed to join that game."
		4: return "That game is full."
		5: return "Steam had an error joining."
		6: return "You're banned from that game."
		9: return "You can't join: it's friends only."
		_: return "Couldn't join the game (Steam error %d)." % response


func leave_lobby() -> void:
	if _ready_to_use and _current_lobby != 0:
		_steam.leaveLobby(_current_lobby)
	_current_lobby = 0


## Asks Steam for open games. Answer arrives as games_listed (an Array of Dictionaries
## with id, host, players, max).
func request_games() -> void:
	if not _ready_to_use:
		return
	_steam.addRequestLobbyListDistanceFilter(3) # Worldwide.
	_steam.addRequestLobbyListStringFilter("game", GAME_KEY, 0)
	_steam.addRequestLobbyListResultCountFilter(30)
	_steam.requestLobbyList()


func _on_match_list(lobbies: Array) -> void:
	var games := []
	for lobby_id in lobbies:
		games.append({
			id = lobby_id,
			host = _steam.getLobbyData(lobby_id, "host"),
			players = _steam.getNumLobbyMembers(lobby_id),
			max = _steam.getLobbyMemberLimit(lobby_id),
			compatible = _steam.getLobbyData(lobby_id, "protocol") == str(protocol),
		})
	games_listed.emit(games)
