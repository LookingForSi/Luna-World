from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]

GENERATOR_SOURCE_NAMES = {
    "BlockoutPrimitives.luau",
    "NorthernZonesBlockout.luau",
    "PlayableWorldBlockout.luau",
    "VillageAndMeadowsBlockout.luau",
    "WorldBootstrap.luau",
    "WorldCompositionBlockout.luau",
    "WorldDressingBlockout.luau",
}

for project_name in ("lobby", "moonfall", "dungeon-selene"):
    project_path = ROOT / "projects" / f"{project_name}.project.json"
    data = json.loads(project_path.read_text(encoding="utf-8"))
    server_scripts = data["tree"]["ServerScriptService"]
    assert "Worldgen" not in server_scripts, f"{project_name} must not map dev worldgen"
    raw = project_path.read_text(encoding="utf-8")
    assert "tools/worldgen" not in raw
    assert "server-world-preview" not in raw

runtime_world = ROOT / "src/server/world"
for name in GENERATOR_SOURCE_NAMES:
    assert not (runtime_world / name).exists(), f"production server source still contains generator {name}"
assert (runtime_world / "TraversalRecovery.luau").exists()
assert (runtime_world / "TerrainGrounding.luau").exists()

default = json.loads((ROOT / "default.project.json").read_text(encoding="utf-8"))
dev_combined = json.loads((ROOT / "projects/dev-combined.project.json").read_text(encoding="utf-8"))
for project in (default, dev_combined):
    worldgen = project["tree"]["ServerScriptService"]["Worldgen"]
    assert worldgen["Moonfall"]["$path"].endswith("tools/worldgen/moonfall")
    assert worldgen["WorldBootstrap"]["$path"].endswith("tools/worldgen/WorldBootstrap.luau")

authoring = json.loads((ROOT / "projects/moonfall-authoring.project.json").read_text(encoding="utf-8"))
authoring_root = authoring["tree"]["ServerStorage"]["MoonfallAuthoring"]
assert authoring_root["Moonfall"]["$path"] == "../tools/worldgen/moonfall"
assert authoring_root["Bake"]["$path"] == "../tools/worldgen/bake/MoonfallBake.luau"

world_manifest = (ROOT / "src/server/bootstrap/manifests/WorldServerManifest.luau").read_text(encoding="utf-8")
assert "Components.moonfallWorldRuntime()" in world_manifest
assert "Components.worldBootstrap()" not in world_manifest

runtime = (ROOT / "src/server/features/world/MoonfallWorldRuntime.luau").read_text(encoding="utf-8")
assert "PlayableWorldBlockout" not in runtime
assert ".rebuild(" not in runtime
assert "Contract.AuthoredManagedBy" in runtime
assert "Contract.TerrainRevision" in runtime
assert "TraversalRecovery.start(root, spawn)" in runtime
assert "TraversalRecovery.stop()" in runtime

bake = (ROOT / "tools/worldgen/bake/MoonfallBake.luau").read_text(encoding="utf-8")
assert "RunService:IsStudio()" in bake
assert "Contract.BakeConfirmation" in bake
assert "Contract.AuthoredManagedBy" in bake
assert "Builder.rebuild()" in bake

builder = (ROOT / "tools/worldgen/moonfall/PlayableWorldBlockout.luau").read_text(encoding="utf-8")
assert "Contract.GeneratorManagedBy" in builder
assert "Contract.TerrainRevision" in builder

north = (ROOT / "tools/worldgen/moonfall/NorthernZonesBlockout.luau").read_text(encoding="utf-8")
assert "lake generation is intentionally disabled" in north
assert "\n\tcreateGoblinCemeteryLake(north, positions)\n" not in north

layout = (ROOT / "src/shared/world/WorldLayout.luau").read_text(encoding="utf-8")
for stable_id in (
    "poi_moonfall_farm",
    "poi_old_cemetery",
    "poi_fallen_shrine",
    "poi_ancient_approach",
    "spawn_young_wolf_farm",
    "spawn_goblin_chieftain_camp",
    "spawn_moonbound_warden",
):
    assert stable_id in layout, f"stable world ID disappeared: {stable_id}"

print("Production worldgen exclusion and Moonfall authoring contract: PASS")
