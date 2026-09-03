# Metro Exodus: Enhanced Edition — Load Remover

A LiveSplit auto splitter script (ASL) that removes loading time for **Metro Exodus:
Enhanced Edition**, so LiveSplit's Game Time equals LRT (time without loads).

The Enhanced Edition had no load remover. Its leaderboard defaults to
`realtime_noloads`, but with no tooling, runs were retimed by hand in a video editor —
which is also why IL runs are required to start from chapter select.

> **Status: not fully runtime-tested.** The loading flag is confirmed to read correctly
> on build `52641792` (diagnostic log, 2026-09-03), and the offsets are stable across
> game restarts. But no full run has been timed with the timer actually running, and the
> script is not on the game's speedrun.com resources page — do not submit runs timed
> with it until that is done and the moderators have signed off.

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

This script therefore identifies the build by `ModuleMemorySize` and refuses to run on
one it was not verified against. Refusing loudly is the only alternative to timing runs
wrongly in silence.

## Install

1. Download `MetroExodusEE.asl`.
2. In LiveSplit: `Layout → + → Control → Scriptable Auto Splitter`, point it at the file.
3. **Save the layout** — otherwise the script path is lost on restart.
4. Answer **Yes** when it offers to switch to Game Time (or right-click the timer →
   `Compare Against → Game Time`).

Splits are manual — there is no auto-splitting yet (the base game's script has none
either). See [Possible future work](#possible-future-work).

## How it works

| What | Value |
| --- | --- |
| Process | `MetroExodus.exe` |
| Loading flag | `MetroExodus.exe+0x1659040` — `1` while loading, `0` in game |

The flag is a static global inside the module image, so only the module base moves
between launches (ASLR); the offset is a constant of the build.

It was verified `0` during gameplay, cutscenes, the pause menu and the main menu, and
`1` during loading screens and while the post-load "press to continue" prompt is held.

### Supported builds

The build is identified by `ModuleMemorySize`, and each verified build gets a row in
`vars.BUILDS`. The offset is stored per build, so a patch that moves the flag does not
break the script for people who have not updated yet.

| `ModuleMemorySize` | Offset | Notes |
| --- | --- | --- |
| `52637696` | `0x1659040` | file version 2.0.0.1, before the 2026-09-03 patch |
| `52641792` | `0x1659040` | file version 2.0.0.1, after the 2026-09-03 patch (`+0x1000`) |

**The file version is not a reliable build identifier.** The 2026-09-03 patch grew the
image by exactly one 4 KB page and left the version string at `2.0.0.1`. Use
`ModuleMemorySize`, and record Steam's `buildid` (in
`steamapps\appmanifest_1449560.acf`, alongside `LastUpdated`) when reporting a build.

## Timing note for moderators

The loading flag stays set until the player presses continue at the post-load prompt,
so **time spent sitting at that prompt is removed from LRT**. This matches how the flag
behaves natively and keeps loads fully excluded, but it does mean idling at the prompt
is not counted. Worth an explicit ruling before runs are accepted with this script.

## After a game update

A patch changes `ModuleMemorySize`, so the script will refuse to run and say so — both
in a dialog and in `meee-unsupported-build.txt` on your desktop.

A changed size does **not** prove the flag moved; it only means the build is unverified.
Check first, it is usually cheaper than a full re-scan:

1. Attach Cheat Engine to `MetroExodus.exe`, add `MetroExodus.exe+1659040` as a `Byte`,
   and watch it across a loading screen — or run the diagnostic script below, which
   reports the same thing plus the new size.
2. **Flag still flips `0 → 1 → 0`** → add a row to the table above and a matching
   `state(...)` descriptor. One-line fix.
3. **It does not** → the patch moved the global; re-find it with the full procedure in
   [docs/finding-the-offset.md](docs/finding-the-offset.md).

## Troubleshooting

**Loads are not being removed, and nothing seems wrong.** Check these in order:

- **Are you looking at Game Time?** `isLoading` pauses Game Time, never RTA. Right-click
  → `Compare Against → Game Time`, and check the `Timer` component's own `Timing Method`
  is `Current Timing Method` rather than pinned to `Real Time`.
- **Did an error dialog open behind the game?** LiveSplit's message box opens *behind*
  an exclusive-fullscreen game and is easy to miss entirely — it looks exactly like the
  script doing nothing. Alt-Tab, or look for `meee-unsupported-build.txt` on your desktop.
- **Is the script actually loaded?** `Edit Layout → Layout Settings → Scriptable Auto
  Splitter` should show the full path. If you never saved the layout, it is empty.
- **Only one auto splitter component?** Two of them fight over the timer.

**Still stuck:** run `debug/MetroExodusEE.debug.asl` instead. It has no build gate and
writes `meee-debug.log` to your desktop, recording whether it attached, the build it
saw, every transition of the loading flag, and what LiveSplit did about it. Note that
with the timer stopped LiveSplit does not apply `isLoading` at all, so start the timer
before drawing conclusions about timing. Do not time runs with the diagnostic build.

Unrelated but adjacent: if LiveSplit's hotkeys only work while LiveSplit itself is
focused, enable `Settings → Hotkeys → Global Hotkeys`.

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
