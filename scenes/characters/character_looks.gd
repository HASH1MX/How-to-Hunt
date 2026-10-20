class_name CharacterLooks
## Ready-made outfits for the story's characters (so the same look is used everywhere,
## e.g. Nurse Nina in the helicopter and on Island 2).

## Nurse Nina: white scrubs top, light blue trousers, a white nurse's cap with a red cross,
## dark hair tied in a bun.
static func nurse(model: CharacterModel) -> void:
	model.skin_color = Color(0.62, 0.43, 0.3)
	model.shirt_color = Color(0.96, 0.96, 0.94)
	model.short_sleeves = true
	model.pants_color = Color(0.55, 0.72, 0.85)
	model.shoe_color = Color(0.95, 0.95, 0.95)
	model.hat = CharacterModel.Hat.NURSE_CAP
	model.hair_color = Color(0.12, 0.08, 0.06)
	model.hair_bun = true


## Trader Tomas: an orange apron over a blue shirt, a grey beanie and a big beard.
static func trader(model: CharacterModel) -> void:
	model.skin_color = Color(0.82, 0.62, 0.45)
	model.shirt_color = Color(0.25, 0.38, 0.6)
	model.pants_color = Color(0.3, 0.25, 0.2)
	model.wear_apron = true
	model.apron_color = Color(0.85, 0.5, 0.16)
	model.hat = CharacterModel.Hat.BEANIE
	model.hat_color = Color(0.45, 0.45, 0.48)
	model.beard = true
	model.hair_color = Color(0.4, 0.28, 0.18)
