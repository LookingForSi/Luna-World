import json
import hashlib
import sys
import tempfile
from unittest.mock import patch
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
config = json.loads((ROOT / "tools/deploy/production.json").read_text(encoding="utf-8"))
workflow = (ROOT / ".github/workflows/roblox-deploy.yml").read_text(encoding="utf-8")
build = (ROOT / "tools/deploy/build.py").read_text(encoding="utf-8")
publish = (ROOT / "tools/deploy/publish.py").read_text(encoding="utf-8")
manifest = json.loads((ROOT / "deploy/canonical/moonfall.manifest.json").read_text(encoding="utf-8"))

assert config["universeId"] == "10767283011"
assert [(place["key"], place["placeId"]) for place in config["places"]] == [
    ("ruins", "72524197323645"),
    ("moonfall", "133570003635782"),
    ("lobby", "81197415020315"),
]
serialized = json.dumps(config).lower()
for forbidden in ("dev-combined", "tests.project", "test.project", "moonfall-authoring"):
    assert forbidden not in serialized
assert config["places"][-1]["key"] == "lobby"
assert "project" not in config["places"][1], "Moonfall must not be a code-only Rojo build"
assert config["places"][1]["canonicalManifest"] == "deploy/canonical/moonfall.manifest.json"
assert manifest["ready"] is True
assert manifest["artifact"] == "../../tools/worldgen/moonfall-current-accepted.rbxlx"
assert manifest["sha256"] == "e7346cdc211c6e1e1e41df8f258d7537b751f4a93402448d53ad049c935cd9ba"
assert hashlib.sha256((ROOT / "tools/worldgen/moonfall-current-accepted.rbxlx").read_bytes()).hexdigest() == manifest["sha256"]
assert not (ROOT / "deploy/canonical/moonfall.rbxlx").exists()
assert "allow-incomplete-moonfall" not in build
assert "ready must be true" in build
assert "SHA-256 mismatch" in build
assert 'os.environ.get("ROBLOX_API_KEY")' in publish
assert '"versionType": "Published"' in publish

# Source validation must fail before invoking Rojo, including tampered bytes.
sys.path.insert(0, str(ROOT / "tools/deploy"))
import build as deployment_build

with tempfile.TemporaryDirectory() as directory:
    fixture = Path(directory)
    manifest_path = fixture / "deploy/canonical/moonfall.manifest.json"
    manifest_path.parent.mkdir(parents=True)
    source = fixture / "tools/worldgen/moonfall-current-accepted.rbxlx"
    source.parent.mkdir(parents=True)
    source.write_bytes(b"accepted fixture")
    (fixture / "VERSION").write_text("0.1.0")
    valid = dict(manifest, sha256=hashlib.sha256(source.read_bytes()).hexdigest())
    with patch.object(deployment_build, "ROOT", fixture):
        for changes, reason in [
            ({"sha256": "0" * 64}, "SHA-256 mismatch"),
            ({"ready": False}, "ready must be true"),
            ({"artifact": "moonfall.rbxlx"}, "source path"),
            ({"sourcePlaceId": "1"}, "Place ID"),
            ({"gameVersion": "0.0.0"}, "gameVersion"),
        ]:
            manifest_path.write_text(json.dumps(dict(valid, **changes)), encoding="utf-8")
            try:
                deployment_build.canonical_moonfall_source(config["places"][1])
            except SystemExit as error:
                assert reason in str(error)
            else:
                raise AssertionError(f"accepted invalid manifest: {changes}")
        manifest_path.write_text(json.dumps(valid), encoding="utf-8")
        assert deployment_build.canonical_moonfall_source(config["places"][1]) == source.resolve()

trigger_section = workflow.split("permissions:", 1)[0]
assert "workflow_dispatch:" in trigger_section
assert "push:" not in trigger_section
assert "pull_request:" not in trigger_section
assert "environment: ROBLOX_API_KEY" in workflow
assert "ROBLOX_API_KEY: ${{ secrets.ROBLOX_API_KEY }}" in workflow
assert "needs: validate-and-build" in workflow
assert "refs/heads/main" in workflow and "refs/tags/v" in workflow
assert "Publish Ruins, Moonfall, then Lobby" in workflow
print("Production deployment IDs, order, manual trigger, secret, and Moonfall guard: PASS")
