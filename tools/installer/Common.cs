// Shared by the How to Hunt setup and uninstaller: names, the game's look (colours, the
// Kurale font, rounded buttons and tick boxes) and small Windows helpers.
// Built with the C# compiler that comes with Windows (.NET Framework 4.8), see build.py.

using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using Microsoft.Win32;

namespace HowToHunt
{
    static class App
    {
        public const string Name = "How to Hunt";
        public const string Version = "0.2.0";
        public const string Publisher = "HASH1MX";
        public const string GameExe = "HowToHunt.exe";
        public const string UninstallerExe = "Uninstall.exe";
        public const string ManifestFile = "install.log";
        public const string UninstallKey = @"Software\Microsoft\Windows\CurrentVersion\Uninstall\HowToHunt";

        public static string DefaultFolder
        {
            get { return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Programs", Name); }
        }

        public static string DesktopShortcut
        {
            get { return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory), Name + ".lnk"); }
        }

        public static string StartMenuShortcut
        {
            get { return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs), Name + ".lnk"); }
        }

        public static bool GameIsRunning()
        {
            return Process.GetProcessesByName(Path.GetFileNameWithoutExtension(GameExe)).Length > 0;
        }

        public static Stream Resource(string name)
        {
            return Assembly.GetExecutingAssembly().GetManifestResourceStream(name);
        }

        public static void CreateShortcut(string link, string target, string description)
        {
            Type shellType = Type.GetTypeFromProgID("WScript.Shell");
            object shell = Activator.CreateInstance(shellType);
            object shortcut = shellType.InvokeMember("CreateShortcut", BindingFlags.InvokeMethod, null, shell, new object[] { link });
            Type t = shortcut.GetType();
            t.InvokeMember("TargetPath", BindingFlags.SetProperty, null, shortcut, new object[] { target });
            t.InvokeMember("WorkingDirectory", BindingFlags.SetProperty, null, shortcut, new object[] { Path.GetDirectoryName(target) });
            t.InvokeMember("IconLocation", BindingFlags.SetProperty, null, shortcut, new object[] { target + ",0" });
            t.InvokeMember("Description", BindingFlags.SetProperty, null, shortcut, new object[] { description });
            t.InvokeMember("Save", BindingFlags.InvokeMethod, null, shortcut, null);
            Marshal.FinalReleaseComObject(shortcut);
            Marshal.FinalReleaseComObject(shell);
        }

        public static void Register(string folder, long sizeBytes)
        {
            using (RegistryKey key = Registry.CurrentUser.CreateSubKey(UninstallKey))
            {
                key.SetValue("DisplayName", Name);
                key.SetValue("DisplayVersion", Version);
                key.SetValue("Publisher", Publisher);
                key.SetValue("DisplayIcon", Path.Combine(folder, GameExe) + ",0");
                key.SetValue("InstallLocation", folder);
                key.SetValue("UninstallString", "\"" + Path.Combine(folder, UninstallerExe) + "\"");
                key.SetValue("QuietUninstallString", "\"" + Path.Combine(folder, UninstallerExe) + "\" /S");
                key.SetValue("EstimatedSize", (int)(sizeBytes / 1024), RegistryValueKind.DWord);
                key.SetValue("NoModify", 1, RegistryValueKind.DWord);
                key.SetValue("NoRepair", 1, RegistryValueKind.DWord);
            }
        }

        public static void Unregister()
        {
            Registry.CurrentUser.DeleteSubKeyTree(UninstallKey, false);
        }
    }

    // The game's look: dark see-through panels, cream text, orange highlights, Kurale font.
    static class Look
    {
        public static readonly Color Back = Color.FromArgb(14, 16, 19);
        public static readonly Color Panel = Color.FromArgb(28, 31, 36);
        public static readonly Color Text = Color.FromArgb(245, 240, 230);
        public static readonly Color Title = Color.FromArgb(255, 242, 214);
        public static readonly Color Dim = Color.FromArgb(170, 168, 160);
        public static readonly Color Accent = Color.FromArgb(237, 115, 77);
        public static readonly Color Line = Color.FromArgb(70, 74, 80);

        static PrivateFontCollection fonts;
        public static float Scale = 1f;

        [DllImport("user32.dll")]
        static extern bool SetProcessDPIAware();

        [DllImport("gdi32.dll")]
        static extern IntPtr AddFontMemResourceEx(IntPtr data, uint length, IntPtr reserved, ref uint count);

        public static void Init()
        {
            try { SetProcessDPIAware(); } catch (Exception) { }
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(true);
            using (Graphics g = Graphics.FromHwnd(IntPtr.Zero))
                Scale = g.DpiX / 96f;
            fonts = new PrivateFontCollection();
            using (Stream s = App.Resource("Kurale.ttf"))
            {
                if (s == null)
                    return;
                byte[] data = new byte[s.Length];
                s.Read(data, 0, data.Length);
                IntPtr memory = Marshal.AllocCoTaskMem(data.Length); // Kept for as long as the program runs.
                Marshal.Copy(data, 0, memory, data.Length);
                fonts.AddMemoryFont(memory, data.Length);
                uint count = 0;
                AddFontMemResourceEx(memory, (uint)data.Length, IntPtr.Zero, ref count);
            }
        }

        public static Font Font(float points)
        {
            if (fonts != null && fonts.Families.Length > 0)
                return new Font(fonts.Families[0], points, FontStyle.Regular);
            return new Font("Segoe UI", points * 0.9f, FontStyle.Regular);
        }

        public static int S(float value)
        {
            return (int)Math.Round(value * Scale);
        }

        public static Icon AppIcon()
        {
            using (Stream s = App.Resource("icon.ico"))
                return s == null ? null : new Icon(s);
        }

        public static GraphicsPath Rounded(RectangleF r, float radius)
        {
            GraphicsPath path = new GraphicsPath();
            float d = radius * 2f;
            path.AddArc(r.X, r.Y, d, d, 180, 90);
            path.AddArc(r.Right - d, r.Y, d, d, 270, 90);
            path.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
            path.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
            path.CloseFigure();
            return path;
        }

        public static Label MakeLabel(string text, float points, Color color)
        {
            Label label = new Label();
            label.Text = text;
            label.Font = Font(points);
            label.ForeColor = color;
            label.BackColor = Color.Transparent;
            label.UseCompatibleTextRendering = true;
            label.AutoSize = false;
            return label;
        }

        public static Form MakeWindow(string title, int width, int height)
        {
            Form form = new Form();
            form.Text = title;
            form.Icon = AppIcon();
            form.BackColor = Back;
            form.ForeColor = Text;
            form.FormBorderStyle = FormBorderStyle.FixedSingle;
            form.MaximizeBox = false;
            form.StartPosition = FormStartPosition.CenterScreen;
            form.AutoScaleMode = AutoScaleMode.None;
            form.ClientSize = new Size(S(width), S(height));
            return form;
        }

        // A message box in the game's look. Returns true for the first (orange) button.
        public static bool Ask(IWin32Window owner, string title, string message, string yes, string no)
        {
            Form box = MakeWindow(title, 440, 190);
            box.ShowInTaskbar = owner == null;
            Label text = MakeLabel(message, 11.5f, Text);
            text.SetBounds(S(24), S(22), S(392), S(100));
            box.Controls.Add(text);
            bool result = false;
            GameButton ok = new GameButton(yes, true);
            ok.SetBounds(S(296), S(132), S(120), S(40));
            ok.Click += delegate { result = true; box.Close(); };
            box.Controls.Add(ok);
            if (no != null)
            {
                GameButton cancel = new GameButton(no, false);
                cancel.SetBounds(S(176), S(132), S(110), S(40));
                cancel.Click += delegate { box.Close(); };
                box.Controls.Add(cancel);
            }
            box.ShowDialog(owner);
            return result;
        }
    }

    // A rounded button: orange-filled for the main action, plain text for the others.
    class GameButton : Control
    {
        readonly bool primary;
        bool hover;

        public GameButton(string text, bool primary)
        {
            this.primary = primary;
            Text = text;
            Font = Look.Font(primary ? 14f : 12.5f);
            Cursor = Cursors.Hand;
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint | ControlStyles.SupportsTransparentBackColor, true);
            BackColor = Color.Transparent;
        }

        protected override void OnMouseEnter(EventArgs e) { hover = true; Invalidate(); base.OnMouseEnter(e); }
        protected override void OnMouseLeave(EventArgs e) { hover = false; Invalidate(); base.OnMouseLeave(e); }
        protected override void OnEnabledChanged(EventArgs e) { Invalidate(); base.OnEnabledChanged(e); }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
            RectangleF r = new RectangleF(1, 1, Width - 3, Height - 3);
            Color text = Enabled ? (hover && !primary ? Color.White : Look.Text) : Look.Dim;
            if (primary)
            {
                Color fill = !Enabled ? Look.Line : (hover ? ControlPaint.Light(Look.Accent, 0.15f) : Look.Accent);
                using (GraphicsPath path = Look.Rounded(r, Look.S(10)))
                using (SolidBrush brush = new SolidBrush(fill))
                using (Pen pen = new Pen(Color.FromArgb(Enabled ? 255 : 80, 255, 255, 255), Look.S(2)))
                {
                    g.FillPath(brush, path);
                    g.DrawPath(pen, path);
                }
                text = Color.White;
            }
            else if (hover && Enabled)
            {
                using (GraphicsPath path = Look.Rounded(r, Look.S(10)))
                using (SolidBrush brush = new SolidBrush(Color.FromArgb(28, 255, 255, 255)))
                    g.FillPath(brush, path);
            }
            StringFormat center = new StringFormat();
            center.Alignment = StringAlignment.Center;
            center.LineAlignment = StringAlignment.Center;
            using (SolidBrush shadow = new SolidBrush(Color.FromArgb(110, 0, 0, 0)))
                g.DrawString(Text, Font, shadow, new RectangleF(r.X + 1.5f, r.Y + 1.5f, r.Width, r.Height), center);
            using (SolidBrush brush = new SolidBrush(text))
                g.DrawString(Text, Font, brush, r, center);
        }
    }

    // A tick box with a label, in the game's colours.
    class TickBox : Control
    {
        bool ticked;
        public event EventHandler Changed;

        public TickBox(string text, bool ticked)
        {
            Text = text;
            this.ticked = ticked;
            Font = Look.Font(12f);
            Cursor = Cursors.Hand;
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint | ControlStyles.SupportsTransparentBackColor, true);
            BackColor = Color.Transparent;
        }

        public bool Ticked
        {
            get { return ticked; }
            set { ticked = value; Invalidate(); }
        }

        protected override void OnClick(EventArgs e)
        {
            ticked = !ticked;
            Invalidate();
            if (Changed != null)
                Changed(this, EventArgs.Empty);
            base.OnClick(e);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
            float size = Look.S(20);
            RectangleF box = new RectangleF(1, (Height - size) / 2f, size, size);
            using (GraphicsPath path = Look.Rounded(box, Look.S(5)))
            {
                using (SolidBrush fill = new SolidBrush(ticked ? Look.Accent : Color.FromArgb(40, 255, 255, 255)))
                    g.FillPath(fill, path);
                using (Pen pen = new Pen(ticked ? Look.Accent : Color.FromArgb(200, 255, 255, 255), Look.S(2)))
                    g.DrawPath(pen, path);
            }
            if (ticked)
            {
                using (Pen tick = new Pen(Color.White, Look.S(2.6f)))
                {
                    tick.StartCap = LineCap.Round;
                    tick.EndCap = LineCap.Round;
                    tick.LineJoin = LineJoin.Round;
                    g.DrawLines(tick, new PointF[] {
                        new PointF(box.X + size * 0.24f, box.Y + size * 0.52f),
                        new PointF(box.X + size * 0.43f, box.Y + size * 0.7f),
                        new PointF(box.X + size * 0.77f, box.Y + size * 0.3f) });
                }
            }
            StringFormat middle = new StringFormat();
            middle.LineAlignment = StringAlignment.Center;
            using (SolidBrush brush = new SolidBrush(Look.Text))
                g.DrawString(Text, Font, brush, new RectangleF(size + Look.S(10), 0, Width - size - Look.S(10), Height), middle);
        }
    }

    // A rounded progress bar that fills orange.
    class ProgressStrip : Control
    {
        float value;

        public ProgressStrip()
        {
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint | ControlStyles.SupportsTransparentBackColor, true);
            BackColor = Color.Transparent;
        }

        public float Value
        {
            get { return value; }
            set { this.value = Math.Max(0f, Math.Min(1f, value)); Invalidate(); }
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            RectangleF r = new RectangleF(0, 0, Width - 1, Height - 1);
            float radius = r.Height / 2f;
            using (GraphicsPath track = Look.Rounded(r, radius))
            using (SolidBrush brush = new SolidBrush(Color.FromArgb(46, 255, 255, 255)))
                g.FillPath(brush, track);
            float w = Math.Max(r.Height, r.Width * value);
            if (value > 0f)
            {
                using (GraphicsPath fill = Look.Rounded(new RectangleF(0, 0, w, r.Height), radius))
                using (SolidBrush brush = new SolidBrush(Look.Accent))
                    g.FillPath(brush, fill);
            }
        }
    }
}
