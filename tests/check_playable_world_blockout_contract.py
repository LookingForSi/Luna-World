from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

REQUIRED_FILES = [
    ROOT / "src/server/world/TerrainGrounding.luau",
    ROOT / "src/server/world/BlockoutPrimitives.luau",
    ROOT / "src/server/world/VillageAndMeadowsBlockout.luau",
    ROOT / "src/server/world/NorthernZonesBlockout.luau",
    ROOT / "src/server/world/GoblinCemeteryLakeTerrain.luau",
    ROOT / "src/server/world/WorldDressingBlockout.luau",
    ROOT / "src/server/world/WorldCompositionBlockout.luau",
    ROOT / "src/server/world/PlayableWorldBlockout.luau",
    ROOT / "src/server/world/WorldBootstrap.server.luau",
    ROOT / "src/server/world/TraversalRecovery.luau",
    ROOT / "src/client/world-preview/ZonePresentation.client.luau",
]


def read(path: Path) -> str:
    assert path.exists(), f"missing required playable-blockout file: {path.relative_to(ROOT)}"
    return path.read_text(encoding="utf-8")


def main() -> None:
    for path in REQUIRED_FILES:
        read(path)

    project = read(ROOT / "world.project.json")
    assert '"$path": "src/server/world"' in project
    assert '"$path": "src/client/world-preview"' in project

    primitives = read(ROOT / "src/server/world/BlockoutPrimitives.luau")
    for token in (
        "embedDepth",
        "paintTerrainStrip",
        "replaceTerrainMaterials",
        "Enum.Material.LeafyGrass",
    ):
        assert token in primitives

    grounding = read(ROOT / "src/server/world/TerrainGrounding.luau")
    assert "Workspace.Terrain" in grounding
    assert "workspace:Raycast" not in grounding  # use explicit Workspace service consistently
    assert "Workspace:Raycast" in grounding
    assert "Enum.RaycastFilterType.Include" in grounding
    for token in (
        "treeSurfaceAt",
        "treeParams.IgnoreWater = false",
        "TREE_MIN_NORMAL_Y",
        "Enum.Material.Grass",
        "Enum.Material.LeafyGrass",
    ):
        assert token in grounding

    bootstrap = read(ROOT / "src/server/world/WorldBootstrap.server.luau")
    assert "PlayableWorldBlockout" in bootstrap
    assert "WorldGreyboxBuilder" not in bootstrap
    assert "TraversalRecovery" in bootstrap
    assert "suppressTemplateBaseplate" in bootstrap
    assert "baseplate.CanCollide = false" in bootstrap

    builder = read(ROOT / "src/server/world/PlayableWorldBlockout.luau")
    assert 'TerrainRevision", "terrain-v11"' in builder
    for boundary in ("WestBoundary", "EastBoundary", "SouthBoundary", "NorthBoundary"):
        assert boundary in builder
    assert "WorldDressingBlockout" in builder
    assert "WorldCompositionBlockout" in builder

    south = read(ROOT / "src/server/world/VillageAndMeadowsBlockout.luau")
    for token in (
        "LunaVillage",
        "VillagePalisadeNorthWest",
        "VillagePalisadeSouth",
        "MoonfallFarm",
        "Sheep%02d",
        "YoungWolf01",
        "RiverAndBridge",
        "RiverSandApproachWest",
        "RiverSandApproachEast",
        "CFrame.lookAt",
        "BridgeApproachSouth",
        "BridgeBankApronSouth",
        "BridgeBankApronNorth",
        "StoneCircle",
        "LunaVillageSpawn",
        "Vector3.new(-34, 0, -8)",
        'FenceCollision = true',
        'string.format("Collision_%02d", index)',
        "postSpacing = 4.0",
        "PalisadeCollision = true",
        'string.format("PalisadeCollision_%03d", index)',
    ):
        assert token in south
    assert "BillboardGui" not in south
    assert "EarlySpiderPocket" not in south
    assert "WaterRecovery" not in south
    assert "Enum.Material.Water" in south
    assert "spawn_spider_meadow_pocket" not in south


    recovery = read(ROOT / "src/server/world/TraversalRecovery.luau")
    assert "WaterRecovery" not in recovery
    assert "fellIntoRiver" not in recovery
    assert "or swimming" not in recovery
    for token in (
        "lastSafe",
        "FALL_RECOVERY_Y",
        "FloorMaterial",
        "character:PivotTo",
        "Terrain water is valid traversal",
    ):
        assert token in recovery

    north = read(ROOT / "src/server/world/NorthernZonesBlockout.luau")
    for token in (
        "MoonfallRoad",
        "GoblinCamp",
        "createCampPalisadeLine",
        "gateHalfWidth = 32",
        '"CampPalisade%02d"',
        '"Foundation"',
        "SpiderHollow",
        "prepareSpiderHollowTerrain",
        "BasinFloorFilled",
        "fillCurvedRidge",
        "northRidge",
        "southRidge",
        "terrain:FillCylinder",
        "floorHalfLength = 170",
        "floorRadius = 135",
        "createSpiderWeb",
        "Enum.Material.Mud",
        "GoblinCemeteryLake",
        "GoblinCemeteryLakeTerrain.build(lake)",
        '"Purpose", "SwimmableWater"',
        "DarkWoodlandThreshold",
        "OldCemetery",
        "FallenShrine",
        "AncientApproach",
        "SeleneGateLeft",
    ):
        assert token in north
    assert "BillboardGui" not in north
    assert "WaterRecovery" not in north
    assert "Enum.Material.Glass" not in north
    assert "prepareGoblinCampBoundaryShelf" not in north
    assert "fillFlatLakeSlab" not in north
    assert "fillContinuousLakePath" not in north
    assert "LakeBedFilled" not in north
    assert "Enum.Material.Mud" in north
    assert "postSpacing = 4.0" in north
    assert "PalisadeCollision = true" in north
    assert "fenceSegments" in north
    assert "Grounding.treeSurfaceAt(position)" in north
    assert "for index = 1, 11 do" in north

    lake_terrain = read(ROOT / "src/server/world/GoblinCemeteryLakeTerrain.luau")
    for token in (
        "WATER_DEPTH = 14",
        "SCANLINE_STEP = 12",
        "SCANLINE_OVERLAP = 2",
        "WATER_SHORE_OVERLAP = 6",
        "BED_THICKNESS = 6",
        "BED_WATER_OVERLAP = 2",
        "WATER_SURFACE_Y = 74",
        "resetLegacyCorridor(terrain)",
        "intersectionsAt",
        "Enum.Material.Air",
        "Enum.Material.Mud",
        "Enum.Material.Water",
        'LakeGeometry", "AxisAlignedPolygonScanlines"',
        'ContainedWithinWorldBounds", true',
    ):
        assert token in lake_terrain
    assert "FillCylinder" not in lake_terrain
    assert "CFrame.Angles" not in lake_terrain

    for removed_square_rim in (
        "SpiderBasinRimWest",
        "SpiderBasinRimSouth",
        "SpiderBasinRimNorth",
        "SpiderBasinRimEastSouth",
        "SpiderBasinRimEastNorth",
    ):
        assert removed_square_rim not in north


    dressing = read(ROOT / "src/server/world/WorldDressingBlockout.luau")
    for token in (
        "EnvironmentDressing",
        "VillageRetainingWallWest",
        "FarmRoadFenceA",
        "SpiderApproachStumpA",
        "SpiderApproachRocks",
        "GoblinSupplyCrates",
        "SpiderDeadTree",
        "CemeteryBoundarySouth",
        "ShrineRubble",
        "ApproachRuinedWallLeft",
        'ArtReplacementTarget", "BlenderModularKits"',
    ):
        assert token in dressing
    assert "MobPlaceholder" not in dressing
    assert "spawn_spider_meadow_pocket" not in dressing
    assert "Grounding.treeSurfaceAt(position)" in dressing

    composition = read(ROOT / "src/server/world/WorldCompositionBlockout.luau")
    assert "GoblinShelfEdge" in composition
    for token in (
        "MacroComposition",
        "VillageHillComposition",
        "FarmAndMeadowsComposition",
        "CombatBlockComposition",
        "UpperValleyComposition",
        "VillageWestTreeBelt",
        "WolfRiverMixedForest",
        "WolfGoblinMixedForest",
        "MeadowHillScree",
        "MoonfallWestScreen",
        "GoblinCemeteryEastForest",
        "GoblinCemeteryRoadsideForest",
        "SpiderBasinRearDeadwood",
        "DarkWoodlandWestMass",
        "CemeteryRearDeadwood",
        "ShrinePromontoryRocks",
        "shapeFallenShrineSouthCliff",
        "FallenShrineCliffScree",
        "ApproachOuterPillarLeft",
        "BlenderStudioAssetPass",
    ):
        assert token in composition
    assert "MobPlaceholder" not in composition
    assert "FarmFieldRow" not in composition
    assert "createCliffWall" not in composition
    assert composition.count("Grounding.treeSurfaceAt(position)") >= 2
    assert '"DarkWoodlandWestMass"' in composition and "\n\t\t15,\n\t\t45\n" in composition

    assert "solidCollision: boolean?" in dressing
    assert "FarmRoadFenceA" in dressing and "FarmRoadFenceB" in dressing
    assert dressing.count("FenceCollision = true") >= 1

    presentation = read(ROOT / "src/client/world-preview/ZonePresentation.client.luau")
    assert "ZoneToast" in presentation
    assert "task.delay(2.5" in presentation
    assert "JumpPower = 0" not in presentation
    assert "JumpHeight = 0" not in presentation
    assert "LunaWorldPreviewDisableJump" not in presentation
    assert "BillboardGui" not in presentation

    layout = read(ROOT / "src/shared/world/WorldLayout.luau")
    for token in (
        "zone_dark_woodland",
        "zone_old_cemetery",
        "zone_fallen_shrine",
        "zone_ancient_approach",
        "poi_moonfall_farm",
        "poi_young_wolf_staging",
        "spawn_young_wolf_farm",
        "poi_old_cemetery",
        "poi_fallen_shrine",
        "poi_ancient_approach",
        "AncientApproachRoute",
    ):
        assert token in layout

    plan = read(ROOT / "docs/superpowers/plans/2026-09-19-playable-world-blockout-pass.md")
    assert "owner traversal" in plan.lower()
    assert "Moonfall Farm" in plan
    assert "no-jump" in plan

    print("playable world blockout contract: PASS")


if __name__ == "__main__":
    main()
