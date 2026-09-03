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
      * Writes a log to  <Desktop>\meee-debug.log , truncated each time the script is
        loaded. The same lines also go to the Win32 debug output, so DebugView still
        works if you prefer it - but nothing needs to be installed to read the file.

    Reading the log:

      "startup" only, no "init"  -> the file parses but LiveSplit never attached to the
                                    process. The problem is attachment, not the offset.
      "init" present             -> attached. The line reports the module base and
                                    ModuleMemorySize actually seen, compare with 52637696.
      transition lines           -> what the loading flag does in real time, alongside
                                    the timer phase, timing method and IsGameTimePaused.

    If the log file never appears at all, the script never ran: the path in the
    Scriptable Auto Splitter component is wrong or the layout was not saved.
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

    vars.LogPath = System.IO.Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory),
        "meee-debug.log");

    // start a fresh file on every script load, so a stale log cannot be mistaken
    // for the current run
    try { System.IO.File.WriteAllText(vars.LogPath, ""); } catch (Exception) { }

    vars.Log = (Action<string>)(msg =>
    {
        // the debug output costs nothing and keeps DebugView usable as a fallback
        print("[MEEE-DEBUG] " + msg);

        // a locked or unwritable file must not take the script down mid-run
        try
        {
            System.IO.File.AppendAllText(vars.LogPath,
                DateTime.Now.ToString("HH:mm:ss.fff") + "  " + msg + Environment.NewLine);
        }
        catch (Exception) { }
    });

    vars.Log("startup: script file loaded and parsed");
    vars.Log("startup: logging to " + vars.LogPath);
}

init
{
    var m = modules.First();

    vars.Log("init: ATTACHED to pid " + game.Id + " ('" + game.ProcessName + "')");
    vars.Log("init: main module '" + m.ModuleName +
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
        vars.Log("update: first tick, loading=" + current.loading +
                 " streaming=" + current.streaming);
    }

    if (old.loading != current.loading)
    {
        vars.Log("loading flag " + old.loading + " -> " + current.loading +
                 "  phase=" + timer.CurrentPhase +
                 " method=" + timer.CurrentTimingMethod +
                 " gameTimePaused=" + timer.IsGameTimePaused);
    }

    if (old.streaming != current.streaming)
    {
        vars.Log("streaming byte " + old.streaming + " -> " + current.streaming);
    }

    // roughly every 5 seconds at the default refresh rate
    if (vars.ticks % 300 == 0)
    {
        vars.Log("heartbeat " + vars.ticks +
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
