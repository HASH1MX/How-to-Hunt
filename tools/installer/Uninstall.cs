// How to Hunt uninstaller (Uninstall.exe in the game folder, also run from Windows'
// "Installed apps"). Removes exactly the files Setup put down (listed in install.log),
// the shortcuts and the Windows entry. Saved worlds and settings live in the player's
// AppData folder and are NOT touched.
//
// It can't delete itself while running, so it first copies itself to the temp folder and
// runs from there (/run "<game folder>"). /S = silent.

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Windows.Forms;

namespace HowToHunt
{
    static class UninstallProgram
    {
        [STAThread]
        static int Main(string[] args)
        {
            bool silent = false;
            string folder = null;
            for (int i = 0; i < args.Length; i++)
            {
                if (args[i].Equals("/S", StringComparison.OrdinalIgnoreCase))
                    silent = true;
                else if (args[i].Equals("/run", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length)
                    folder = args[++i];
            }
            string self = Assembly.GetExecutingAssembly().Location;
            if (folder == null)
            {
                // Step 1: hand over to a copy in the temp folder.
                string copy = Path.Combine(Path.GetTempPath(), "HowToHunt-Uninstall.exe");
                File.Copy(self, copy, true);
                ProcessStartInfo start = new ProcessStartInfo(copy, "/run \"" + Path.GetDirectoryName(self) + "\"" + (silent ? " /S" : ""));
                start.UseShellExecute = false;
                Process.Start(start);
                return 0;
            }
            if (!silent)
                Look.Init();
            int result = Run(folder, silent);
            ScheduleDelete(self);
            return result;
        }

        static int Run(string folder, bool silent)
        {
            if (!silent && !Look.Ask(null, "Uninstall " + App.Name,
                    "Remove " + App.Name + " from this computer?\n\nYour saved worlds and settings are kept, so they'll still be there if you install it again.",
                    "Uninstall", "Cancel"))
                return 1;
            while (App.GameIsRunning())
            {
                if (silent || !Look.Ask(null, "Close the game", App.Name + " is running. Close the game, then press Try again.", "Try again", "Cancel"))
                    return 1;
            }
            string manifest = Path.Combine(folder, App.ManifestFile);
            List<string> files = new List<string>();
            List<string> shortcuts = new List<string>();
            if (File.Exists(manifest))
            {
                foreach (string line in File.ReadAllLines(manifest))
                {
                    int bar = line.IndexOf('|');
                    if (bar < 0)
                        continue;
                    string kind = line.Substring(0, bar);
                    string value = line.Substring(bar + 1);
                    if (kind == "file")
                        files.Add(value);
                    else if (kind == "shortcut")
                        shortcuts.Add(value);
                }
            }
            else
            {
                // No list (very old install): only remove the files we know the game ships with.
                files.AddRange(new string[] { App.GameExe, "libgodotsteam.windows.template_release.x86_64.dll",
                    "steam_api64.dll", "steam_appid.txt", "HOW_TO_PLAY.txt", App.UninstallerExe });
                shortcuts.Add(App.DesktopShortcut);
                shortcuts.Add(App.StartMenuShortcut);
            }
            string root = Path.GetFullPath(folder);
            List<string> failed = new List<string>();
            foreach (string file in files)
            {
                string path = Path.GetFullPath(Path.Combine(root, file));
                if (!path.StartsWith(root, StringComparison.OrdinalIgnoreCase))
                    continue;
                if (!TryDelete(path))
                    failed.Add(file);
                // Remove folders the game made, once they are empty.
                string dir = Path.GetDirectoryName(path);
                while (dir != null && dir.Length > root.Length && Directory.Exists(dir) && Directory.GetFileSystemEntries(dir).Length == 0)
                {
                    Directory.Delete(dir);
                    dir = Path.GetDirectoryName(dir);
                }
            }
            foreach (string link in shortcuts)
                TryDelete(link);
            if (Directory.Exists(root) && Directory.GetFileSystemEntries(root).Length == 0)
            {
                try { Directory.Delete(root); } catch (Exception) { }
            }
            App.Unregister();
            if (!silent)
            {
                string message = failed.Count == 0
                    ? App.Name + " has been removed. Thanks for playing!"
                    : App.Name + " has been removed, but a few files couldn't be deleted:\n" + string.Join("\n", failed.ToArray());
                Look.Ask(null, "Uninstall " + App.Name, message, "OK", null);
            }
            return failed.Count == 0 ? 0 : 2;
        }

        static bool TryDelete(string path)
        {
            for (int attempt = 0; attempt < 10; attempt++)
            {
                try
                {
                    if (File.Exists(path))
                        File.Delete(path);
                    return true;
                }
                catch (Exception)
                {
                    System.Threading.Thread.Sleep(300); // The old Uninstall.exe may still be closing.
                }
            }
            return false;
        }

        // The temp copy removes itself a moment after it closes.
        static void ScheduleDelete(string self)
        {
            ProcessStartInfo cleanup = new ProcessStartInfo("cmd.exe", "/c ping -n 3 127.0.0.1 > nul & del /f /q \"" + self + "\"");
            cleanup.WindowStyle = ProcessWindowStyle.Hidden;
            cleanup.CreateNoWindow = true;
            cleanup.UseShellExecute = false;
            try { Process.Start(cleanup); } catch (Exception) { }
        }
    }
}
