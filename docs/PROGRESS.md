# How to Hunt — Progress Log

## Stages

| # | Stage | Status |
|---|---|---|
| 1 | Development setup | ✅ Done |
| 2 | First playable prototype + Windows export | ✅ Done |
| 3 | Crash Forest | ⏳ Next |
| 4 | Player system | — |
| 5 | Animal system | — |
| 6 | Hunting and punching | — |
| 7 | Inventory and economy | — |
| 8 | Merchant and weapons | — |
| 9 | Multiplayer prototype | — |
| 10 | Multiplayer gameplay | — |
| 11 | Private internet lobbies | — |
| 12 | Portal and second forest | — |
| 13 | More content | — |
| 14 | Polish and performance | — |
| 15 | Release | — |

## What works now

- Godot 4.7.2 project with Forward+ renderer and Jolt physics.
- Test world: ground, sky, sun with shadows, 3 crates.
- Third-person player: WASD, mouse look, Space to jump, Esc frees the mouse, respawn after falling.
- Windows export: `build/windows/HowToHunt.exe` (single file, PCK embedded). Tested by the user outside the editor.

## Technical decisions

| Decision | Why |
|---|---|
| Godot 4.7.2 standard (not .NET), GDScript | Project requirement; GDScript needs no extra tools. |
| Forward+ renderer | Best 3D quality on Windows PCs. |
| Jolt Physics | Godot 4.7 default; faster and more stable than the old engine. |
| Third-person camera on a SpringArm3D | Players see their character; the camera won't clip through walls. |
| Scenes and their scripts in the same folder (`scenes/<thing>/`) | Easy to find related files. |
| Embed PCK in the export | One `.exe` to share instead of two files. |
| `build/` is not stored in Git | Builds are large; they will be shared through GitHub Releases. |
| Input actions: `move_forward`, `move_back`, `move_left`, `move_right`, `jump` | Named actions so keys can be changed later without editing scripts. |

## How to export (command line)

```
"H:\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --export-release "Windows Desktop" build/windows/HowToHunt.exe
```
