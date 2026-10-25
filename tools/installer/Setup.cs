// How to Hunt setup: installs the game into the player's own folder (no admin needed),
// adds desktop and Start menu shortcuts, an Uninstall.exe and an entry in Windows'
// "Installed apps" list. The game files travel inside this exe as game.zip.
//
// Command line (for testing): /S = silent, /NOSHORTCUTS = no shortcuts,
// /D=<folder> = install folder (must come last).

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.IO;
using System.IO.Compression;
using System.Threading;
using System.Windows.Forms;

namespace HowToHunt
{
    class SetupWindow : Form
    {
        Image banner;
        TextBox folderBox;
        GameButton browse, install, cancel;
        TickBox desktop, startMenu, playNow;
        Label folderTitle, note, status, detail;
        ProgressStrip progress;
        bool busy, done;

        public SetupWindow()
        {
            Form template = Look.MakeWindow(App.Name + " Setup", 600, 470);
            Text = template.Text;
            Icon = template.Icon;
            BackColor = Look.Back;
            ForeColor = Look.Text;
            FormBorderStyle = FormBorderStyle.FixedSingle;
            MaximizeBox = false;
            StartPosition = FormStartPosition.CenterScreen;
            AutoScaleMode = AutoScaleMode.None;
            ClientSize = template.ClientSize;
            template.Dispose();
            DoubleBuffered = true;
            using (Stream s = App.Resource("banner.png"))
                if (s != null)
                    banner = Image.FromStream(s);

            folderTitle = Look.MakeLabel("Install to", 11f, Look.Dim);
            folderTitle.SetBounds(Look.S(24), Look.S(216), Look.S(300), Look.S(24));
            Controls.Add(folderTitle);

            folderBox = new TextBox();
            folderBox.Text = App.DefaultFolder;
            folderBox.Font = new Font("Segoe UI", 10.5f);
            folderBox.BackColor = Look.Panel;
            folderBox.ForeColor = Look.Text;
            folderBox.BorderStyle = BorderStyle.FixedSingle;
            folderBox.SetBounds(Look.S(24), Look.S(244), Look.S(438), Look.S(30));
            Controls.Add(folderBox);

            browse = new GameButton("Browse...", false);
            browse.SetBounds(Look.S(470), Look.S(239), Look.S(106), Look.S(36));
            browse.Click += delegate { Browse(); };
            Controls.Add(browse);

            desktop = new TickBox("Put a shortcut on the desktop", true);
            desktop.SetBounds(Look.S(24), Look.S(288), Look.S(400), Look.S(28));
            Controls.Add(desktop);
            startMenu = new TickBox("Add to the Start menu", true);
            startMenu.SetBounds(Look.S(24), Look.S(320), Look.S(400), Look.S(28));
            Controls.Add(startMenu);

            note = Look.MakeLabel("Needs about 120 MB. Your saved worlds and settings are kept separately and are never removed.", 10f, Look.Dim);
            note.SetBounds(Look.S(24), Look.S(362), Look.S(552), Look.S(40));
            Controls.Add(note);

            status = Look.MakeLabel("", 17f, Look.Title);
            status.SetBounds(Look.S(24), Look.S(226), Look.S(552), Look.S(40));
            status.Visible = false;
            Controls.Add(status);
            detail = Look.MakeLabel("", 11f, Look.Dim);
            detail.SetBounds(Look.S(24), Look.S(268), Look.S(552), Look.S(48));
            detail.Visible = false;
            Controls.Add(detail);
            progress = new ProgressStrip();
            progress.SetBounds(Look.S(24), Look.S(322), Look.S(552), Look.S(16));
            progress.Visible = false;
            Controls.Add(progress);
            playNow = new TickBox("Play How to Hunt now", true);
            playNow.SetBounds(Look.S(24), Look.S(330), Look.S(400), Look.S(28));
            playNow.Visible = false;
            Controls.Add(playNow);

            cancel = new GameButton("Cancel", false);
            cancel.SetBounds(Look.S(356), Look.S(414), Look.S(104), Look.S(40));
            cancel.Click += delegate { Close(); };
            Controls.Add(cancel);
            install = new GameButton("Install", true);
            install.SetBounds(Look.S(468), Look.S(414), Look.S(108), Look.S(40));
            install.Click += delegate { OnInstallClicked(); };
            Controls.Add(install);
            AcceptButton = null;
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            Rectangle top = new Rectangle(0, 0, ClientSize.Width, Look.S(200));
            if (banner != null)
                g.DrawImage(banner, top);
            // Fade the picture into the dark window, then the title on top.
            using (LinearGradientBrush fade = new LinearGradientBrush(new Rectangle(0, Look.S(80), top.Width, Look.S(121)),
                    Color.FromArgb(0, Look.Back), Look.Back, LinearGradientMode.Vertical))
                g.FillRectangle(fade, 0, Look.S(80), top.Width, Look.S(121));
            using (Font title = Look.Font(34f))
            using (Font small = Look.Font(11.5f))
            {
                DrawShadowed(g, App.Name, title, Look.Title, Look.S(22), Look.S(112));
                DrawShadowed(g, "Setup  -  version " + App.Version, small, Look.Dim, Look.S(26), Look.S(170));
            }
            base.OnPaint(e);
        }

