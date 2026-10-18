class_name GusStory
## What Captain Gus says, depending on how far the story has got. The story, in short:
## a bird flew into the engine fan, the engine burned, the plane crashed in the Crash Forest
## and Gus hurt his leg. He needs a first-aid kit, sticks for a splint and cloth. Tone: Gus
## is a dramatic, clumsy, good-hearted captain.

## Every spoken line, in one place, so the story is easy to rewrite.
const INTRO: Array[String] = [
	"Oh! You're alive! Thank goodness... I thought I was the only one who made it out of that mess.",
	"I'm Gus. Captain Gus. Well... captain of a plane that used to fly.",
	"We were cruising along, perfect weather, not a cloud in the sky. Then ONE little bird flew straight into the left engine fan.",
	"FWUMP. Feathers everywhere. The engine caught fire, the fire caught the wing, and the wing caught my pride.",
	"I tried to glide us down onto the beach, but those mountains came out of nowhere. We skidded right over them and the trees took a wing as a souvenir.",
	"And now my leg has stopped working, so I'm stuck in this seat. It's just you and me, kid.",
	"Can you help an old captain out? I need three things: a first-aid kit from the wreck (a little red box, check the spilled luggage), two sticks for a splint, and some cloth to tie it all up.",
	"Bring them to me and press E. Oh, and I'm starving. Catch something and drop it right in front of my face, and I'll pay you for it!",
]

const KIT_CLUES := "The first-aid kit is a little red box. Try the spilled luggage by the tail."
const CLOTH_CLUES := "For cloth, look around the thrown-out seats."


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
	if Quests.is_done("patch_me_up"):
		return PackedStringArray([
			"My leg feels so much better! I still can't walk on it, but I feel like a new man.",
			"Give me a moment to think. I have more jobs for you, and one of them might get us off this island.",
			"In the meantime, if you catch something, feed me! A hungry captain is a grumpy captain.",
		])
	return PackedStringArray(["Drop what you hunt right in front of my face. I'll pay for it!"])


## What he says when you hand him `count` of an item. `finishes` is true when that
## completes his quest.
static func thanks_lines(item_id: String, count: int, finishes: bool) -> PackedStringArray:
	var lines: Array[String] = []
	match item_id:
		"first_aid_kit":
			lines.append("The first-aid kit! Bless you, kid. It's only slightly burnt.")
		"stick":
			lines.append("%s A fine stick. Very stick-like." % ("Two sticks!" if count > 1 else "A stick!"))
		"cloth":
			lines.append("Cloth! Soft. A little singed, but soft.")
		_:
			lines.append("Thanks, kid!")
	if finishes:
		lines.append("That's everything! Now hold still while I... ow. OW. Okay. Okay! That actually helps. I owe you one.")
		lines.append("Here, take a little cash for your trouble. Come back and talk to me, I have more jobs!")
	else:
		var rest := _missing("patch_me_up", item_id, count)
		if rest != "":
			lines.append("I still need: %s." % rest)
	return PackedStringArray(lines)


## "a first-aid kit, 1 more stick" style list of what is still missing from a quest. The
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
