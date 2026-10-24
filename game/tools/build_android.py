"""Export the installable Android preview APK; never installs or runs it."""

import argparse
import os
from pathlib import Path
import shutil
import subprocess


GAME = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=shutil.which("godot") or shutil.which("godot4"))
    parser.add_argument("--keystore", type=Path, default=Path.home() / ".android/debug.keystore")
    parser.add_argument("--output", type=Path, default=GAME / "builds/Escape-del-Laboratorio-debug.apk")
    args = parser.parse_args()
    if not args.godot:
        parser.error("Pass --godot with the Godot 4.7.2 standard (non-.NET) executable.")
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
    print("Build only. No device was contacted.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
