import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ROLE_PROJECTS = ("lobby", "moonfall", "dungeon-selene", "dev-combined", "tests")
CANONICAL_ROOT_PROJECTS = (
    "default.project.json",
    "test.project.json",
    "world.project.json",
    "world.test.project.json",
)


def collect_paths(node):
    if isinstance(node, dict):
        if "$path" in node:
            yield node["$path"]
        for value in node.values():
            yield from collect_paths(value)
    elif isinstance(node, list):
        for value in node:
            yield from collect_paths(value)


projects = [ROOT / name for name in CANONICAL_ROOT_PROJECTS]
projects.extend(sorted((ROOT / "projects").glob("*.project.json")))
project_names = {path.stem.removesuffix(".project") for path in projects if path.parent.name == "projects"}
assert set(ROLE_PROJECTS).issubset(project_names)

for project in projects:
    data = json.loads(project.read_text())
    for relative_path in collect_paths(data):
        resolved = (project.parent / relative_path).resolve()
        assert resolved.exists(), f"{project.relative_to(ROOT)} has missing $path {relative_path} ({resolved})"

for name in ROLE_PROJECTS:
    data = json.loads((ROOT / "projects" / f"{name}.project.json").read_text())
    assert data["tree"]["ReplicatedStorage"]["Shared"]["$path"] == "../src/shared"

studio_roles = {
    "dev-combined": "DevCombined",
    "lobby": "Lobby",
    "moonfall": "World",
    "dungeon-selene": "Dungeon",
}
for name, expected_role in studio_roles.items():
    data = json.loads((ROOT / "projects" / f"{name}.project.json").read_text())
    marker = data["tree"]["ReplicatedStorage"]["StudioPlaceRole"]
    assert marker["$className"] == "StringValue"
    assert marker["$properties"]["Value"] == expected_role

lobby_manifest = (ROOT / "src/server/bootstrap/manifests/LobbyServerManifest.luau").read_text()
assert "Components.character()" in lobby_manifest
assert "Components.combat()" not in lobby_manifest
assert "Components.mobs()" not in lobby_manifest
assert "Components.worldBootstrap()" not in lobby_manifest

world_manifest = (ROOT / "src/server/bootstrap/manifests/WorldServerManifest.luau").read_text()
assert "Components.character()" not in world_manifest
assert "Components.placeArrival" in world_manifest

dungeon_manifest = (ROOT / "src/server/bootstrap/manifests/DungeonServerManifest.luau").read_text()
for village_only_component in ("economyWorld", "npcWorld", "quests", "travel", "worldBootstrap"):
    assert f"Components.{village_only_component}(" not in dungeon_manifest

for name in ("lobby", "moonfall", "dungeon-selene"):
    production_mapping = (ROOT / "projects" / f"{name}.project.json").read_text()
    assert "server-world-preview" not in production_mapping
    assert "world-preview" not in production_mapping

config = (ROOT / "src/shared/config/PlaceConfig.luau").read_text()
assert "gameId = 10767283011" in config
assert "[81197415020315] = PlaceRole.Lobby" in config
assert "[133570003635782] = PlaceRole.World" in config
assert "local deployments: { Deployment } = {}" not in config
assert "StudioDefaultRole = PlaceRole.DevCombined" in config
print("Place project mappings, Studio roles, role boundaries, and fail-closed test deployment config: PASS")
