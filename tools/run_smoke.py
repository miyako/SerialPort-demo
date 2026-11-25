#!/usr/bin/env python3
"""Run the SerialPort demo's headless end-to-end test.

Starts the PTY-backed virtual device, writes the demo-test input file the 4D
side expects, runs tool4d with the demo test startup method and reports the
result of every case.

    $ python3 tools/run_smoke.py
    $ python3 tools/run_smoke.py --tool4d /path/to/tool4d

Exit code 0 means every case passed.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
PROJECT = REPO / "Project" / "SerialPort-demo.4DProject"

sys.path.insert(0, str(Path(__file__).resolve().parent))
import resolve_dependency  # noqa: E402  (needs the path above)
SIMULATOR = REPO / "tools" / "virtual-serial" / "virtual_serial.py"
INPUT = REPO / "demo-test-input.json"
REPORT = REPO / "demo-test-report.json"
STATUS = REPO / "demo-test-status.json"

DEFAULT_TOOL4D = Path(
    "/Applications/tool4d/tool4d/21R4/100224/tool4d.app/Contents/MacOS/tool4d"
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tool4d", default=os.environ.get("TOOL4D_PATH", ""))
    parser.add_argument("--timeout", type=int, default=90)
    parser.add_argument("--keep-files", action="store_true")
    return parser.parse_args()


def tool4d_binary(argument: str) -> Path:
    candidate = Path(argument) if argument else DEFAULT_TOOL4D
    if not candidate.exists():
        sys.exit(f"tool4d not found: {candidate}\nPass --tool4d or set TOOL4D_PATH")
    return candidate


class Device:
    """The PTY simulator, supervised from this process."""

    def __init__(self) -> None:
        self.process = subprocess.Popen(
            [sys.executable, str(SIMULATOR)],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1,
        )
        self.port = self._wait_for_port()

    def _wait_for_port(self) -> str:
        deadline = time.monotonic() + 20
        while time.monotonic() < deadline:
            line = self.process.stdout.readline()
            if not line:
                break
            line = line.strip()
            if line.startswith("PORT="):
                port = line.split("=", 1)[1].strip()
                # The READY line follows; consuming it keeps the pipe honest.
                while True:
                    ready = self.process.stdout.readline()
                    if not ready or ready.strip() == "READY":
                        break
                return port
        self.close()
        raise RuntimeError("the virtual device did not announce a port")

    def close(self) -> None:
        if self.process.poll() is None:
            self.process.terminate()
            try:
                self.process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.process.kill()


def main() -> int:
    args = parse_args()
    binary = tool4d_binary(args.tool4d)

    # A fresh clone has no resolved component yet: tool4d only reads what the
    # Dependency manager already put in .local-components.
    if not resolve_dependency.ensure(REPO):
        print("the SerialPort dependency could not be resolved", file=sys.stderr)
        return 1

    if REPORT.exists():
        REPORT.unlink()
    if STATUS.exists():
        STATUS.unlink()

    # tool4d needs a writable "Application Support/tool4d/<project name>" folder.
    # FIXED_USER_HOME makes that independent of the machine's real home folder.
    home = Path(tempfile.mkdtemp(prefix="serial-demo-t4d-"))
    (home / "Library" / "Application Support").mkdir(parents=True, exist_ok=True)

    device = Device()
    print(f"virtual device: {device.port}")

    INPUT.write_text(json.dumps({"port": device.port}), encoding="utf-8")

    environment = dict(os.environ)
    environment["CFFIXED_USER_HOME"] = str(home)

    command = [
        str(binary),
        "--dataless",
        "--skip-onstartup",
        "--startup-method=SerialPortDemoTest",
        f"--project={PROJECT}",
    ]
    print("running:", " ".join(command))
    started = time.monotonic()
    try:
        completed = subprocess.run(
            command,
            env=environment,
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
    finally:
        device.close()
        shutil.rmtree(home, ignore_errors=True)

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
        print(f"port={report.get('port')} connection={report.get('connection', '')}")
        for case in report.get("cases", []):
            mark = "PASS" if case.get("ok") else "FAIL"
            print(f"  {mark}  {case.get('name')}")
            if not case.get("ok"):
                print(f"        {json.dumps(case.get('detail'), ensure_ascii=False)}")
    else:
        print("no report was written")

    success = bool(report.get("success")) and bool(report.get("finished"))
    print()
    print(f"{'PASS' if success else 'FAIL'} in {elapsed:.1f}s (tool4d exit code {exit_code})")

    if not success:
        if output.strip():
            print("--- tool4d output -------------------------------------------")
            print(output.strip()[-4000:])
        if not args.keep_files:
            pass
        return 1

    if not args.keep_files:
        for leftover in (INPUT, STATUS):
            if leftover.exists():
                leftover.unlink()
    return 0


if __name__ == "__main__":
    sys.exit(main())
