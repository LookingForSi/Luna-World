#!/usr/bin/env python3
"""Build immutable production Place artifacts without publishing them."""

from __future__ import annotations

import hashlib
import json
import tempfile
import xml.etree.ElementTree as ET

from moonfall_overlay import MANAGED_PATHS, child, overlay_place, serialized_item
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


def canonical_moonfall_source(place: dict) -> Path:
    manifest_path = ROOT / place["canonicalManifest"]
    manifest = load_json(manifest_path)
    if manifest.get("ready") is not True:
        fail("Moonfall canonical authored-place guard is closed (ready must be true)")
    source = (manifest_path.parent / str(manifest.get("artifact", ""))).resolve()
    if source != (ROOT / "tools/worldgen/moonfall-current-accepted.rbxlx").resolve():
        fail("unexpected canonical Moonfall source path")
    if manifest.get("sourcePlaceId") != place["placeId"]:
        fail("Moonfall source Place ID does not match deployment")
    if manifest.get("gameVersion") != (ROOT / "VERSION").read_text().strip():
        fail("Moonfall manifest gameVersion does not match VERSION")
    expected = manifest.get("sha256")
    if not source.is_file() or source.stat().st_size == 0:
        fail("canonical Moonfall artifact is missing or empty")
    if not isinstance(expected, str) or len(expected) != 64:
        fail("Moonfall manifest must contain a full SHA-256 digest")
    actual = hashlib.sha256(source.read_bytes()).hexdigest()
    if actual != expected.lower():
        fail(f"Moonfall SHA-256 mismatch: expected {expected.lower()}, got {actual}")
    print(f"Canonical Moonfall SHA-256: {actual}")
    return source


def build_moonfall(source: Path, output: Path, donor: Path) -> None:
    build_project(ROOT / "projects/moonfall.project.json", donor)
    source_document = source.read_bytes()
    root = ET.fromstring(source_document)
    # Preserve the exact Studio serialization, not merely equivalent XML values.
    preserved = {name: serialized_item(source_document, child(root, name))
                 for name in ("Workspace", "Lighting")}
    try:
        overlay_place(source, donor, output)
    except ValueError as error:
        fail(str(error))
    output_document = output.read_bytes()
    root = ET.fromstring(output_document)
    for path in MANAGED_PATHS:
        parent = root
        for name in path:
            parent = child(parent, name)
            if parent is None:
                fail(f"missing production code root: {'/'.join(path)}")
    build_info = child(child(child(root, "ReplicatedStorage"), "Shared"), "config")
    build_info = child(build_info, "BuildInfo")
    if build_info.findtext("Properties/*[@name='Source']") != (ROOT / "src/shared/config/BuildInfo.luau").read_text(encoding="utf-8"):
        fail("output BuildInfo differs from Git-managed release metadata")
    for name, payload in preserved.items():
        if serialized_item(output_document, child(root, name)) != payload:
            fail(f"accepted {name} serialization changed during production overlay")
    print("Moonfall: accepted Workspace/Terrain and Lighting bytes preserved; current Git code applied")


def main() -> None:
    config = load_json(CONFIG_PATH)
    places = config.get("places")
    if not isinstance(places, list) or [p.get("key") for p in places] != ["ruins", "moonfall", "lobby"]:
        fail("production place order must be ruins, moonfall, lobby")
    source = canonical_moonfall_source(places[1])
    verify_rojo()
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    # Stage the entire set before replacing outputs; never expose partial builds.
    with tempfile.TemporaryDirectory(dir=OUTPUT_DIR, prefix="build-") as temporary:
        stage = Path(temporary)
        for place in places:
            output = stage / place["artifact"]
            if place["key"] == "moonfall":
                build_moonfall(source, output, stage / "moonfall-code.rbxlx")
            else:
                build_project(ROOT / place["project"], output)
            if output.stat().st_size == 0:
                fail(f"generated artifact is empty: {place['artifact']}")
        for place in places:
            output = OUTPUT_DIR / place["artifact"]
            (stage / place["artifact"]).replace(output)
            print(f"{output.name}: {output.stat().st_size} bytes")
    print("All production artifacts built and validated")


if __name__ == "__main__":
    main()
