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

The arenas and lobby are built from plain parts by `src/server/World.luau`. The game turns off any SpawnLocation it didn't create, so a new Baseplate works as a starting place.

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
