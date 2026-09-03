/*
    Metro Exodus: Enhanced Edition - Load Remover
    ---------------------------------------------
    Removes loading time so LiveSplit's Game Time equals LRT (time without loads).

    Process : MetroExodus.exe
    Builds  : see vars.BUILDS below - one row per verified build

    NOTE: the Enhanced Edition uses the same process name as the base game but is a
    completely different build. The base game's load remover reads a hardcoded offset
    that is still a valid mapped address in EE, so pointing it at EE fails SILENTLY -
    it never errors, it just never pauses. That is why this script identifies the build
    by ModuleMemorySize and refuses to run on anything it was not verified against:
    refusing loudly is the only alternative to timing runs wrongly in silence.

    The loading flag was found by memory scan against two held states:
      gameplay (0) <-> post-load "press to continue" prompt (1)
    Verified 0 during gameplay, cutscenes, pause menu and main menu;
    1 during loading screens and while the continue prompt is held.

    A patch changes ModuleMemorySize whether or not the file version is bumped - the
    2026-09-03 patch grew the image by exactly one 4 KB page and left the version
    string at 2.0.0.1. It did not move this flag, so both builds share an offset. If a
    future patch does move it, the offset is per-build: add a state descriptor and a
    row to vars.BUILDS rather than editing the existing ones, so people who have not
    updated yet keep working. Re-finding the flag: docs/finding-the-offset.md

    STATUS: not fully runtime-tested. The flag is confirmed to read correctly on build
    52641792 (diagnostic log, 2026-09-03), but no full run has been timed with the
    timer actually running. Do not submit runs timed with this script until that is
    done and the moderators have signed off.
*/

state("MetroExodus", "EE_52637696")
{
    // loading flag: 1 = loading, 0 = in game
    byte loading : 0x1659040;
}

state("MetroExodus", "EE_52641792")
{
    byte loading : 0x1659040;
}

startup
{
    // ModuleMemorySize -> state descriptor version.
    // The process name is shared with the base game, so the module size is what tells
    // the builds apart. One row per build actually verified, newest last.
    vars.BUILDS = new Dictionary<int, string>
    {
        { 52637696, "EE_52637696" },  // 2.0.0.1, before the 2026-09-03 patch
        { 52641792, "EE_52641792" },  // 2.0.0.1, after  the 2026-09-03 patch (+0x1000)
    };

    vars.warned = false;

    // An unsupported build is reported to a file as well as a dialog: LiveSplit's
    // message box opens *behind* an exclusive-fullscreen game, where it is easy to
    // miss entirely and look exactly like the script doing nothing.
    vars.ReportPath = System.IO.Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory),
        "meee-unsupported-build.txt");

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
    int size = modules.First().ModuleMemorySize;

    if (!vars.BUILDS.ContainsKey(size))
    {
        if (!vars.warned)
        {
            vars.warned = true;

            var known = new List<string>();
            foreach (var key in vars.BUILDS.Keys)
                known.Add(key.ToString());

            string report =
                "Metro Exodus EE load remover - unsupported build\r\n" +
                "\r\n" +
                "Attached process reports ModuleMemorySize " + size + ".\r\n" +
                "Verified builds: " + string.Join(", ", known.ToArray()) + "\r\n" +
                "\r\n" +
                "Loads are NOT being removed. Do not submit runs timed with this " +
                "script until it has been updated for your build.\r\n" +
                "\r\n" +
                "The game was most likely patched. The file version is not a reliable " +
                "check - a patch can change the build without bumping it. Report this " +
                "number together with \"buildid\" from steamapps\\appmanifest_1449560.acf\r\n";

            try { System.IO.File.WriteAllText(vars.ReportPath, report); }
            catch (Exception) { }

            MessageBox.Show(
                report + "\r\nThis text was also saved to:\r\n" + vars.ReportPath,
                "LiveSplit | Metro Exodus EE - unsupported build",
                MessageBoxButtons.OK, MessageBoxIcon.Error);
        }

        throw new Exception("Unsupported build: ModuleMemorySize " + size);
    }

    version = (string)vars.BUILDS[size];
    vars.warned = false;
}

isLoading
{
    return current.loading == 1;
}
