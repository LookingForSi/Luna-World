#!/usr/bin/env python3
"""Build immutable production Place artifacts without publishing them."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CONFIG_PATH = ROOT / "tools/deploy/production.json"
OUTPUT_DIR = ROOT / "artifacts/deploy"


def fail(message: str) -> None:
    raise SystemExit(f"production build refused: {message}")


def load_json(path: Path) -> dict:
    if not path.is_file():
        fail(f"required file is missing: {path.relative_to(ROOT)}")
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        fail(f"cannot read {path.relative_to(ROOT)}: {error}")


def verify_rojo() -> None:
    result = subprocess.run(["rojo", "--version"], check=True, text=True, capture_output=True)
    if "7.7.0" not in result.stdout:
        fail(f"Rojo 7.7.0 is required; got {result.stdout.strip()!r}")
    print(result.stdout.strip())


def build_project(project: Path, output: Path) -> None:
    if not project.is_file():
        fail(f"required project is missing: {project.relative_to(ROOT)}")
    print(f"Building {project.relative_to(ROOT)} -> {output.relative_to(ROOT)}")
    subprocess.run(["rojo", "build", str(project), "-o", str(output)], cwd=ROOT, check=True)


def copy_canonical_moonfall(place: dict, output: Path) -> None:
    manifest_path = ROOT / place["canonicalManifest"]
    manifest = load_json(manifest_path)
    if manifest.get("ready") is not True:
        fail("Moonfall canonical authored-place guard is closed (ready must be true)")
    source = manifest_path.parent / str(manifest.get("artifact", ""))
    expected = manifest.get("sha256")
    if not source.is_file() or source.stat().st_size == 0:
        fail(f"canonical Moonfall artifact is missing or empty: {source.relative_to(ROOT)}")
    if not isinstance(expected, str) or len(expected) != 64:
        fail("Moonfall manifest must contain a full SHA-256 digest")
    actual = hashlib.sha256(source.read_bytes()).hexdigest()
    if actual != expected.lower():
        fail(f"Moonfall SHA-256 mismatch: expected {expected.lower()}, got {actual}")
    print(f"Copying verified canonical Moonfall -> {output.relative_to(ROOT)}")
    shutil.copyfile(source, output)


def canonical_moonfall_is_ready(place: dict) -> bool:
    manifest = load_json(ROOT / place["canonicalManifest"])
    return manifest.get("ready") is True


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--allow-incomplete-moonfall",
        action="store_true",
        help="build only reproducible Places while retaining the Moonfall guard",
    )
    args = parser.parse_args()
    config = load_json(CONFIG_PATH)
    places = config.get("places")
    if not isinstance(places, list) or [p.get("key") for p in places] != ["ruins", "moonfall", "lobby"]:
        fail("production place order must be ruins, moonfall, lobby")

    moonfall = next(place for place in places if place["key"] == "moonfall")
    if not canonical_moonfall_is_ready(moonfall) and not args.allow_incomplete_moonfall:
        fail("Moonfall canonical authored-place guard is closed (ready must be true)")

    verify_rojo()
    shutil.rmtree(OUTPUT_DIR, ignore_errors=True)
    OUTPUT_DIR.mkdir(parents=True)
    incomplete = False
    for place in places:
        output = OUTPUT_DIR / place["artifact"]
        if place["key"] == "moonfall":
            try:
                copy_canonical_moonfall(place, output)
            except SystemExit:
                if not args.allow_incomplete_moonfall:
                    raise
                incomplete = True
                print("Moonfall: BLOCKED — canonical authored-place artifact is not ready")
        else:
            build_project(ROOT / place["project"], output)

    for artifact in OUTPUT_DIR.glob("*.rbxlx"):
        if artifact.stat().st_size == 0:
            fail(f"generated artifact is empty: {artifact.relative_to(ROOT)}")
    if incomplete:
        print("Safe Place builds passed; full production artifact set remains BLOCKED")
    else:
        print("All production artifacts built and validated")


if __name__ == "__main__":
    main()
