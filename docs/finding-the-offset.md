# Finding the loading flag again

Run this when a game patch breaks the script — the build changes, `ModuleMemorySize`
changes, and the offsets move. Nothing here is specific to build 2.0.0.1 except the
example numbers.

The target is a **single byte, a static global inside the module image**: `1` while
loading, `0` in game. All three known 4A Engine scripts (Metro 2033, Metro Redux,
Metro Exodus base game) use exactly this shape — no pointer chains.

## 0. Collect the build's constants

Start the game, then in **64-bit PowerShell as administrator**:

```powershell
$p = Get-Process MetroExodus
$m = $p.Modules[0]
$b = $m.BaseAddress.ToInt64()
"version   : {0}"   -f $m.FileVersionInfo.FileVersion
"size      : {0}"   -f $m.ModuleMemorySize     # goes into the script's build gate
"CE Start  : {0:X}" -f $b
"CE Stop   : {0:X}" -f ($b + $m.ModuleMemorySize)
```

If `$p.Modules` comes back null, PowerShell is 32-bit or not elevated. The same numbers
are available in Cheat Engine: `Memory View → View → Enumerate DLLs and Symbols`.

`CE Start` / `CE Stop` are valid only for the current launch — the base moves with ASLR
on every start. `size` and `version` are constants of the build.

## 1. Set up the scan

Cheat Engine 64-bit, as administrator, attached to `MetroExodus.exe`.

- Value Type: **`1 Byte`**
- `Memory Scan Options` → Start / Stop = the values from step 0
- `Writable` on, `Executable` off, `CopyOnWrite` off

Restricting the range to the module is what makes this tractable: it drops the heap
entirely, and turning off `Executable` drops the code section, which is most of the
image. It also guarantees anything found is static relative to the module base — a
global's RVA is fixed, only the base moves.

## 2. Use two *held* states

This is the part that matters. Do **not** try to catch a three-second loading screen.

| State | How to hold it | Flag |
| --- | --- | --- |
| A — in game | press continue, stand still | `0` |
| B — loading | quickload (F9), wait, **do not** press continue | `1` |

The flag stays set until the player dismisses the post-load prompt, so state B can be
held indefinitely. Both states are stable, so scanning is unhurried.

**Do not use the main menu as the second state.** It is tempting, but the flag is a
boolean *"loading in progress"*, not *"where am I"*. Standing in the menu the load has
already finished and the flag is back to `0` — identical to gameplay. A
`Changed value` filter at that moment eliminates the very byte you are looking for.

## 3. Alternate Exact value

Since the value is boolean and both states are held, this is far stronger than
`Changed`/`Unchanged`:

| # | State | Scan Type | Value |
| --- | --- | --- | --- |
| 1 | held at the continue prompt | `Exact value` | `1` — First Scan |
| 2 | in gameplay, standing still | `Exact value` | `0` — Next Scan |
| 3 | F9, held at the prompt | `Exact value` | `1` — Next Scan |
| 4 | in gameplay | `Exact value` | `0` — Next Scan |

Repeat 3–4 until a handful of addresses remain. If step 2 wipes everything, the
polarity is inverted — start over with `0` at the prompt.

Focus loss does not matter here: the game auto-pauses when minimized, but the loading
flag does not depend on window focus, so alt-tabbing to click is fine. A byte that
*did* depend on focus could not survive this scan anyway — it would read the same in
both states.

## 4. Eliminate candidates

Put the survivors in the address list (`Add to the addresslist`), rename them to their
offsets so they are distinguishable, and save a `.CT` copy before pruning. The `.CT`
stores addresses as `module+offset`, so it re-resolves itself after a restart.

Watch the values — ideally with Cheat Engine on a second monitor, since the list keeps
updating while the game has focus.

| Observation | Verdict |
| --- | --- |
| flickers while simply walking around | streaming or similar — **out** |
| stays `1` during gameplay | **out** |
| reads `1` during a cutscene | a "simulation halted" flag, not loading — **out** (cutscenes count as game time) |
| reads `1` in the pause menu or main menu | **out** |
| takes values other than two | a state enum, not a boolean — keep aside, map its values |
| reacts to a load with a visible delay | downstream subsystem — prefer the instant one, and check its *falling* edge |

Two structural hints from the 2.0.0.1 hunt:

- Addresses spaced on a regular stride (there: `0x88`) are one field across an array of
  structs, not a global. They died off as the search narrowed.
- The real flag was a lone, otherwise-unremarkable byte — as was the base game's
  `0x214312B`.

Check the **falling** edge, not just the rising one. A flag that clears late keeps the
timer paused into gameplay and removes time it should not.

## 5. Update the script

Put the new offset in the `state` block and the new `ModuleMemorySize` in
`vars.SUPPORTED_SIZE`. Keep the gate strict: it is the only thing standing between a
patched build and silently wrong times.
