"""Explicit, user-run Android installation and diagnostics. Never creates an emulator."""

import argparse
from pathlib import Path
import shutil
import subprocess


PACKAGE = "mx.udg.alumnos.juegos.escape_del_laboratorio"
GAME = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--adb", default=shutil.which("adb"))
    parser.add_argument("--serial", help="Explicit device serial from adb devices (required for device actions)")
    actions = parser.add_subparsers(dest="action", required=True)
    actions.add_parser("devices", help="List attached devices only")
    install = actions.add_parser("install", help="Install/update the APK, preserving app data")
    install.add_argument("--apk", type=Path, default=GAME / "builds/Escape-del-Laboratorio-debug.apk")
    actions.add_parser("launch", help="Launch the installed game")
    logs = actions.add_parser("logs", help="Save existing application logs without clearing the device log")
    logs.add_argument("--output", type=Path, default=GAME / "builds/android-logcat.txt")
    shot = actions.add_parser("screenshot", help="Save the current device screen as PNG")
    shot.add_argument("--output", type=Path, default=GAME / "builds/android-screen.png")
    args = parser.parse_args()
    if not args.adb:
        parser.error("adb not found; add Android platform-tools to PATH or pass --adb.")
    if args.action == "devices":
        return subprocess.run([args.adb, "devices", "-l"], check=False).returncode
    if not args.serial:
        parser.error("Specify --serial to avoid acting on the wrong device.")
    command = [args.adb, "-s", args.serial]
    subprocess.run(command + ["get-state"], check=True, capture_output=True)
    if args.action == "install":
        if not args.apk.is_file():
            parser.error(f"APK not found: {args.apk}")
        return subprocess.run(command + ["install", "-r", str(args.apk.resolve())], check=False).returncode
    if args.action == "launch":
        # Resolve the exported launcher alias; the internal GodotApp activity
        # is not exported by the 4.7 Android template.
        return subprocess.run(command + ["shell", "am", "start", "-a", "android.intent.action.MAIN",
                                         "-c", "android.intent.category.LAUNCHER", "-p", PACKAGE], check=False).returncode
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    if args.action == "screenshot":
        result = subprocess.run(command + ["exec-out", "screencap", "-p"], capture_output=True, check=True)
        output.write_bytes(result.stdout)
    else:
        pid = subprocess.run(command + ["shell", "pidof", "-s", PACKAGE], capture_output=True, text=True, check=False).stdout.strip()
        if not pid.isdecimal():
            parser.error("Game is not running; launch it first to collect process logs.")
        result = subprocess.run(command + ["logcat", "-d", f"--pid={pid}", "-v", "threadtime"], capture_output=True, check=True)
        output.write_bytes(result.stdout)
    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
