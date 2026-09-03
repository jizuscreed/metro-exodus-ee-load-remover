/*
    Metro Exodus: Enhanced Edition - DIAGNOSTIC BUILD
    -------------------------------------------------
    This is NOT the load remover. Do not time runs with it.

    It exists to answer one question that the normal script cannot answer, because the
    normal script is silent on success: does it actually attach to the game process and
    what does it read once attached?

    Differences from MetroExodusEE.asl, all deliberate:

      * No ModuleMemorySize gate. It reports the size instead of refusing to run, so a
        mismatched build still produces diagnostics rather than a single error box.
      * No version string on the state descriptor, so state selection cannot be the
        thing that fails. If this build works and the real one does not, that is the
        answer by itself.
      * Prints to the Win32 debug output. Read it with DebugView (Sysinternals),
        Capture -> Capture Win32 enabled.

    Reading the log:

      "startup" only, no "init"  -> the file parses but LiveSplit never attached to the
                                    process. The problem is attachment, not the offset.
      "init" present             -> attached. The line reports the module base and
                                    ModuleMemorySize actually seen, compare with 52637696.
      transition lines           -> what the loading flag does in real time, alongside
                                    the timer phase, timing method and IsGameTimePaused.
*/

state("MetroExodus")
{
    byte loading   : 0x1659040;
    byte streaming : 0x3001CBB;
}

startup
{
    vars.ticks = 0;
    vars.announced = false;

    print("[MEEE-DEBUG] startup: script file loaded and parsed");
}

init
{
    var m = modules.First();

    print("[MEEE-DEBUG] init: ATTACHED to pid " + game.Id + " ('" + game.ProcessName + "')");
    print("[MEEE-DEBUG] init: main module '" + m.ModuleName +
          "' base 0x" + m.BaseAddress.ToString("X") +
          " ModuleMemorySize " + m.ModuleMemorySize + " (expected 52637696)");

    vars.ticks = 0;
    vars.announced = false;
}

update
{
    vars.ticks++;

    if (!vars.announced)
    {
        vars.announced = true;
        print("[MEEE-DEBUG] update: first tick, loading=" + current.loading +
              " streaming=" + current.streaming);
    }

    if (old.loading != current.loading)
    {
        print("[MEEE-DEBUG] loading flag " + old.loading + " -> " + current.loading +
              "  phase=" + timer.CurrentPhase +
              " method=" + timer.CurrentTimingMethod +
              " gameTimePaused=" + timer.IsGameTimePaused);
    }

    if (old.streaming != current.streaming)
    {
        print("[MEEE-DEBUG] streaming byte " + old.streaming + " -> " + current.streaming);
    }

    // roughly every 5 seconds at the default refresh rate
    if (vars.ticks % 300 == 0)
    {
        print("[MEEE-DEBUG] heartbeat " + vars.ticks +
              " loading=" + current.loading +
              " streaming=" + current.streaming +
              " phase=" + timer.CurrentPhase +
              " method=" + timer.CurrentTimingMethod +
              " gameTimePaused=" + timer.IsGameTimePaused);
    }
}

isLoading
{
    return current.loading == 1;
}
