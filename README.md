# Flashlight Tag

A Roblox game that mixes Hide and Seek with Tag. Each 3-minute round picks one seeker who is surrounded by darkness and armed with a flashlight; the hiders play in a dusk scene and lose health while the beam is on them.

The full plan, including the open gameplay decisions, is in the [build plan doc](https://claude.ai/code/artifact/ef3d5f77-5eb9-406b-8134-eec61f188c4f).

## Setup

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install` in this folder. It installs the tool versions pinned in `rokit.toml` (Rojo, StyLua, Selene, Lune).
2. Install the Rojo plugin in Roblox Studio: `rojo plugin install`.
3. Run `rojo serve`, open a new Baseplate in Studio, and click **Connect** in the Rojo plugin. Code changes in `src/` now sync into Studio live.

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

The map the game plays is `assets/ArenaMap.rbxmx`, which Rojo syncs into **ServerStorage** as `ArenaMap`. Each pad gets its own copy. It starts as an export of the built-in neighborhood, so it's ready to edit in Studio.

To change the map:

1. With `rojo serve` connected, open **ServerStorage > ArenaMap** in Studio and edit it, or replace it with a map of your own.
2. Keep it centred on the origin (0, 0, 0), with walls around the edge to keep players in, and under 400 studs wide so the copies for each pad don't overlap.
3. Keep one part named `SeekerSpawn` and several named `HiderSpawn` where players should start (the red and blue pads). They are hidden when the game runs.
4. Right-click **ArenaMap** > **Save to File...**, choose the XML format (`.rbxmx`), and overwrite `assets/ArenaMap.rbxmx` in this repo. Rojo doesn't copy Studio edits back to files, so this step is what saves them.
5. Commit the file.

If the file is missing or has no spawn parts, the game warns in Output and uses the built-in map from `src/server/ArenaMap.luau`. To start over from that built-in map, run `lune run scripts/export-map`, which overwrites `assets/ArenaMap.rbxmx`.

## Sounds

Sound ids live in `Config.Sounds`. They currently point at sounds that ship with Roblox as placeholders; swap in anything from the Creator Store.

## Layout

| Folder | Lands in | What goes there |
| --- | --- | --- |
| `src/server` | ServerScriptService.Server | Game rules: queues, rounds, damage |
| `src/client` | StarterPlayerScripts.Client | Lighting, flashlight controls, sounds and effects, HUD |
| `src/shared` | ReplicatedStorage.Shared | Config, remote names, pure helpers |
| `assets` | ServerStorage | The arena map, `ArenaMap.rbxmx` |
| `scripts` | not synced | `export-map`, which regenerates the map file from the built-in map |
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
