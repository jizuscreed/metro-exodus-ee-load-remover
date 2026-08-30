# Metro Exodus: Enhanced Edition — Load Remover

A LiveSplit auto splitter script (ASL) that removes loading time for **Metro Exodus:
Enhanced Edition**, so LiveSplit's Game Time equals LRT (time without loads).

The Enhanced Edition had no load remover. Its leaderboard defaults to
`realtime_noloads`, but with no tooling, runs were retimed by hand in a video editor —
which is also why IL runs are required to start from chapter select.

> **Status:** verified against EE build 2.0.0.1 (Steam). Offsets confirmed stable across
> game restarts. Not yet runtime-tested across a full run in LiveSplit, and not yet
> submitted to the speedrun.com resources for the game.

## Why the base game's script does not work here

The base game has a load remover (by Corvex, on the
[Metro Exodus resources page](https://www.speedrun.com/metro_exodus/resources)). It is
a single hardcoded offset:

```csharp
state("MetroExodus", "Steam") { int Loader : 0x214312B; }
isLoading { return current.Loader == 1; }
```

Two problems when pointed at the Enhanced Edition:

1. **EE is a different build.** Separate Steam app (1449560), separate install,
   DX12-only rebuild of 4A Engine. The base game's offset means nothing in it.
2. **The failure is silent.** EE uses the same process name (`MetroExodus.exe`), the
   script's state descriptor has no build check, and `0x214312B` is still a *valid
   mapped address* inside EE's module. So it attaches, reads an unrelated byte, never
   errors — and the timer simply never pauses.

This script therefore gates on `ModuleMemorySize` and refuses to run on a build it was
not verified against, showing an error instead of quietly producing wrong times.

## Install

1. Download `MetroExodusEE.asl`.
2. In LiveSplit: `Layout → + → Control → Scriptable Auto Splitter`, point it at the file.
3. Answer **Yes** when it offers to switch to Game Time (or right-click the timer →
   `Compare Against → Game Time`).

Splits are manual — there is no auto-splitting yet (the base game's script has none
either). See [Possible future work](#possible-future-work).

## Settings

| Setting | Effect |
| --- | --- |
| `Debug: log when +3001CBB disagrees with the loading flag` | Diagnostics only, no effect on timing. Writes to the debug output (view with DebugView). Off by default. |

## How it works

| What | Value |
| --- | --- |
| Process | `MetroExodus.exe` |
| Build | Enhanced Edition, file version 2.0.0.1 (Steam) |
| `ModuleMemorySize` | `52637696` |
| Loading flag | `MetroExodus.exe+0x1659040` — `1` while loading, `0` in game |
| Engine-state byte | `MetroExodus.exe+0x3001CBB` — diagnostics only |

Both bytes are static globals inside the module image, so only the module base moves
between launches (ASLR); the offsets are constants of the build.

The loading flag was verified `0` during gameplay, cutscenes, the pause menu and the
main menu, and `1` during loading screens and while the post-load "press to continue"
prompt is held.

`+0x3001CBB` tracks the loading flag closely but is **not** equivalent — it also fires
on engine teardown when the game is closed, so it is most likely a broader
"engine busy / streaming" state of which loading is one case. It is deliberately not
OR'd into `isLoading`: doing so would remove intervals that are not loads.

## Timing note for moderators

The loading flag stays set until the player presses continue at the post-load prompt,
so **time spent sitting at that prompt is removed from LRT**. This matches how the flag
behaves natively and keeps loads fully excluded, but it does mean idling at the prompt
is not counted. Worth an explicit ruling before runs are accepted with this script.

## After a game update

A patch changes the build, which changes both `ModuleMemorySize` and the offsets. The
script will refuse to run and say so. To update it, re-find the flag — the full
procedure is in [docs/finding-the-offset.md](docs/finding-the-offset.md).

## Possible future work

- **Auto-splitting.** Metro 2033 Redux's ASL splits on a level-id global
  (`int Splitter`). If the equivalent is found in EE, chapter splits become possible —
  something the base game's script does not have.
- **Signature scanning** instead of hardcoded offsets, so the script survives patches
  (see [asl-help](https://github.com/ero-qt/asl-help)).
- **Base game support** in the same file, gated by `ModuleMemorySize`.

## Credits

- Base game load remover by **Corvex** — the reference for the flag's semantics.
- `Metro2033Redux.asl` by **Kuno Demetries** and **Chimpaneez**, and `metro2033.asl` by
  **Ekelbatzen**, for the 4A Engine state-global structure and the build-detection
  pattern via `ModuleMemorySize`.
