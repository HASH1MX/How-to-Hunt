extends IslandWorld
## The Crash Forest: the first island. Easy, peaceful animals live here, and Captain Gus's
## story happens here (see GusStory and QuestLibrary): fix his leg, feed him, light a
## campfire, find the radar parts, hunt a deer, then signal for help with the flare gun.
## The main menu also uses this scene as its background, with spawn_player off.

var _case: FlareCase


## Sticks lie around under the trees (and more fall out when you punch a tree).
const STICK_COUNT := 45
## Where the radar parts are: [angle in degrees, distance from the middle]. Wires east,
## battery up the western mountains, antenna north-west (see GusStory).
const SCRAP_SPOTS := {
	&"wire_bundle": [35.0, 75.0],
	&"battery": [150.0, 120.0],
	&"antenna": [250.0, 100.0],
}
## Where the campfire is built, next to Gus.
const CAMPFIRE_AT := Vector2(-6.4, -0.3)
## The plane's radar (pulled out next to the seats) and the emergency case (by the cockpit).
const RADAR_AT := Vector3(-0.4, 0.0, -3.4)
const CASE_AT := Vector3(6.6, 0.0, -9.6)
## Where the rescue helicopter lands (the open field by the crash site).
const LANDING_AT := Vector2(12.0, 18.0)


func _scatter_sticks(world_sync: WorldSync) -> void:
	if Network.is_online() and not Network.is_host():
		return # The host's items are sent to us.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7777
	var stick := ItemLibrary.get_item(&"stick")
	var terrain: Terrain = terrain
	var placed := 0
	var tries := 0
	while placed < STICK_COUNT and tries < 600:
		tries += 1
		var angle := rng.randf() * TAU
		var dist := sqrt(rng.randf_range(22.0 * 22.0, 135.0 * 135.0))
		var x := cos(angle) * dist
		var z := sin(angle) * dist
		var height := terrain.get_height(x, z)
		if height < terrain.water_level + 1.5 or dist > terrain.mountain_radius * 0.92:
			continue
		var item := WorldSync.spawn_item(self, stick, Vector3(x, height + 0.4, z), Vector3.ZERO)
		if item != null:
			item.rotation.y = rng.randf() * TAU
		placed += 1


## Loose items aren't saved, so if the case was opened but the flare not fired yet, a flare
## gun waits in the case again.
func _replace_flare_gun(case: Node3D) -> void:
	if Network.is_online() and not Network.is_host():
		return
	if Quests.is_active("signal_for_help") and Quests.get_progress("signal_for_help", 0) > 0 and Quests.get_progress("signal_for_help", 1) == 0:
		WorldSync.spawn_item(self, ItemLibrary.get_item(&"flare_gun"), case.global_position + Vector3(0, 0.5, 0), Vector3.ZERO)


## The three radar parts, each with a beam of light, unless they were already handed over.
func _place_scrap() -> void:
	if Network.is_online() and not Network.is_host():
		return
	if Quests.is_done("scrap_hunt"):
		return
	var terrain: Terrain = terrain
	var objective_index := {&"wire_bundle": 0, &"battery": 1, &"antenna": 2}
	for id in SCRAP_SPOTS:
		if Quests.get_progress("scrap_hunt", objective_index[id]) > 0:
			continue
		var angle := deg_to_rad(SCRAP_SPOTS[id][0])
		var dist: float = SCRAP_SPOTS[id][1]
		var x := cos(angle) * dist
		var z := sin(angle) * dist
		WorldSync.spawn_item(self, ItemLibrary.get_item(id), Vector3(x, terrain.get_height(x, z) + 0.5, z), Vector3.ZERO)


## The first-aid kit and cloth Gus asks for lie near the wreck until they've been handed over.
func _place_quest_items(world_sync: WorldSync) -> void:
	var items := get_node_or_null("QuestItems")
	if items == null:
		return
	if Network.is_online() and not Network.is_host():
		items.queue_free() # The host sends every item.
		return
	for child in items.get_children():
		var done := Quests.get_progress("patch_me_up", 0 if child.item_id == &"first_aid_kit" else 2) > 0 or Quests.is_done("patch_me_up")
		if done:
			child.queue_free()
		elif world_sync != null:
			world_sync.register_existing_item(child)


# --- Island hooks (see IslandWorld) ----------------------------------------------------------

func _place_story_props() -> void:
	# Gus's campfire (lit by the quest "Light a Fire").
	var campfire := Campfire.new()
	campfire.name = "Campfire"
	add_child(campfire)
	campfire.position = Vector3(CAMPFIRE_AT.x, terrain.get_height(CAMPFIRE_AT.x, CAMPFIRE_AT.y), CAMPFIRE_AT.y)
	var radar := RadarConsole.new()
	radar.name = "Radar"
	add_child(radar)
	radar.position = Vector3(RADAR_AT.x, terrain.get_height(RADAR_AT.x, RADAR_AT.z) - 0.05, RADAR_AT.z)
	radar.rotation.y = 0.6
	_case = FlareCase.new()
	_case.name = "EmergencyCase"
	add_child(_case)
	_case.position = Vector3(CASE_AT.x, terrain.get_height(CASE_AT.x, CASE_AT.z) - 0.04, CASE_AT.z)
	_case.rotation = Vector3(0.0, 1.2, 0.08)
	var rescue := RescueEvent.new()
	rescue.name = "Rescue"
	rescue.landing_at = Vector3(LANDING_AT.x, terrain.get_height(LANDING_AT.x, LANDING_AT.y), LANDING_AT.y)
	rescue.water_level = terrain.water_level
	add_child(rescue)


func _place_story_items() -> void:
	_place_quest_items(world_sync)
	_scatter_sticks(world_sync)
	_place_scrap()
	_replace_flare_gun(_case)
