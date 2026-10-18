# How to Hunt — Progress Log

## Stages

| # | Stage | Status |
|---|---|---|
| 1 | Development setup | ✅ Done |
| 2 | First playable prototype + Windows export | ✅ Done |
| 3 | Crash Forest | 🔨 Nearly done (new `.exe` export still to do) |
| 4 | Player system | 🔨 Mostly done early, at the user's request |
| 5 | Animal system | ✅ Done: rabbits, chickens, squirrels, a few deer |
| 6 | Hunting and punching | ✅ Done: punching (10 dmg), damage numbers, loot drops |
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

**Animals (first island: easy, never attack)**
- Rabbit (30 HP, shy), Chicken (20 HP), Squirrel (20 HP, shy), Deer (80 HP, very shy, only 4).
- Wander, flee when hit or when you run near them (crouch to sneak up), respawn 60 s after being hunted.
- Drop loot: Rabbit Pelt, Feathers, Squirrel Tail, Deer Hide (sell values ready for the merchant).
- Floating damage numbers, white hit flash and knockback.

**Settings and menus**
- Esc pause menu (Resume / Settings / Main Menu / Quit).
- Settings: mouse sensitivity, invert Y, FOV, graphics presets and options, window mode, V-Sync, FPS limit, rebindable keys. Saved to the user folder.

**GUI (How to Fish style, Kurale font)**
- Round health / food / breath icons, stamina bar, inventory slots with 3D item icons, money box, quest tip (J), pick-up / talk prompts, underwater tint and damage flash.

## Controls

| Key | Action |
|---|---|
| WASD | Move |
| Shift | Sprint |
| Ctrl | Crouch (hold) |
| Space | Jump |
| Mouse | Look |
| Left click | Punch (click fast, or hold) |
| E | Pick up / talk / continue dialogue |
| 1-4 | Select slot, or store the hand item there |
| Q | Drop held item |
| J | Show / hide quest tip |
| Esc | Pause menu |

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
| Settings autoload (`Settings`), saved in `user://settings.cfg` | One place for all options; prompts show the player's own key names. |
| Animals extend one `Animal` base class | Each species only defines its stats, model and animation. |
| Characters, animals and first-person arms use smooth rounded shading (`LowPoly.add_smooth_shape`) | The faceted/boxy look read as pixelated; How to Fish characters are soft and round. Terrain and props stay faceted. |
| Island is 540 m wide (coast radius 214, mountains at 154) | Bigger map, props and animals scaled up about 2.5x to match. |
| Multiplayer: Godot ENet, host = server, friends join by IP (`Network` autoload) | Free, no extra service. Each player runs their own world from fixed seeds and sends only their position/actions (20/s). Host tries UPnP to open the router port. Stage A done: connect, spawn, sync, names, join/leave. Animals and dropped items are NOT shared yet; no internet relay yet. |
| Internet play through Steam relay (GodotSteam GDExtension in `addons/godotsteam`, app id 480 "Spacewar", `steam_appid.txt`) | Free Valve relay, no router setup, join by lobby code or open-games list. Lobby create/list verified on one account; the actual two-account connection still needs a friend test. Exe folder must keep the two DLLs and steam_appid.txt next to it. Own app id ($100) later. |
| Save games: many worlds, each one file `user://worlds/<id>.json` (`SaveManager`) | Progress per player (position, health, food, money, inventory) stored by player key. Host owns the file; joined players get theirs from the host and send it back as they play. Autosave 30 s + on leaving. Animals/loose items and the map itself are not saved (every world uses the same island). |
| Sound: `Sfx` autoload with sound groups; Kenney CC0 packs (Impact Sounds, RPG Audio, Interface Sounds) for footsteps/hits/UI + our own synthesized wind, waves, birds, water, animal calls and voice blips (`tools/make_sounds.py`) | Footsteps by surface, jump/land/swim/punch/hurt, animal voices, dialogue blips, ambience, muffled under water, volume sliders in Settings. Synthesized sounds were not auditioned by ear while building. No music yet. |
| `WorldSync`: host owns animals and loose items; joined players see puppets | Animals near each player are sent 10x/s; items spawn/remove/settle events + moving items. Pickup, drop, push and animal hits are requests the host checks (distance, damage cap). Wind/wave ambience lowered. Protocol 3. |
| Hunted animals become their own body item and drop nothing else. Feed it to Captain Gus (drop it within ~2 m of his face; a mouth Area3D eats it) and the player who dropped it is paid: chicken $6, squirrel $14, rabbit $18, deer $60 (priced by difficulty) | First step of the economy. The host judges feeding and pays the right player. Money is client-side for now (a joined player could cheat; the host should check later). Protocol 5. |
| `build/` is not stored in Git | Builds are large; they will be shared through GitHub Releases. |

## How to export (command line)

```
"H:\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --export-release "Windows Desktop" build/windows/HowToHunt.exe
```
