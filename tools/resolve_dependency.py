#!/usr/bin/env python3
"""Resolve the project's Dependency manager dependencies without the 4D IDE.

``Project/Sources/dependencies.json`` names a GitHub dependency, and 4D keeps
resolved components in ``.local-components/``. When the project is opened in the
IDE that happens automatically; a headless ``tool4d`` run only finds what is
already on disk, and otherwise reports

    PackageManager No component to fetch dependencies
    PackageManager Dependency 'SerialPort' cannot be found

so a fresh clone cannot even compile. This script closes that gap: it reads the
pins and, for every missing component, downloads the release ZIP that the
Dependency manager itself would have fetched and unpacks it into
``.local-components/<name>.4dbase``.

    $ python3 tools/resolve_dependency.py          # resolve what is missing
    $ python3 tools/resolve_dependency.py --check  # report only, no network

`environment4d.json` is the second half of the resolution: it is the map from
dependency name to the folder that holds it, written by the IDE and read by
every other consumer. Unpacking a component without it changes nothing --
4D still reports "Dependency 'SerialPort' cannot be found" -- so ``ensure``
writes both.

Both harnesses call ``ensure`` before launching 4D, so ``run_smoke.py`` and
``run_ui_smoke.py`` work from a fresh clone.
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
import tempfile
import urllib.request
import zipfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SOURCES = REPO / "Project" / "Sources"
LOCAL = REPO / ".local-components"


def _pins(repo: Path = REPO) -> dict[str, tuple[str, str]]:
    """Return ``{name: (github, version)}`` for GitHub dependencies."""
    path = repo / "Project" / "Sources" / "dependencies.json"
    if not path.is_file():
        return {}
    document = json.loads(path.read_text())
    pins: dict[str, tuple[str, str]] = {}
    for name, spec in (document.get("dependencies") or {}).items():
        github, version = spec.get("github"), spec.get("version")
        if github and version:
            pins[name] = (github, version)
    return pins


def _environment(repo: Path, entries: dict[str, str]) -> Path:
    """Merge ``name -> path`` into environment4d.json (the IDE's resolution map)."""
    path = repo / "environment4d.json"
    document: dict = {}
    if path.is_file():
        try:
            document = json.loads(path.read_text())
        except json.JSONDecodeError:
            document = {}
    dependencies = document.setdefault("dependencies", {})
    changed = False
    for name, location in entries.items():
        if dependencies.get(name) != location:
            dependencies[name] = location
            changed = True
    if changed or not path.is_file():
        path.write_text(json.dumps(document, indent="\t") + "\n")
    return path


def _asset_url(github: str, name: str, version: str) -> str:
    return f"https://github.com/{github}/releases/download/{version}/{name}.zip"


def ensure(repo: Path = REPO, *, quiet: bool = False, force: bool = False) -> bool:
    """Make every pinned dependency available; return False on failure."""
    local = repo / ".local-components"
    resolved: dict[str, str] = {}
    for name, (github, version) in _pins(repo).items():
        target = local / f"{name}.4dbase"
        if target.is_dir() and not force:
            resolved[name] = f".local-components/{name}.4dbase"
            if not quiet:
                print(f"dependency {name} {version}: present")
            continue

        url = _asset_url(github, name, version)
        if not quiet:
            print(f"dependency {name} {version}: downloading {url}")
        local.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory() as scratch:
            archive = Path(scratch) / f"{name}.zip"
            try:
                with urllib.request.urlopen(url, timeout=120) as response:
                    archive.write_bytes(response.read())
            except Exception as error:  # noqa: BLE001 - report, do not crash
                print(f"dependency {name}: download failed ({error})", file=sys.stderr)
                return False

            with zipfile.ZipFile(archive) as bundle:
                names = bundle.namelist()
                if f"{name}.4dbase/" not in names:
                    print(
                        f"dependency {name}: the archive does not contain "
                        f"{name}.4dbase/ (first entries: {names[:3]})",
                        file=sys.stderr,
                    )
                    return False
                # Only the component folder, never the archive root, and with
                # the ZIP's own permission bits: zipfile.extract() drops them,
                # and the bundled CLI must stay executable (else POSIX 13).
                for info in bundle.infolist():
                    if not info.filename.startswith(f"{name}.4dbase/"):
                        continue
                    bundle.extract(info, local)
                    mode = (info.external_attr >> 16) & 0o777
                    if mode:
                        (local / info.filename).chmod(mode)

        if not target.is_dir():
            print(f"dependency {name}: unpacking produced no {target}", file=sys.stderr)
            return False
        resolved[name] = f".local-components/{name}.4dbase"
        if not quiet:
            print(f"dependency {name} {version}: unpacked into {target}")

    if resolved:
        map_file = _environment(repo, resolved)
        if not quiet:
            print(f"resolution map: {map_file.relative_to(repo)}")
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="report without downloading")
    parser.add_argument("--force", action="store_true", help="re-download even if present")
    options = parser.parse_args()

    pins = _pins(REPO)
    if not pins:
        print("no GitHub dependencies pinned in Project/Sources/dependencies.json")
        return 0

    if options.check:
        for name, (github, version) in pins.items():
            state = "present" if (LOCAL / f"{name}.4dbase").is_dir() else "missing"
            print(f"{name} {version} ({github}): {state}")
        return 0

    return 0 if ensure(REPO, force=options.force) else 1


if __name__ == "__main__":
    raise SystemExit(main())
