class_name GusStory
## What Captain Gus says, depending on how far the story has got. The story, in short:
## a bird flew into the engine fan, the engine burned, the plane crashed in the Crash Forest
## and Gus hurt his leg. You patch him up, feed him, light a campfire, hunt down the plane
## parts for the radar, and hunt a deer. Tone: Gus is a dramatic, clumsy, good-hearted captain.

## Every spoken line, in one place, so the story is easy to rewrite.
const INTRO: Array[String] = [
	"Oh! You're alive! Thank goodness... I thought I was the only one who made it out of that mess.",
	"I'm Gus. Captain Gus. Well... captain of a plane that used to fly.",
	"We were cruising along, perfect weather, not a cloud in the sky. Then ONE little bird flew straight into the left engine fan.",
	"FWUMP. Feathers everywhere. The engine caught fire, the fire caught the wing, and the wing caught my pride.",
	"I tried to glide us down onto the beach, but those mountains came out of nowhere. We skidded right over them and the trees took a wing as a souvenir.",
	"And now my leg has stopped working, so I'm stuck in this seat. It's just you and me, kid.",
	"Can you help an old captain out? I need three things: a first-aid kit from the wreck (a white box with a red cross, check the spilled luggage), two sticks for a splint, and some cloth to tie it all up.",
	"Bring them to me and press E. Oh, and I'm starving. Catch something and drop it right in front of my face, and I'll pay you for it!",
]

const KIT_CLUES := "The first-aid kit is a white box with a red cross. Try the spilled luggage by the tail."
const CLOTH_CLUES := "For cloth, look around the thrown-out seats."

## What he says when a quest's last item arrives.
const FINISH_LINES := {
	"patch_me_up": [
		"That's everything! Now hold still while I... ow. OW. Okay. Okay! That actually helps. I owe you one.",
		"Here, take a little cash for your trouble. And look: I can stand! Sort of!",
	],
	"light_a_fire": [
		"Sticks stacked, a little spark, and... FIRE! Look at that. Warm, bright and only slightly dangerous.",
		"Here's some cash. Now that I can see in the dark, I can finally start on our escape plan.",
	],
	"scrap_hunt": [
		"The wires, the battery AND the antenna! You're a miracle worker. This radar might actually work!",
		"Give me a moment to plug things in... I'm a captain, not an electrician, but how hard can it be?",
	],
}


## The lines for a normal conversation right now.
static func talk_lines() -> PackedStringArray:
	if Quests.is_active("mayday"):
		return PackedStringArray(INTRO)
	if Quests.is_active("patch_me_up"):
		return PackedStringArray([
			"Still waiting on my leg treatment! I need: %s." % _missing("patch_me_up"),
			"%s %s" % [KIT_CLUES, CLOTH_CLUES],
			"And if you catch something, drop it right in my face. I mean that nicely.",
		])
	if Quests.is_active("hungry_captain"):
		return PackedStringArray([
			"Look at me! Standing! Well, leaning. On a stick. But standing!",
			"Now, about food. I'm so hungry I could eat a whole rabbit, so please catch me three. Drop them right in front of my face.",
			"Rabbits hop away when you run at them, so sneak up on them. Hold crouch and they won't spook as easily.",
		])
	if Quests.is_active("light_a_fire"):
		return PackedStringArray([
			"Mmm, rabbit. I feel like a new man. A new man with a stick. A very cold one.",
			"The sun is going to set eventually and I'd like a campfire. Can you bring me 5 sticks? Stack them up and hand them over.",
			"Sticks lie around under the trees. Look for brown ones in the grass and press E to pick them up. Or punch a tree and one might fall out.",
		])
	if Quests.is_active("scrap_hunt"):
		return PackedStringArray([
			"Now for the big idea. The plane's radar still has a screen and a dish, but the parts that make it work flew off in the crash.",
			"I need a wire bundle, a battery and the antenna. They're glowing, you can't miss them, as long as you're close.",
			"I saw the wires fly EAST, the battery bounce up the WESTERN mountains, and the antenna spin off to the NORTH-WEST. Look for a tall beam of light!",
		])
	if Quests.is_active("big_game"):
		return PackedStringArray([
			"The radar is warming up! It beeps and everything. But it needs power, and a captain needs a proper feast.",
			"There's a deer out there somewhere. A big one. Deer are shy and fast, and eight punches' worth of tough. Sneak up on it. Crouch!",
			"Bring it to me and drop it at my face. I'll cook, I mean eat, it. Don't tell it I said that.",
		])
	if Quests.is_done("big_game"):
		return PackedStringArray([
			"That was the best meal of my life. The radar is humming, and I think I see another island on the screen!",
			"More jobs soon, kid. We're getting closer to getting off this rock.",
		])
	return PackedStringArray(["Drop what you hunt right in front of my face. I'll pay for it!"])


## The active quest that is waiting for `item_id` to be handed over, or "".
static func quest_for_item(item_id: String) -> String:
	for id in Quests.get_active():
		for objective in QuestLibrary.get_def(id).objectives:
			if objective.type == "give" and String(objective.item) == item_id:
				return id
	return ""


## What he says when you hand him `count` of an item.
static func thanks_lines(item_id: String, count: int) -> PackedStringArray:
	var quest_id := quest_for_item(item_id)
	var lines: Array[String] = []
	match item_id:
		"first_aid_kit":
			lines.append("The first-aid kit! Bless you, kid. It's only slightly burnt.")
		"stick":
			lines.append("%s A fine stick. Very stick-like." % (("%d sticks!" % count) if count > 1 else "A stick!"))
		"cloth":
			lines.append("Cloth! Soft. A little singed, but soft.")
		"wire_bundle":
			lines.append("The wire bundle! Tangled, but I love a good tangle.")
		"battery":
			lines.append("The battery! Heavy. Slightly cracked. Perfect.")
		"antenna":
			lines.append("The antenna! Now we can hear the whole sky.")
		_:
			lines.append("Thanks, kid!")
	var rest := _missing(quest_id, item_id, count) if quest_id != "" else ""
	if rest == "" and FINISH_LINES.has(quest_id):
		lines.append_array(FINISH_LINES[quest_id])
	elif rest != "":
		lines.append("I still need: %s." % rest)
	return PackedStringArray(lines)


## "a first aid kit, 1 more stick" style list of what is still missing from a quest. The
## optional pending item is counted as already handed over.
static func _missing(quest_id: String, pending_item: String = "", pending_count: int = 0) -> String:
	var def := QuestLibrary.get_def(quest_id)
	var parts: Array[String] = []
	for i in def.objectives.size():
		var objective: Dictionary = def.objectives[i]
		var left: int = int(objective.count) - Quests.get_progress(quest_id, i)
		if String(objective.get("item", "")) == pending_item:
			left -= pending_count
		if left > 0:
			var name := String(objective.item).replace("_", " ")
			parts.append("%d %s" % [left, name] if int(objective.count) > 1 else "a %s" % name)
	return ", ".join(parts)
