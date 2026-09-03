/*
    Metro Exodus: Enhanced Edition - DIAGNOSTIC BUILD
    -------------------------------------------------
    This is NOT the load remover. Do not time runs with it.

    It answers what the normal script cannot, because the normal script is silent on
    success: does it attach, what build does it see, what does the flag do, and does
    LiveSplit actually act on it.

    Differences from MetroExodusEE.asl, all deliberate:

      * No build gate. It reports ModuleMemorySize instead of refusing to run, so an
        unknown build still produces diagnostics rather than a single error box.
      * No version string on the state descriptor, so state selection cannot be the
        thing that fails. If this build works and the real one does not, that is the
        answer by itself.
      * Writes a log to  <Desktop>\meee-debug.log , truncated each time the script is
        loaded. The same lines also go to the Win32 debug output, so DebugView still
        works if you prefer it - but nothing needs to be installed to read the file.

    Reading the log:

      "startup" only, no "init"  -> the file parses but LiveSplit never attached to the
                                    process. The problem is attachment, not the offset.
      "init" present             -> attached; the line reports the module base and the
                                    ModuleMemorySize actually seen, and whether it is a
                                    build the real script knows about.
      transition lines           -> what the loading flag does in real time.

    Every line carries phase, timing method, gameTimePaused and both clocks. That last
    part is the point when testing end to end: with the timer RUNNING, a load should
    show gameTimePaused=True and gt= frozen while rta= keeps climbing. With the timer
    stopped (phase=NotRunning) LiveSplit does not apply isLoading at all, so a log full
    of gameTimePaused=False proves nothing about timing - only that reading works.

    If the log file never appears at all, the script never ran: the path in the
    Scriptable Auto Splitter component is wrong or the layout was not saved.
*/

state("MetroExodus")
{
    byte loading : 0x1659040;
}

startup
{
    vars.ticks = 0;
    vars.announced = false;
    vars.lastPhase = "";

    // kept in sync with vars.BUILDS in MetroExodusEE.asl
    vars.KNOWN = new List<int> { 52637696, 52641792 };

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
    int size = m.ModuleMemorySize;

    vars.Log("init: ATTACHED to pid " + game.Id + " ('" + game.ProcessName + "')");
    vars.Log("init: main module '" + m.ModuleName +
             "' base 0x" + m.BaseAddress.ToString("X") +
             " ModuleMemorySize " + size +
             (vars.KNOWN.Contains(size) ? " (known build)" : " (UNKNOWN build)"));

    vars.ticks = 0;
    vars.announced = false;
    vars.lastPhase = "";
}

update
{
    vars.ticks++;

    var t = timer.CurrentTime;
    string clocks =
        " rta=" + (t.RealTime.HasValue ? t.RealTime.Value.ToString(@"hh\:mm\:ss\.ff") : "-") +
        " gt="  + (t.GameTime.HasValue ? t.GameTime.Value.ToString(@"hh\:mm\:ss\.ff") : "-");

    string state = " phase=" + timer.CurrentPhase +
                   " method=" + timer.CurrentTimingMethod +
                   " gameTimePaused=" + timer.IsGameTimePaused +
                   clocks;

    if (!vars.announced)
    {
        vars.announced = true;
        vars.Log("update: first tick, loading=" + current.loading + state);
    }

    if (vars.lastPhase != timer.CurrentPhase.ToString())
    {
        vars.lastPhase = timer.CurrentPhase.ToString();
        vars.Log("timer phase now " + timer.CurrentPhase + ", loading=" + current.loading + state);
    }

    if (old.loading != current.loading)
    {
        vars.Log("loading flag " + old.loading + " -> " + current.loading + state);
    }

    // roughly every 5 seconds at the default refresh rate
    if (vars.ticks % 300 == 0)
    {
        vars.Log("heartbeat " + vars.ticks + " loading=" + current.loading + state);
    }
}

isLoading
{
    return current.loading == 1;
}

exit
{
    // matches MetroExodusEE.asl - see the comment there
    timer.IsGameTimePaused = false;
    vars.Log("exit: process gone, released IsGameTimePaused");
}
