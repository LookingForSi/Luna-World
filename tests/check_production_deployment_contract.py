import json
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
assert manifest["ready"] is False
assert manifest["sha256"] is None
assert "ready must be true" in build
assert "SHA-256 mismatch" in build
assert 'os.environ.get("ROBLOX_API_KEY")' in publish
assert '"versionType": "Published"' in publish

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
