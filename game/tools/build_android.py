"""Export the installable Android preview APK; never installs or runs it."""

import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys


GAME = Path(__file__).resolve().parents[1]


def editor_settings_path(godot):
    binary = Path(shutil.which(str(godot)) or godot).resolve()
    if any((binary.parent / marker).is_file() for marker in ("_sc_", "._sc_")):
        return binary.parent / "editor_data/editor_settings-4.7.tres"
    if sys.platform == "win32":
        directory = Path(os.environ.get("APPDATA", Path.home() / "AppData/Roaming")) / "Godot"
    elif sys.platform == "darwin":
        directory = Path.home() / "Library/Application Support/Godot"
    else:
        directory = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "godot"
    return directory / "editor_settings-4.7.tres"


def keeps_adb_running(settings):
    try:
        content = settings.read_text(encoding="utf-8-sig")
    except OSError:
        return False
    values = re.findall(r"^\s*export/android/shutdown_adb_on_exit\s*=\s*(true|false)\s*$", content, re.MULTILINE)
    # Godot defaults to true when the setting is absent. Never start an export
    # that may shut down the user's shared ADB server (and wireless transports).
    return bool(values) and values[-1] == "false"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=shutil.which("godot") or shutil.which("godot4"))
    parser.add_argument("--keystore", type=Path, default=Path.home() / ".android/debug.keystore")
    parser.add_argument("--output", type=Path, default=GAME / "builds/Escape-del-Laboratorio-debug.apk")
    args = parser.parse_args()
    if not args.godot:
        parser.error("Pass --godot with the Godot 4.7.2 standard (non-.NET) executable.")
    settings = editor_settings_path(args.godot)
    if not keeps_adb_running(settings):
        parser.error("Export stopped to preserve the shared ADB server. In Godot Editor Settings > "
                     "Export > Android, disable Shutdown Adb On Exit (advanced settings), then rerun. "
                     f"Expected export/android/shutdown_adb_on_exit = false in {settings}")
    version = subprocess.run([args.godot, "--version"], capture_output=True, text=True, check=True).stdout.strip()
    if "mono" in version:
        parser.error("Use standard Godot: this GDScript project does not need the .NET Android runtime.")
    if not version.startswith("4.7.2."):
        parser.error(f"Expected Godot 4.7.2 and matching export templates, got {version!r}.")
    env = os.environ.copy()
    keystore = args.keystore.expanduser().resolve()
    if keystore.is_file():
        env.update(GODOT_ANDROID_KEYSTORE_DEBUG_PATH=str(keystore),
                   GODOT_ANDROID_KEYSTORE_DEBUG_USER="androiddebugkey",
                   GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="android")
    output = args.output.expanduser().resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    command = [args.godot, "--headless", "--path", str(GAME), "--export-debug", "Android", str(output)]
    result = subprocess.run(command, env=env, check=False)
    if result.returncode:
        return result.returncode
    if not output.is_file():
        parser.error("Godot did not produce an APK. Check SDK, templates and debug signing in Editor Settings.")
    print(f"APK: {output} ({output.stat().st_size / 1024 / 1024:.1f} MiB)")
    print("Build only. No app was installed or launched; shared ADB server preserved.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