        static void DrawShadowed(Graphics g, string text, Font font, Color color, float x, float y)
        {
            using (SolidBrush shadow = new SolidBrush(Color.FromArgb(150, 0, 0, 0)))
                g.DrawString(text, font, shadow, x + Look.S(2), y + Look.S(2));
            using (SolidBrush brush = new SolidBrush(color))
                g.DrawString(text, font, brush, x, y);
        }

        protected override void OnShown(EventArgs e)
        {
            base.OnShown(e);
            folderBox.SelectionStart = folderBox.Text.Length;
            folderBox.SelectionLength = 0;
            ActiveControl = install;
        }

        protected override void OnFormClosing(FormClosingEventArgs e)
        {
            if (busy)
                e.Cancel = true; // Don't stop half-way through copying files.
            base.OnFormClosing(e);
        }

        void Browse()
        {
            using (FolderBrowserDialog dialog = new FolderBrowserDialog())
            {
                dialog.Description = "Choose where to install " + App.Name;
                dialog.SelectedPath = Path.GetDirectoryName(folderBox.Text.TrimEnd('\\'));
                if (dialog.ShowDialog(this) == DialogResult.OK)
                {
                    string chosen = dialog.SelectedPath;
                    // Always install into its own "How to Hunt" folder.
                    if (!string.Equals(Path.GetFileName(chosen.TrimEnd('\\')), App.Name, StringComparison.OrdinalIgnoreCase))
                        chosen = Path.Combine(chosen, App.Name);
                    folderBox.Text = chosen;
                }
            }
        }

        void OnInstallClicked()
        {
            if (done)
            {
                if (playNow.Ticked)
                    Installer.Launch(folderBox.Text);
                Close();
                return;
            }
            string folder = folderBox.Text.Trim();
            if (folder == "" || !Path.IsPathRooted(folder))
            {
                Look.Ask(this, "Install folder", "Please choose a full folder path, for example\n" + App.DefaultFolder, "OK", null);
                return;
            }
            while (App.GameIsRunning())
            {
                if (!Look.Ask(this, "Close the game", App.Name + " is running. Close the game, then press Try again.", "Try again", "Cancel"))
                    return;
            }
            busy = true;
            folderTitle.Visible = folderBox.Visible = browse.Visible = desktop.Visible = startMenu.Visible = note.Visible = false;
            status.Text = "Installing...";
            detail.Text = "Unpacking the island, the animals and Captain Gus.";
            status.Visible = detail.Visible = progress.Visible = true;
            install.Enabled = false;
            cancel.Visible = false;
            bool wantDesktop = desktop.Ticked;
            bool wantStart = startMenu.Ticked;
            Thread worker = new Thread(delegate ()
            {
                string error = null;
                try
                {
                    Installer.Run(folder, wantDesktop, wantStart, delegate (float p)
                    {
                        BeginInvoke(new Action(delegate { progress.Value = p; }));
                    });
                }
                catch (UnauthorizedAccessException)
                {
                    error = "Windows didn't allow installing into that folder. Pick a folder inside your user folder (the default one works), or run Setup as administrator.";
                }
                catch (IOException ex)
                {
                    error = "A file couldn't be written. Is How to Hunt still open? Close it and try again.\n\n" + ex.Message;
                }
                catch (Exception ex)
                {
                    error = "Something went wrong: " + ex.Message;
                }
                BeginInvoke(new Action(delegate { Finished(error); }));
            });
            worker.SetApartmentState(ApartmentState.STA); // Shortcuts are made through a COM object.
            worker.IsBackground = true;
            worker.Start();
        }

