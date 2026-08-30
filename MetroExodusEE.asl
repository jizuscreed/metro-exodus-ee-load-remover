/*
    Metro Exodus: Enhanced Edition - Load Remover
    ---------------------------------------------
    Removes loading time so LiveSplit's Game Time equals LRT (time without loads).

    Supported build : Enhanced Edition, file version 2.0.0.1 (Steam)
                      ModuleMemorySize 52637696
    Process         : MetroExodus.exe

    NOTE: the Enhanced Edition uses the same process name as the base game but is a
    completely different build. The base game's load remover reads a hardcoded offset
    that is still a valid mapped address in EE, so pointing it at EE fails SILENTLY -
    it never errors, it just never pauses. This script gates on ModuleMemorySize and
    refuses to run on anything it was not verified against.

    The loading flag was found by memory scan against two held states:
      gameplay (0) <-> post-load "press to continue" prompt (1)
    Verified 0 during gameplay, cutscenes, pause menu and main menu;
    1 during loading screens and while the continue prompt is held.

    STATUS: not runtime-tested. The flag's behaviour was confirmed by watching memory in
    Cheat Engine, not by timing a full run in LiveSplit. Do not submit runs timed with
    this script until it has been through a real run and the moderators have signed off.

    A second byte at +0x3001CBB tracks it closely but is NOT equivalent: it also fires
    on engine teardown when the game is closed, so it is most likely a broader
    "engine busy / streaming" state of which loading is one case. It is read for
    diagnostics only and never drives the timer - ORing the two would remove
    intervals that are not loads.
*/

state("MetroExodus", "EE_2001")
{
    // loading flag: 1 = loading, 0 = in game
    byte loading : 0x1659040;

    // broader engine-state byte, diagnostics only - see note above
    byte streaming : 0x3001CBB;
}

startup
{
    vars.SUPPORTED_SIZE = 52637696; // EE 2.0.0.1
    vars.warned = false;

    settings.Add("logDiag", false, "Debug: log when +3001CBB disagrees with the loading flag");
    settings.SetToolTip("logDiag",
        "Diagnostics only, has no effect on timing. Writes to the debug output\n" +
        "(view it with DebugView). +3001CBB is a broader engine-state byte and is\n" +
        "expected to disagree sometimes - the log is there to show where.");

    if (timer.CurrentTimingMethod == TimingMethod.RealTime)
    {
        var choice = MessageBox.Show(
            "Metro Exodus EE is timed with Time without Loads (Game Time).\n" +
            "LiveSplit is currently showing Real Time (RTA).\n\n" +
            "Switch the timing method to Game Time?",
            "LiveSplit | Metro Exodus EE",
            MessageBoxButtons.YesNo, MessageBoxIcon.Question);

        if (choice == DialogResult.Yes)
            timer.CurrentTimingMethod = TimingMethod.GameTime;
    }
}

init
{
    var size = modules.First().ModuleMemorySize;

    if (size != vars.SUPPORTED_SIZE)
    {
        if (!vars.warned)
        {
            vars.warned = true;
            MessageBox.Show(
                "This script was built for Metro Exodus: Enhanced Edition 2.0.0.1.\n\n" +
                "Attached process reports ModuleMemorySize " + size + ", expected " +
                vars.SUPPORTED_SIZE + ".\n\n" +
                "Loads will NOT be removed. Do not submit runs timed with this script " +
                "until it has been updated for your build.",
                "LiveSplit | Metro Exodus EE - unsupported build",
                MessageBoxButtons.OK, MessageBoxIcon.Error);
        }

        throw new Exception("Unsupported build: ModuleMemorySize " + size);
    }

    version = "EE_2001";
    vars.warned = false;
}

update
{
    if (settings["logDiag"] && current.loading != current.streaming)
    {
        print("[MetroExodusEE] +1659040=" + current.loading +
              " +3001CBB=" + current.streaming);
    }
}

isLoading
{
    return current.loading == 1;
}
