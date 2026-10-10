# Flashlight Tag

A Roblox game that mixes Hide and Seek with Tag. Each 3-minute round picks one seeker who is surrounded by darkness and armed with a flashlight; the hiders play in a dusk scene and lose health while the beam is on them.

The full plan, including the open gameplay decisions, is in the [build plan doc](https://claude.ai/code/artifact/ef3d5f77-5eb9-406b-8134-eec61f188c4f).

## Setup

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install` in this folder. It installs the tool versions pinned in `rokit.toml` (Rojo, StyLua, Selene, Lune).
2. Install the Rojo plugin in Roblox Studio: `rojo plugin install`.
3. Run `rojo serve`, open a new Baseplate in Studio, and click **Connect** in the Rojo plugin. Code changes in `src/` now sync into Studio live.

## Playtesting a round

1. With `rojo serve` running and Studio connected, open the **Test** tab.
2. Set the player count to **3** and click **Clients and Servers** (a round needs `Config.Queue.MinPlayers` players).
3. After a 10-second countdown one player becomes the seeker. They see a black screen for 15 seconds while the hiders scatter, then get the flashlight. Aim it with the camera.
4. A hider in the beam drains from 100 to 0 in 4 seconds and is sent back to the lobby. The round ends when every hider is caught or the 3 minutes run out.

The arena is built from plain parts by `src/server/World.luau`. The game turns off any SpawnLocation it didn't create, so a new Baseplate works as a starting place.

## Layout

| Folder | Lands in | What goes there |
| --- | --- | --- |
| `src/server` | ServerScriptService.Server | Game rules: queues, rounds, damage |
| `src/client` | StarterPlayerScripts.Client | Lighting, flashlight input, HUD |
| `src/shared` | ReplicatedStorage.Shared | Config, remote names, pure helpers |
| `tests` | not synced | Unit tests for pure modules, run with Lune |

All tunable numbers (round length, damage, group size) are in `src/shared/Config.luau`.

## Checks

These are what CI runs on every pull request:

```sh
stylua --check src tests   # formatting
selene src                 # lint
lune run tests/run         # unit tests
mkdir -p build && rojo build -o build/FlashlightTag.rbxl
```
