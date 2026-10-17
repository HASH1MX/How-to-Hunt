extends Node
## Save games (autoload "SaveManager"). The player can have many worlds, each with its
## own progress, like save files. Each world is one file: user://worlds/<id>.json
##
## What a world file holds:
##   - name, when it was made and last played, how long it has been played
##   - "players": the saved progress of every player who has played in it (position, health,
##     food, money, inventory), stored by a player key (see below)
##   - "world": room for things shared by everyone (day, unlocked areas...) - added later
##
## In multiplayer the HOST owns the world file. A joining player's progress is stored in
## the host's file under their player key (their Steam ID, or their name on a direct
## connection), sent to them when they join, and sent back to the host as they play.
## The host's own character uses the key "host".
##
## Saved automatically every 30 seconds, when leaving to the menu, when a player leaves and
## when the window is closed. Files are written to a temporary file first and a backup of
## the previous save is kept, so a crash while saving can't destroy a world.
## Not saved yet: animals and loose items on the ground (they come back fresh).

signal saved

const DIR := "user://worlds"
const FORMAT_VERSION := 1
const AUTOSAVE_SECONDS := 30.0
## The key for the character of whoever owns the world file (solo player or host).
const HOST_KEY := "host"

var current_id := ""
var data := {}
## The character on this computer (set when a game starts).
var session_player: Node

var _since_save := 0.0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)


func _process(delta: float) -> void:
	if session_player == null or not is_instance_valid(session_player):
		return
	if _owns_file():
		data["play_seconds"] = float(data.get("play_seconds", 0.0)) + delta
	_since_save += delta
	if _since_save >= AUTOSAVE_SECONDS:
		save_now()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_now()


# --- Worlds ------------------------------------------------------------------------------

## Every saved world (newest played first): Dictionaries with id, name, created,
## last_played and play_seconds.
func list_worlds() -> Array:
	var worlds := []
	for file_name in DirAccess.get_files_at(DIR):
		if not file_name.ends_with(".json"):
			continue
		var id := file_name.trim_suffix(".json")
		var world := _read(id)
		if world.is_empty():
			continue
		worlds.append({
			id = id,
			name = str(world.get("name", "World")),
			created = int(world.get("created", 0)),
			last_played = int(world.get("last_played", 0)),
			play_seconds = float(world.get("play_seconds", 0.0)),
		})
	worlds.sort_custom(func(a, b): return a.last_played > b.last_played)
	return worlds


## Makes a new empty world and returns its id.
func create_world(world_name: String) -> String:
	world_name = world_name.strip_edges().left(30)
	if world_name == "":
		world_name = "New World"
	var now := int(Time.get_unix_time_from_system())
	var id := "w%d_%d" % [now, randi() % 10000]
	data = {
		version = FORMAT_VERSION,
		name = world_name,
		created = now,
		last_played = now,
		play_seconds = 0.0,
		players = {},
		world = {},
	}
	current_id = id
	_write()
	return id


## Opens a world so the game uses it. Returns false if it can't be read.
func load_world(id: String) -> bool:
	var world := _read(id)
	if world.is_empty():
		return false
	data = world
	if not data.has("players"):
		data["players"] = {}
	if not data.has("world"):
		data["world"] = {}
	current_id = id
	session_player = null
	return true


func delete_world(id: String) -> void:
	for suffix in [".json", ".json.bak", ".json.tmp"]:
		var path := "%s/%s%s" % [DIR, id, suffix]
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if id == current_id:
		current_id = ""
		data = {}


func has_world() -> bool:
	return current_id != "" and not data.is_empty()


func get_world_name() -> String:
	return str(data.get("name", ""))


## Loads the newest world, or makes one called `fallback_name` if there are none.
## For quick testing from the command line.
func ensure_world(fallback_name: String = "Test World") -> void:
	if has_world():
		return
	var worlds := list_worlds()
	if worlds.is_empty() or not load_world(worlds[0].id):
		create_world(fallback_name)


# --- Players -----------------------------------------------------------------------------

func get_player_data(key: String) -> Dictionary:
	return data.get("players", {}).get(key, {})


## Stores a player's progress in the world (host side), e.g. one sent by a joined player.
func set_player_data(key: String, progress: Dictionary) -> void:
	if not data.has("players"):
		return
	data["players"][key] = progress


## Called when a game starts, with the character on this computer.
func begin_session(player: Node) -> void:
	session_player = player
	_since_save = 0.0


func end_session() -> void:
	save_now()
	session_player = null


## Saves right now. The world's owner writes the file; a joined player sends their
## progress to the host instead.
func save_now() -> void:
	_since_save = 0.0
	if session_player == null or not is_instance_valid(session_player):
		return
	var progress: Dictionary = session_player.to_save_data()
	if Network.is_online() and not Network.is_host():
		Network.send_progress(progress)
		return
	if not has_world():
		return
	set_player_data(HOST_KEY, progress)
	data["last_played"] = int(Time.get_unix_time_from_system())
	_write()
	saved.emit()


## Writes the world file to disk right away (host side, e.g. after a player leaves).
func save_world_file() -> void:
	if not has_world():
		return
	if session_player != null and is_instance_valid(session_player):
		set_player_data(HOST_KEY, session_player.to_save_data())
	data["last_played"] = int(Time.get_unix_time_from_system())
	_write()


func _owns_file() -> bool:
	return has_world() and not (Network.is_online() and not Network.is_host())


# --- Files -----------------------------------------------------------------------------------

func _path(id: String) -> String:
	return "%s/%s.json" % [DIR, id]


func _write() -> void:
	var path := _path(current_id)
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		push_error("Could not save the world (error %d)." % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	# Keep the previous save as a backup, then swap the new one in.
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".bak")
	DirAccess.rename_absolute(temp, path)


## Reads a world file (falling back to its backup if it is damaged). Empty if unreadable.
func _read(id: String) -> Dictionary:
	for path in [_path(id), _path(id) + ".bak"]:
		if not FileAccess.file_exists(path):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary and parsed.has("name"):
			return parsed
	return {}
