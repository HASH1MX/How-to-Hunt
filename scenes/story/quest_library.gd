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
##                       "sell"  - dropped in the trader's crate (key: item; "any" = anything)
##                 text  what the tracker says
##   reward      - money paid to every player when it is done
##   next        - quests that start when this one is finished
##
## Island 1 story (Crash Forest), built in phases:
##   mayday -> patch_me_up -> hungry_captain -> (more tasks later: rabbits, fire, plane parts, deer,
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
			next = ["hungry_captain"],
		},
		"hungry_captain": {
			title = "Hungry Captain",
			objectives = [
				{type = "feed", item = "rabbit", npc = "gus", count = 3, text = "Feed Gus rabbits"},
			],
			reward = 40,
			next = ["light_a_fire"],
		},
		"light_a_fire": {
			title = "Light a Fire",
			objectives = [
				{type = "give", item = "stick", npc = "gus", count = 5, text = "Bring 5 sticks for a campfire"},
			],
			reward = 40,
			next = ["scrap_hunt"],
		},
		"scrap_hunt": {
			title = "Scrap Hunt",
			objectives = [
				{type = "give", item = "wire_bundle", npc = "gus", count = 1, text = "Find the wire bundle (east)"},
				{type = "give", item = "battery", npc = "gus", count = 1, text = "Find the battery (western mountains)"},
				{type = "give", item = "antenna", npc = "gus", count = 1, text = "Find the antenna (north-west)"},
			],
			reward = 60,
			next = ["big_game"],
		},
		"big_game": {
			title = "Big Game",
			objectives = [
				{type = "feed", item = "deer", npc = "gus", count = 1, text = "Feed Gus a deer"},
			],
			reward = 100,
			next = ["signal_for_help"],
		},
		"signal_for_help": {
			title = "Signal for Help",
			objectives = [
				{type = "flag", flag = "case_opened", count = 1, text = "Open the emergency case by the cockpit (Gus has the key)"},
				{type = "flag", flag = "flare_fired", count = 1, text = "Fire the flare gun from a mountain top"},
			],
			reward = 50,
			next = ["rescue"],
		},
		"rescue": {
			title = "Rescue!",
			objectives = [
				{type = "flag", flag = "boarded", count = 1, text = "Board the rescue helicopter"},
			],
			reward = 0,
			next = ["washed_ashore"],
		},
		# --- Island 2: the Jungle (see NinaStory) ---
		"washed_ashore": {
			title = "Washed Ashore",
			objectives = [
				{type = "talk", npc = "nina", count = 1, text = "Talk to the woman on the beach"},
			],
			reward = 0,
			next = ["gus_memorial"],
		},
		"gus_memorial": {
			title = "Gus's Memorial",
			objectives = [
				{type = "give", item = "gus_hat", npc = "nina", count = 1, text = "Find Captain Gus's cap on the beach and bring it to Nina"},
			],
			reward = 50,
			next = ["jungle_trade"],
		},
		"jungle_trade": {
			title = "Supplies",
			objectives = [
				{type = "sell", item = "any", count = 3, text = "Sell 3 animals in Tomas's crate"},
			],
			reward = 80,
			next = ["apex_predator"],
		},
		"apex_predator": {
			title = "Apex Predator",
			objectives = [
				{type = "sell", item = "jaguar", count = 1, text = "Hunt the jaguar and sell it to Tomas"},
			],
			reward = 300,
			next = [],
		},
	}
