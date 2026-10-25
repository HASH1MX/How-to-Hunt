"""Builds the How to Hunt setup file: build/HowToHunt-Setup.exe.

1. Export the game first (build/windows/HowToHunt.exe, see docs/PROGRESS.md).
2. Run from the project folder:  python tools/installer/build.py

Packs build/windows into game.zip and compiles Uninstall.exe and the setup with the C#
compiler that comes with Windows (.NET Framework 4.8), so nothing extra is needed."""
import os, shutil, subprocess, sys, zipfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
HERE = os.path.join(ROOT, "tools", "installer")
GAME = os.path.join(ROOT, "build", "windows")
WORK = os.path.join(ROOT, "build", "installer")
OUT = os.path.join(ROOT, "build", "HowToHunt-Setup.exe")
CSC = os.path.join(os.environ.get("WINDIR", r"C:\Windows"), "Microsoft.NET", "Framework64", "v4.0.30319", "csc.exe")
GAME_FILES = ["HowToHunt.exe", "libgodotsteam.windows.template_release.x86_64.dll", "steam_api64.dll", "steam_appid.txt"]


def compile_exe(out, sources, resources):
    args = [CSC, "/nologo", "/target:winexe", "/optimize+", "/platform:anycpu",
            "/out:" + out, "/win32icon:" + os.path.join(HERE, "icon.ico"),
            "/win32manifest:" + os.path.join(HERE, "app.manifest"),
            "/reference:System.Windows.Forms.dll", "/reference:System.Drawing.dll",
            "/reference:System.IO.Compression.dll", "/reference:System.IO.Compression.FileSystem.dll"]
    args += ["/resource:%s,%s" % (path, name) for path, name in resources]
    args += [os.path.join(HERE, s) for s in sources]
    result = subprocess.run(args, capture_output=True, text=True)
    if result.returncode != 0:
        print(result.stdout, result.stderr)
        sys.exit("Compiling %s failed" % os.path.basename(out))


def main():
    for name in GAME_FILES:
        if not os.path.exists(os.path.join(GAME, name)):
            sys.exit("Missing build/windows/%s - export the game first." % name)
    os.makedirs(WORK, exist_ok=True)
    font = os.path.join(ROOT, "assets", "fonts", "Kurale-Regular.ttf")
    icon = os.path.join(HERE, "icon.ico")

    game_zip = os.path.join(WORK, "game.zip")
    with zipfile.ZipFile(game_zip, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for name in GAME_FILES:
            z.write(os.path.join(GAME, name), name)
        z.write(os.path.join(HERE, "HOW_TO_PLAY.txt"), "HOW_TO_PLAY.txt")
    print("game.zip: %.1f MB" % (os.path.getsize(game_zip) / 1e6))

    uninstaller = os.path.join(WORK, "Uninstall.exe")
    compile_exe(uninstaller, ["Common.cs", "Uninstall.cs"], [(font, "Kurale.ttf"), (icon, "icon.ico")])
    compile_exe(OUT, ["Common.cs", "Setup.cs"], [
        (game_zip, "game.zip"), (uninstaller, "Uninstall.exe"), (font, "Kurale.ttf"), (icon, "icon.ico"),
        (os.path.join(HERE, "banner.png"), "banner.png")])
    print("Built %s (%.1f MB)" % (OUT, os.path.getsize(OUT) / 1e6))


if __name__ == "__main__":
    main()
