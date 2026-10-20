class_name NinaStory
## What Nurse Nina says on Island 2. She was the helicopter's nurse; she and the players are
## the only ones who made it out of the crash. Captain Gus and the pilot didn't. She's
## practical, warm and a little bossy, and keeps everyone going.

const ARRIVAL: Array[String] = [
	"Easy, easy. Don't sit up so fast. You swallowed half the ocean.",
	"I'm Nina. I was the nurse on that helicopter. The engine caught fire and we went into the sea.",
	"I pulled you out. I looked for the others for hours. The pilot... and your captain. I'm so sorry. It's just us now.",
	"There's a little trading post up the beach. Tomas runs it. He's strange, but he has food, guns and a working stove.",
	"First things first, though. Something of your captain's washed up further along the sand. Would you bring it to me?",
]


static func talk_lines() -> PackedStringArray:
	if Quests.is_active("washed_ashore"):
		return PackedStringArray(ARRIVAL)
	if Quests.is_active("gus_memorial"):
		return PackedStringArray([
			"Your captain's cap washed up along the beach. It's glowing in the sun, you can't miss it.",
			"Bring it to me and press E. He deserves to be remembered.",
		])
	if Quests.is_active("jungle_trade"):
		return PackedStringArray([
			"There. He'll watch over the beach now. Gus would have liked the view.",
			"Now we need money for supplies. Hunt in the jungle and drop what you catch in Tomas's crate. He pays fair.",
			"Careful in there: boars bite back when you hit them, and something big has been prowling at night. Maybe buy a proper gun.",
		])
	if Quests.is_active("apex_predator"):
		return PackedStringArray([
			"That big thing prowling the jungle is a jaguar. It's been circling our camp.",
			"It hunts anything it sees, so crouch to stay hidden and keep your distance. A shotgun up close, or a sniper rifle from far away.",
			"Bring it to Tomas's crate. Then we can sleep at night.",
		])
	if Quests.is_done("apex_predator"):
		return PackedStringArray([
			"You did it. The jungle's a lot quieter now.",
			"And listen: my radio picked up a signal last night. Far off, but real. There's someone else out there.",
			"We'll find them. But for now, rest. You've earned it.",
		])
	return PackedStringArray(["Stay safe out there."])


## What she says when you hand her something.
static func thanks_lines(item_id: String, _count: int) -> PackedStringArray:
	if item_id == "gus_hat":
		return PackedStringArray([
			"His cap. Oh, Captain...",
			"I'll make a little memorial right here on the beach, where he can see the sea.",
		])
	return PackedStringArray(["Thank you."])
