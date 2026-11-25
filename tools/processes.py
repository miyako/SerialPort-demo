#!/usr/bin/env python3
"""Reap leftover simulator processes before a run.

A run that is interrupted -- a killed 4D, a timeout, a Ctrl-C -- leaves its
``virtual_serial.py`` helper alive holding a PTY. The next run gets the same
``/dev/ttysNNN`` path back from the kernel, the stale helper still owns the
slave side, and writes disappear into a device nobody reads: the suite then
fails with "0 chunks were decoded" while every step reports success.

Reaping is scoped to this repository's script path, so an unrelated process is
never touched.
"""

from __future__ import annotations

import os
import signal
import subprocess
import sys
from pathlib import Path


def _ancestors(pid: int) -> set[int]:
    """This process and every process above it, so a shell is never a target."""
    seen: set[int] = set()
    while pid and pid not in seen:
        seen.add(pid)
        try:
            parent = subprocess.run(
                ["ps", "-o", "ppid=", "-p", str(pid)],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
                check=False,
            ).stdout.strip()
        except OSError:
            break
        try:
            pid = int(parent)
        except ValueError:
            break
    return seen


def _candidates(script: Path) -> list[int]:
    """PIDs whose command line runs ``script`` (best effort, POSIX + ps)."""
    try:
        listing = subprocess.run(
            ["ps", "-Ao", "pid=,command="],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            check=False,
        ).stdout
    except OSError:
        return []

    # Match the file name, not the absolute path: leftovers may have been
    # started from another working directory (relative command line).
    culprit = script.name
    protected = _ancestors(os.getpid())
    pids: list[int] = []
    for line in listing.splitlines():
        fields = line.strip().split(None, 1)
        if len(fields) != 2:
            continue
        pid, command = fields
        if culprit not in command or "ps -Ao" in command:
            continue
        # Only the interpreter that runs the script: a shell whose command
        # line merely mentions the name (a CI step, a wrapper) is not a helper.
        # macOS shows the interpreter as "Python" (capitalised) inside the
        # framework bundle, so compare without case.
        interpreter = Path(command.split(None, 1)[0]).name.lower()
        if "python" not in interpreter:
            continue
        try:
            number = int(pid)
        except ValueError:
            continue
        if number not in protected:
            pids.append(number)
    return pids


def reap_simulators(repo: Path, *, quiet: bool = False) -> int:
    """Kill leftover virtual_serial.py helpers; return how many were killed."""
    script = repo / "tools" / "virtual-serial" / "virtual_serial.py"
    killed = 0
    for pid in _candidates(script):
        if pid == os.getpid():
            continue
        try:
            os.kill(pid, signal.SIGKILL)
            killed += 1
        except OSError:
            continue
    if killed and not quiet:
        print(f"reaped {killed} leftover simulator process(es) from an earlier run")
    return killed


if __name__ == "__main__":
    repo = Path(__file__).resolve().parent.parent
    sys.exit(0 if reap_simulators(repo) >= 0 else 1)
