class_name QuestLibrary
## Every quest in the game, as plain data. To add a quest, add an entry to defs().
##
## A quest has:
##   title       - shown in the quest tracker
##   objectives  - a list of steps, all of which must be finished. Each one has
##                 type  "talk"  - talk to an NPC          (key: npc)
##                       "give"  - hand items to an NPC    (key: item, with count)
##                       "feed"  - NPC eats animal bodies  (key: item, with count)
##                       "flag"  - ticked by a script event (key: flag)
##                 text  what the tracker says
##   reward      - money paid to every player when it is done
##   next        - quests that start when this one is finished
##
## Island 1 story (Crash Forest), built in phases:
##   mayday -> patch_me_up -> (more tasks later: rabbits, fire, plane parts, deer,
##   radar, flare gun, rescue helicopter...)

static var _defs: Dictionary = {}


static func get_def(id: String) -> Dictionary:
	if _defs.is_empty():
		_defs = defs()
	return _defs.get(id, {})


static func defs() -> Dictionary:
	return {
		"mayday": {
			title = "Mayday",
			objectives = [
				{type = "talk", npc = "gus", count = 1, text = "Talk to Captain Gus"},
			],
			reward = 0,
			next = ["patch_me_up"],
		},
		"patch_me_up": {
			title = "Patch Me Up",
			objectives = [
				{type = "give", item = "first_aid_kit", npc = "gus", count = 1, text = "Find the first-aid kit"},
				{type = "give", item = "stick", npc = "gus", count = 2, text = "Bring 2 sticks for a splint"},
				{type = "give", item = "cloth", npc = "gus", count = 1, text = "Bring some cloth"},
			],
			reward = 30,
			next = [],
		},
	}
