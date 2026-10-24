#!/usr/bin/env python3
"""Run Godot suites with isolated saves and fail on runtime errors or resource leaks.

Examples:
    python3 game/tools/run_tests.py --jobs 3
    python3 game/tools/run_tests.py --repeat 5 screen_shake_test resource_lifecycle_test
Full verbose transcripts and a JSON summary are saved outside the project.
"""

import argparse
import concurrent.futures
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


GAME = Path(__file__).resolve().parents[1]
DIAGNOSTIC = re.compile(
    r"ERROR:|Leaked instance:|resources still in use|Orphan StringName:|"
    r"WARNING:.*(?:leaked|RID)|RID allocations.*leaked"
)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tests", nargs="*", help="Suite names, without .gd; default: all")
    parser.add_argument("--godot", default=shutil.which("godot") or shutil.which("godot4"))
    parser.add_argument("--jobs", type=int, default=1)
    parser.add_argument("--repeat", type=int, default=1)
    parser.add_argument("--timeout", type=float, default=600)
    parser.add_argument("--log-dir", type=Path)
    args = parser.parse_args()
    if not args.godot:
        parser.error("Godot was not found; pass --godot /path/to/godot")
    if min(args.jobs, args.repeat, args.timeout) <= 0:
        parser.error("jobs, repeat and timeout must be positive")
    available = {p.stem: p for p in (GAME / "tests").glob("*test.gd")}
    unknown = set(args.tests) - available.keys()
    if unknown:
        parser.error("Unknown suites: " + ", ".join(sorted(unknown)))
    logs = args.log_dir or Path(tempfile.mkdtemp(prefix="escape-test-logs-"))
    logs.mkdir(parents=True, exist_ok=True)

    def run(task):
        name, repetition = task
        with tempfile.TemporaryDirectory(prefix="escape-controls-", suffix=".save-check") as data:
            env = dict(os.environ, APPDATA=data, XDG_DATA_HOME=data)
            command = [args.godot, "--headless", "--verbose", "--fixed-fps", "60",
                       "--path", str(GAME), "--script", f"res://tests/{name}.gd"]
            try:
                result = subprocess.run(command, env=env, stdout=subprocess.PIPE,
                                        stderr=subprocess.STDOUT, text=True, timeout=args.timeout)
                output, code = result.stdout, result.returncode
            except subprocess.TimeoutExpired as error:
                output = (error.stdout or b"").decode(errors="replace")
                output += f"\nERROR: Suite exceeded {args.timeout} seconds\n"
                code = 124
        path = logs / f"{name}-{repetition}.log"
        path.write_text(output)
        diagnostics = [line for line in output.splitlines() if DIAGNOSTIC.search(line)]
        passed = code == 0 and not diagnostics
        print(f"{'PASS' if passed else 'FAIL'} {name} ({repetition})", flush=True)
        return dict(test=name, repetition=repetition, passed=passed, exit_code=code,
                    diagnostics=diagnostics, log=str(path.resolve()))

    tasks = [(name, n) for name in sorted(args.tests or available)
             for n in range(1, args.repeat + 1)]
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        results = list(pool.map(run, tasks))
    (logs / "summary.json").write_text(json.dumps(results, indent=2) + "\n")
    failed = sum(not result["passed"] for result in results)
    print(f"{len(results) - failed}/{len(results)} passed. Logs: {logs.resolve()}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
