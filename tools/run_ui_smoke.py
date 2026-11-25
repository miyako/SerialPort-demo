#!/usr/bin/env python3
"""Drive the demo's real window and report what it showed.

The headless suite (``tools/run_smoke.py``) exercises the component through an
owner worker only.  This runner goes one level further: it launches the full 4D
application, opens the ``Main`` form, and lets ``SerialPortDemoUIDriver`` click
the demo's own buttons while the window stays in its event loop.  The verdict is
read back from two files written by that run:

* a status file published by the worker (the same one the demo shows on screen)
* a form dump published by the window process itself

    $ python3 tools/run_ui_smoke.py
    $ python3 tools/run_ui_smoke.py --4d "/Applications/4D 21 R5 (100176)/4D.app/Contents/MacOS/4D"

Exit code 0 means every case passed.  The run needs a desktop session: 4D opens
a window and closes it again when the driver finishes.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
PROJECT = REPO / "Project" / "SerialPort-demo.4DProject"

# 4D writes reliably inside the project folder, while writes to /tmp can be
# refused silently by the macOS sandbox, so every artefact stays here.
STATUS = REPO / "demo-ui-status.json"
REPORT = REPO / "demo-ui-report.json"
FORM_DUMP = REPO / "demo-ui-report.json.end.json"
TRACE = REPO / "demo-ui-report.json.trace.txt"
MID_DUMP = REPO / "demo-ui-report.json.mid.json"
END_DUMP = REPO / "demo-ui-report.json.end.json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--4d", dest="fourd", default=os.environ.get("FOURD_PATH", ""))
    parser.add_argument("--timeout", type=int, default=120)
    parser.add_argument("--keep-files", action="store_true")
    return parser.parse_args()


def fourd_binary(argument: str) -> Path:
    if argument:
        candidate = Path(argument)
    else:
        # Feature-release builds are preferred: the installed 21.2 LTS build
        # (100694) hangs before running the startup method when --user-param is
        # passed, while 21 R5 runs it and quits as documented.
        candidates = sorted(Path("/Applications").glob("4D */4D.app/Contents/MacOS/4D"))
        feature = [path for path in candidates if "LTS" not in str(path)]
        ordered = feature + [path for path in candidates if path not in feature]
        candidate = ordered[0] if ordered else Path("/Applications/4D.app/Contents/MacOS/4D")
    if not candidate.exists():
        sys.exit(f"4D not found: {candidate}\nPass --4d or set FOURD_PATH")
    return candidate


def main() -> int:
    args = parse_args()
    binary = fourd_binary(args.fourd)

    for leftover in (STATUS, REPORT, FORM_DUMP, TRACE, MID_DUMP, END_DUMP):
        if leftover.exists():
            leftover.unlink()

    user_param = f"{STATUS}|{REPORT}"
    command = [
        str(binary),
        f"--project={PROJECT}",
        "--dataless",
        "--skip-onstartup",
        "--startup-method=SerialPortDemoUIRun",
        f"--user-param={user_param}",
    ]
    print(f"4D: {binary}")
    print("running:", " ".join(command))

    started = time.monotonic()
    try:
        completed = subprocess.run(
            command,
            timeout=args.timeout,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        )
        output = completed.stdout
        exit_code = completed.returncode
    except subprocess.TimeoutExpired as timeout:
        output = timeout.stdout or ""
        exit_code = -1

    elapsed = time.monotonic() - started
    report = {}
    if REPORT.exists():
        try:
            report = json.loads(REPORT.read_text(encoding="utf-8"))
        except json.JSONDecodeError as error:
            print(f"unreadable report: {error}")

    print()
    if report:
        print(f"finished={report.get('finished')} success={report.get('success')} phase={report.get('phase')}")
        for case in report.get("cases", []):
            mark = "PASS" if case.get("ok") else "FAIL"
            print(f"  {mark}  {case.get('name')}")
            if not case.get("ok"):
                print(f"        {json.dumps(case.get('detail'), ensure_ascii=False)}")
    else:
        print("no report was written")

    dump = {}
    if FORM_DUMP.exists():
        try:
            dump = json.loads(FORM_DUMP.read_text(encoding="utf-8"))
        except json.JSONDecodeError as error:
            print(f"unreadable form dump: {error}")
    if dump:
        print()
        print("what the window displayed:")
        for key in ("phase", "statusText", "statsText", "chunkCountText", "deviceState", "connection"):
            print(f"  {key}: {dump.get(key)}")
        print(f"  rx: {str(dump.get('rx', ''))[:400]}")
        for line in (dump.get("tail") or [])[-8:]:
            print(f"  log  {line}")

    success = bool(report.get("success")) and bool(report.get("finished"))
    print()
    print(f"{'PASS' if success else 'FAIL'} in {elapsed:.1f}s (4D exit code {exit_code})")

    if not success:
        if output.strip():
            print("--- 4D output -----------------------------------------------")
            print(output.strip()[-4000:])
        return 1

    if not args.keep_files:
        for leftover in (STATUS, REPORT, FORM_DUMP, TRACE, MID_DUMP, END_DUMP):
            if leftover.exists():
                leftover.unlink()
    return 0


if __name__ == "__main__":
    sys.exit(main())