        void Finished(string error)
        {
            busy = false;
            if (error != null)
            {
                Look.Ask(this, "Setup failed", error, "OK", null);
                status.Visible = detail.Visible = progress.Visible = false;
                folderTitle.Visible = folderBox.Visible = browse.Visible = desktop.Visible = startMenu.Visible = note.Visible = true;
                install.Enabled = true;
                cancel.Visible = true;
                return;
            }
            done = true;
            progress.Value = 1f;
            progress.Visible = false;
            folderTitle.Visible = folderBox.Visible = browse.Visible = desktop.Visible = startMenu.Visible = note.Visible = false;
            cancel.Visible = false;
            status.Visible = detail.Visible = true;
            status.Text = "All set! " + App.Name + " is installed.";
            detail.Text = "Start it any time from the desktop or the Start menu. Remove it from Windows' Installed apps, or with Uninstall.exe in the game folder.";
            detail.Height = Look.S(52);
            playNow.Visible = true;
            install.Text = "Finish";
            install.Enabled = true;
        }
    }

    static class Installer
    {
        public delegate void ProgressHandler(float progress);

        // Unpacks the game, writes the uninstaller and a list of every file put down
        // (so uninstalling removes exactly those), then shortcuts and the Windows entry.
        public static void Run(string folder, bool desktop, bool startMenu, ProgressHandler onProgress)
        {
            Directory.CreateDirectory(folder);
            List<string> installed = new List<string>();
            long total = 0, written = 0;
            using (Stream zipStream = App.Resource("game.zip"))
            using (ZipArchive zip = new ZipArchive(zipStream, ZipArchiveMode.Read))
            {
                foreach (ZipArchiveEntry entry in zip.Entries)
                    total += entry.Length;
                byte[] buffer = new byte[1 << 16];
                foreach (ZipArchiveEntry entry in zip.Entries)
                {
                    if (entry.FullName.EndsWith("/"))
                        continue;
                    string target = Path.GetFullPath(Path.Combine(folder, entry.FullName));
                    if (!target.StartsWith(Path.GetFullPath(folder), StringComparison.OrdinalIgnoreCase))
                        continue; // Never write outside the install folder.
                    Directory.CreateDirectory(Path.GetDirectoryName(target));
                    using (Stream input = entry.Open())
                    using (FileStream output = File.Create(target))
                    {
                        int read;
                        while ((read = input.Read(buffer, 0, buffer.Length)) > 0)
                        {
                            output.Write(buffer, 0, read);
                            written += read;
                            if (onProgress != null)
                                onProgress(total > 0 ? 0.95f * written / total : 0f);
                        }
                    }
                    installed.Add(entry.FullName.Replace('/', '\\'));
                }
            }
            using (Stream input = App.Resource("Uninstall.exe"))
            using (FileStream output = File.Create(Path.Combine(folder, App.UninstallerExe)))
                input.CopyTo(output);
            installed.Add(App.UninstallerExe);

            string game = Path.Combine(folder, App.GameExe);
            List<string> lines = new List<string>();
            foreach (string file in installed)
                lines.Add("file|" + file);
            if (desktop)
            {
                App.CreateShortcut(App.DesktopShortcut, game, "Play " + App.Name);
                lines.Add("shortcut|" + App.DesktopShortcut);
            }
            if (startMenu)
            {
                App.CreateShortcut(App.StartMenuShortcut, game, "Play " + App.Name);
                lines.Add("shortcut|" + App.StartMenuShortcut);
            }
            lines.Add("file|" + App.ManifestFile);
            File.WriteAllLines(Path.Combine(folder, App.ManifestFile), lines.ToArray());
            App.Register(folder, written);
            if (onProgress != null)
                onProgress(1f);
        }

        public static void Launch(string folder)
        {
            ProcessStartInfo start = new ProcessStartInfo(Path.Combine(folder, App.GameExe));
            start.WorkingDirectory = folder;
            try { Process.Start(start); } catch (Exception) { }
        }
    }

    static class SetupProgram
    {
        [STAThread]
        static int Main(string[] args)
        {
            bool silent = false, shortcuts = true;
            string folder = null;
            foreach (string arg in args)
            {
                if (arg.Equals("/S", StringComparison.OrdinalIgnoreCase))
                    silent = true;
                else if (arg.Equals("/NOSHORTCUTS", StringComparison.OrdinalIgnoreCase))
                    shortcuts = false;
            }
            // /D= must come last and takes the rest of the line, so folders with spaces work
            // with or without quotes.
            string line = Environment.CommandLine;
            int d = line.IndexOf(" /D=", StringComparison.OrdinalIgnoreCase);
            if (d >= 0)
                folder = line.Substring(d + 4).Trim().Trim('"');
            if (silent)
            {
                try
                {
                    Installer.Run(folder ?? App.DefaultFolder, shortcuts, shortcuts, null);
                    return 0;
                }
                catch (Exception ex)
                {
                    Console.Error.WriteLine(ex.Message);
                    return 1;
                }
            }
            Look.Init();
            Application.Run(new SetupWindow());
            return 0;
        }
    }
}
