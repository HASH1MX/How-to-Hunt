# How to Hunt — Progress Log

## Stages

| # | Stage | Status |
|---|---|---|
| 1 | Development setup | ✅ Done |
| 2 | First playable prototype + Windows export | ✅ Done |
| 3 | Crash Forest | 🔨 Nearly done (new `.exe` export still to do) |
| 4 | Player system | 🔨 Mostly done early, at the user's request |
| 5 | Animal system | — |
| 6 | Hunting and punching | 🔨 Punching done (10 damage); animals, loot still to do |
| 7 | Inventory and economy | 🔨 Inventory done; cash still to do |
| 8 | Merchant and weapons | — |
| 9 | Multiplayer prototype | — |
| 10 | Multiplayer gameplay | — |
| 11 | Private internet lobbies | — |
| 12 | Portal and second forest | — |
| 13 | More content | — |
| 14 | Polish and performance | — |
| 15 | Release | — |

## What works now

**World**
- Start page: the island in the background with a slowly circling camera, Play / Quit.
- Low-poly island built in code: forest in the middle, a crash-site clearing, a climbable mountain ring, beach and ocean all around (endless sea floor underneath).
- Code-built nature: pine, leafy and birch trees, bushes with berries, rocks, logs, stumps, flowers, mushrooms, pebbles and grass, all slightly varied in colour.
- Crashed airplane broken in two, with torn metal, wires, seats, luggage, an escape slide, a lost wheel, scorch marks and engine smoke.
- How to Fish-style lighting: low sun, long shadows, blue haze.

**Characters**
- Code-built How to Fish-style character model (bean head, googly eyes, outfits, sitting pose, breathing / looking / talking animations).
- Captain Gus, the pilot NPC: sits by the plane, follows the player with his head, tells the crash story and gives the "Find a Way Out" quest.

**Player (first person)**
- WASD, mouse look, Shift sprint (uses stamina), Space jump (uses stamina, 0.4 s cooldown), fall damage.
- First-person fists with walk bob, sway, landing dip and alternating punches (left click, 10 damage, 2 m reach).
- Health, food (empties in 12 minutes, then slowly hurts), stamina.
- Deep water: you sink, 3 jumps to push up, breath lasts 6 s with your head under water, then drowning damage.
- Inventory: 4 slots + a hand slot. E picks up into the hand, 1-4 stores, Q drops. Placeholder stone and stick items.
- E talks to NPCs; conversations type out in a dialogue box.

**GUI (How to Fish style, Kurale font)**
- Round health / food / breath icons, stamina bar, inventory slots with 3D item icons, money box, quest tip (J), pick-up / talk prompts, underwater tint and damage flash.

## Controls

| Key | Action |
|---|---|
| WASD | Move |
| Shift | Sprint |
| Space | Jump |
| Mouse | Look |
| Left click | Punch |
| E | Pick up / talk / continue dialogue |
| 1-4 | Select slot, or store the hand item there |
| Q | Drop held item |
| J | Show / hide quest tip |
| Esc | Free the mouse |

## Technical decisions

| Decision | Why |
|---|---|
| Godot 4.7.2 standard (not .NET), GDScript | Project requirement; GDScript needs no extra tools. |
| Forward+ renderer, Jolt Physics | Best 3D quality on Windows; Jolt is faster and more stable. |
| First-person camera | Matches How to Fish (user's choice). |
| All models built in code from simple shapes (`LowPoly` helper) | User wanted no downloaded model packs; flat-shaded shapes give the How to Fish look. |
| Fixed seeds for terrain and scatter | Every player gets an identical world in multiplayer. |
| MultiMesh + distance fading for props | Thousands of trees and grass clumps stay fast. |
| Kurale font from Google Fonts (OFL licence, in `assets/fonts`) | Closest free match to How to Fish's font. Patrick Hand and Fredoka were downloaded as alternatives. |
| Interactables use `interact(player)` and `get_interact_text()` | Items, NPCs and future things (merchant, portal) all work with E the same way. |
| Damage uses `take_hit(amount, from, at)` | Animals only need this one method to be punchable. |
| Physics layers: 1 world, 3 items, 4 interactables | The E ray only finds things you can use. |
| `build/` is not stored in Git | Builds are large; they will be shared through GitHub Releases. |

## How to export (command line)

```
"H:\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --export-release "Windows Desktop" build/windows/HowToHunt.exe
```
