extends Node
## The quest system (autoload "Quests"). Keeps track of which quests are active or done
## and how far each objective has got. The whole team shares one set of quests:
##
##   - The HOST (or a solo player) owns the progress. Joined players send what they do
##     ("I gave 2 sticks to Gus") to the host, who updates the quests and sends the new
##     state to everyone.
##   - Progress is saved in the world file, so it survives quitting.
##   - When a quest is completed every player gets its reward.
##
## Game code reports things with Quests.report(kind, key, amount) - for example
## Quests.report("talk", "gus") - and the quest system matches that against the active quests'
## objectives (see QuestLibrary). The tracker in the HUD listens to `changed`.

signal changed
## A quest began or finished (kind is "started" or "completed"); for the on-screen banner.
signal announced(kind: String, quest_id: String, reward: int)
## The quest state is ready (the game just started, or a joined player got the host's state).
## Characters use it to take their starting pose without animating.
signal session_started

## quest id -> {status = "active" or "done", progress = [one number per objective]}
var state := {}
var _order: Array[String] = []
var _got_state := false


# --- Reading ------------------------------------------------------------------------------

func is_active(id: String) -> bool:
	return state.has(id) and state[id].status == "active"


func is_done(id: String) -> bool:
	return state.has(id) and state[id].status == "done"


## Active quest ids, oldest first.
func get_active() -> Array[String]:
	var active: Array[String] = []
	for id in _order:
		if is_active(id):
			active.append(id)
	return active


func get_progress(id: String, objective: int) -> int:
	if not state.has(id):
		return 0
	var progress: Array = state[id].progress
	return int(progress[objective]) if objective < progress.size() else 0


## How many more of this (kind, key) the active quests are still waiting for.
func needed(kind: String, key: String) -> int:
	var total := 0
	for id in get_active():
		var objectives: Array = QuestLibrary.get_def(id).objectives
		for i in objectives.size():
			if _matches(objectives[i], kind, key):
				total += int(objectives[i].count) - get_progress(id, i)
	return total


# --- Starting a game -----------------------------------------------------------------------

## Called when a game starts. The host (or a solo player) loads the saved quests, or starts
## the first one; a joined player asks the host for the current state.
func begin_session() -> void:
	if Network.is_online() and not Network.is_host():
		_got_state = false
		_request_state.rpc_id(1)
		return
	state = {}
	_order = []
	var saved: Dictionary = SaveManager.data.get("world", {}).get("quests", {})
	for id in saved:
		if QuestLibrary.get_def(id).is_empty():
			continue
		var progress: Array = []
		for number in saved[id].get("progress", []):
			progress.append(int(number))
		state[id] = {status = str(saved[id].get("status", "active")), progress = progress}
		_order.append(id)
	if state.is_empty():
		_start("mayday")
	# Saves from before a follow-up quest existed: make sure finished quests' next ones began.
	for id in state.keys():
		if is_done(id):
			for next_id in QuestLibrary.get_def(id).next:
				_start(next_id)
	changed.emit()
	session_started.emit()


# --- Reporting what happened -----------------------------------------------------------------

## Something happened that quests may care about (talked to an NPC, handed over items...).
## A joined player's report is sent to the host.
func report(kind: String, key: String, amount: int = 1) -> void:
	if Network.is_online() and not Network.is_host():
		_request_report.rpc_id(1, kind, key, amount)
		return
	_apply_report(kind, key, amount)


func _apply_report(kind: String, key: String, amount: int) -> void:
	var finished: Array[String] = []
	for id in get_active():
		var def := QuestLibrary.get_def(id)
		var progress: Array = state[id].progress
		var touched := false
		for i in def.objectives.size():
			var objective: Dictionary = def.objectives[i]
			if _matches(objective, kind, key) and int(progress[i]) < int(objective.count):
				progress[i] = mini(int(progress[i]) + amount, int(objective.count))
				touched = true
		if touched and _all_done(id):
			finished.append(id)
	for id in finished:
		_complete(id)
	_broadcast()


func _matches(objective: Dictionary, expected_kind: String, key: String) -> bool:
	if objective.type != expected_kind:
		return false
	# What each kind of objective is about: who (talk), which item (give, feed), which flag.
	var about := "npc" if expected_kind == "talk" else ("flag" if expected_kind == "flag" else "item")
	var wanted := String(objective.get(about, ""))
	return wanted == "any" or key == wanted


func _all_done(id: String) -> bool:
	var objectives: Array = QuestLibrary.get_def(id).objectives
	for i in objectives.size():
		if get_progress(id, i) < int(objectives[i].count):
			return false
	return true


func _start(id: String) -> void:
	var def := QuestLibrary.get_def(id)
	if def.is_empty() or state.has(id):
		return
	var progress: Array = []
	progress.resize(def.objectives.size())
	progress.fill(0)
	state[id] = {status = "active", progress = progress}
	_order.append(id)
	if Network.is_online():
		_announce.rpc("started", id, 0)
	else:
		_show_announcement("started", id, 0)


func _complete(id: String) -> void:
	state[id].status = "done"
	var def := QuestLibrary.get_def(id)
	var reward: int = def.reward
	if Network.is_online():
		_announce.rpc("completed", id, reward)
	else:
		_show_announcement("completed", id, reward)
	for next_id in def.next:
		_start(next_id)


## Host: saves the quests in the world file and sends the new state to every player.
func _broadcast() -> void:
	if SaveManager.has_world():
		SaveManager.data["world"]["quests"] = state.duplicate(true)
		SaveManager.save_world_file()
	if Network.is_online():
		_receive_state.rpc(state, _order)
	changed.emit()


# --- Multiplayer -------------------------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _request_state() -> void:
	if multiplayer.is_server():
		_receive_state.rpc_id(multiplayer.get_remote_sender_id(), state, _order)


@rpc("any_peer", "call_remote", "reliable")
func _request_report(kind: String, key: String, amount: int) -> void:
	if multiplayer.is_server():
		# A player can't claim more than a stack's worth at once.
		_apply_report(kind, key, clampi(amount, 1, 5))


@rpc("authority", "call_remote", "reliable")
func _receive_state(new_state: Dictionary, new_order: Array) -> void:
	state = new_state
	_order.assign(new_order)
	changed.emit()
	if not _got_state:
		_got_state = true
		session_started.emit()


## Everyone (including the host) shows the banner; completing pays everyone their reward.
@rpc("authority", "call_local", "reliable")
func _announce(kind: String, quest_id: String, reward: int) -> void:
	_show_announcement(kind, quest_id, reward)


func _show_announcement(kind: String, quest_id: String, reward: int) -> void:
	if kind == "completed" and reward > 0:
		var player := get_tree().get_first_node_in_group("players")
		if player != null:
			player.add_money(reward)
	announced.emit(kind, quest_id, reward)
