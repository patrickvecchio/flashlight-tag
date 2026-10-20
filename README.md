# Flashlight Tag

A Roblox game that mixes Hide and Seek with Tag. Each 3-minute round picks one seeker who is surrounded by darkness and armed with a flashlight; the hiders play in a dusk scene and lose health while the beam is on them.

The full plan, including the open gameplay decisions, is in the [build plan doc](https://claude.ai/code/artifact/ef3d5f77-5eb9-406b-8134-eec61f188c4f).

## Workflow

Code and maps are managed in different places:

| What | Where it lives | How it changes |
| --- | --- | --- |
| Scripts and code | This repo (`src/`) | Edit in VS Code; Rojo syncs it into the open Studio place |
| Maps, the lobby's look, other models | Your Studio place | Edit in Studio; save the place |
| Publishing | Studio | **File > Publish to Roblox** |

Rojo only manages the folders in `default.project.json` (the scripts under ReplicatedStorage, ServerScriptService and StarterPlayerScripts, plus the Lighting technology). It never touches Workspace or ServerStorage, so your map and anything else you build in Studio stays in the place.

## Setup

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install` in this folder. It installs the tool versions pinned in `rokit.toml` (Rojo, StyLua, Selene, Lune).
2. Install the Rojo plugin in Roblox Studio: `rojo plugin install`.
3. Open your place in Studio, run `rojo serve` in this folder, and click **Connect** in the Rojo plugin. Code changes in `src/` now sync into Studio live.
4. Add a map (see below), save the place, and publish with **File > Publish to Roblox** when you're happy with it.

## Playtesting a match

1. With `rojo serve` running and Studio connected, open the **Test** tab.
2. Set the player count to **3** and click **Clients and Servers** (a group needs `Config.Queue.MinPlayers` players).
3. In each player window, walk up to the same group pad in the lobby and press **E** to join. Press E again to leave.
4. Once the pad has 3 players it counts down from 10 and the match starts in that pad's arena.
5. A match is 3 rounds. Each round one player seeks (nobody seeks twice until everyone has), the seeker sees black for 15 seconds, then hunts with the flashlight. Caught hiders wait in the lobby and come back for the next round.
6. After the last round everyone sees the final scores, then returns to the lobby and the pad opens again.

There are two pads, each with its own arena, so two groups can play at once (try 6 players). Scoring: the seeker gets 10 points per hider caught, and each hider still hidden when time runs out gets 10.

Test on a phone by picking a device in Studio's **Test > Device** emulator, and on a gamepad by plugging one in.

## Controls

| | Keyboard and mouse | Gamepad | Phone |
| --- | --- | --- | --- |
| Aim the flashlight (seeker) | Move the camera; the beam points at the middle of the screen | Right stick | Drag on the screen |
| Flashlight on/off (seeker) | F | X | The LIGHT button |
| Join or leave a group pad | E | The prompt's button | Tap the prompt |

## The arena map

The built-in arena is a small neighborhood (two houses, a garage, a playground, a street with parked cars, trees, hedges and fences), built from parts by `src/server/ArenaMap.luau`. The lobby is built by `src/server/World.luau`. The game turns off any SpawnLocation it didn't create, so a new Baseplate works as a starting place.

The game plays the Model named `ArenaMap` in **ServerStorage** in your place. Each pad gets its own copy. If there isn't one, or it has no spawn parts, the game warns in Output and uses the built-in map from `src/server/ArenaMap.luau`, so a fresh place still works.

To make or change the map:

1. Build it in Studio's Workspace so you can see it, or start from `assets/StarterArenaMap.rbxmx` (right-click **Workspace** > **Insert from File...**). That file is an export of the built-in neighborhood; `lune run scripts/export-map` rewrites it.
2. Keep it centred on the origin (0, 0, 0), with walls around the edge to keep players in, and under 400 studs wide so the copies for each pad don't overlap.
3. Add one part named `SeekerSpawn` and several named `HiderSpawn` where players should start. They are hidden when the game runs.
4. Group everything into a Model named `ArenaMap`, drag it into **ServerStorage**, and delete any copy left in Workspace.
5. Save the place. The map is stored in the place file, not in git.

## Sounds

Sound ids live in `Config.Sounds`. They currently point at sounds that ship with Roblox as placeholders; swap in anything from the Creator Store.

## Layout

| Folder | Lands in | What goes there |
| --- | --- | --- |
| `src/server` | ServerScriptService.Server | Game rules: queues, rounds, damage |
| `src/client` | StarterPlayerScripts.Client | Lighting, flashlight controls, sounds and effects, HUD |
| `src/shared` | ReplicatedStorage.Shared | Config, remote names, pure helpers |
| `assets` | not synced | `StarterArenaMap.rbxmx`, a map to insert into Studio as a starting point |
| `scripts` | not synced | `export-map`, which regenerates the starter map from the built-in map |
| `tests` | not synced | Unit tests for pure modules, run with Lune |

All tunable numbers (round length, damage, group size) are in `src/shared/Config.luau`.

## Checks

These are what CI runs on every pull request:

```sh
stylua --check src tests scripts   # formatting
selene src                 # lint
lune run tests/run         # unit tests
mkdir -p build && rojo build -o build/FlashlightTag.rbxl
```
