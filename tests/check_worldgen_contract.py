from __future__ import annotations

import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "tools" / "worldgen" / "world_v01.json"

sys.path.insert(0, str(ROOT))
from tools.worldgen.generate_world import generate_height  # noqa: E402

REQUIRED_POIS = {
    "poi_main_gate",
    "poi_village_square",
    "poi_moonfall_farm",
    "poi_meadow_bridge",
    "poi_stone_circle",
    "exit_moonfall_road",
    "poi_moonfall_crossroads",
    "poi_goblin_camp",
    "poi_spider_hollow",
    "entry_dark_woodland",
}

REQUIRED_ROUTES = {"main", "moonfall", "goblin", "spider", "spider_return"}


def max_slope_degrees(points: list[list[float]]) -> float:
    result = 0.0
    for first, second in zip(points[:-1], points[1:]):
        horizontal = math.hypot(second[0] - first[0], second[2] - first[2])
        slope = math.degrees(math.atan2(abs(second[1] - first[1]), horizontal))
        result = max(result, slope)
    return result


def sample_height(height, data: dict, x: float, z: float) -> float:
    bounds = data["boundsStuds"]
    resolution = data["resolution"]
    px = round((x - bounds["minX"]) / (bounds["maxX"] - bounds["minX"]) * (resolution["width"] - 1))
    pz = round((z - bounds["minZ"]) / (bounds["maxZ"] - bounds["minZ"]) * (resolution["height"] - 1))
    return float(height[pz, px])


def radial_average(height, data: dict, center: list[float], radius: float) -> float:
    values = []
    for index in range(24):
        angle = 2.0 * math.pi * index / 24.0
        x = center[0] + math.cos(angle) * radius
        z = center[2] + math.sin(angle) * radius
        values.append(sample_height(height, data, x, z))
    return sum(values) / len(values)


def main() -> None:
    data = json.loads(SOURCE.read_text(encoding="utf-8"))

    assert data["version"] == 1
    assert data["worldScaleXZ"] == 2.0
    assert data["resolution"] == {"width": 650, "height": 1200}
    assert data["heightRangeStuds"] == [0, 192]
    assert data["artifactRevision"] == "terrain-v03"

    bounds = data["boundsStuds"]
    assert bounds["maxX"] - bounds["minX"] == 2600
    assert bounds["maxZ"] - bounds["minZ"] == 4800

    poi_ids = {entry["id"] for entry in data["pois"]}
    assert REQUIRED_POIS <= poi_ids
    assert REQUIRED_ROUTES == set(data["routes"])

    assert max_slope_degrees(data["routes"]["main"]) <= 12.0
    assert max_slope_degrees(data["routes"]["moonfall"]) <= 12.0
    assert max_slope_degrees(data["routes"]["goblin"]) <= 18.0
    assert max_slope_degrees(data["routes"]["spider"]) <= 18.0
    assert max_slope_degrees(data["routes"]["spider_return"]) <= 18.0

    bridge_id = data["features"]["river"]["bridgePoiId"]
    assert bridge_id == "poi_meadow_bridge"

    landforms = {entry["id"]: entry for entry in data["features"]["macroLandforms"]}
    assert "village_hill" in landforms
    assert "selene_horizon_massif" in landforms
    assert landforms["village_hill"]["amplitude"] >= 45
    assert landforms["village_hill"]["sigmaXZ"][0] >= 600
    assert landforms["selene_horizon_massif"]["amplitude"] >= 70
    assert landforms["selene_horizon_massif"]["centerXZ"][1] > bounds["maxZ"]

    village_pad = next(entry for entry in data["features"]["terrainPads"] if entry["id"] == "village_core")
    assert village_pad["targetY"] >= 55
    assert village_pad["radiusStuds"] >= 180

    terrain_pads = {entry["id"]: entry for entry in data["features"]["terrainPads"]}
    assert terrain_pads["goblin_camp"]["mode"] == "raise"
    assert terrain_pads["goblin_camp"]["targetY"] >= 65
    assert terrain_pads["spider_hollow"]["mode"] == "lower"
    assert terrain_pads["spider_hollow"]["targetY"] <= 4

    rings = {entry["id"]: entry for entry in data["features"]["localRings"]}
    assert "goblin_camp_outer_rampart" not in rings
    assert rings["spider_hollow_rim"]["amplitude"] >= 18

    future = {entry["id"]: entry for entry in data["features"]["futureTerrainReservations"]}
    assert future["future_old_cemetery"]["terrainIntent"] == "raised_terrace"
    assert future["future_fallen_shrine"]["terrainIntent"] == "raised_promontory"
    assert future["future_old_cemetery"]["mode"] == "raise"
    assert future["future_fallen_shrine"]["mode"] == "raise"
    assert future["future_old_cemetery"]["targetY"] >= 120
    assert future["future_fallen_shrine"]["targetY"] >= 125
    assert bounds["maxZ"] - future["future_old_cemetery"]["center"][2] >= 350
    assert bounds["maxZ"] - future["future_fallen_shrine"]["center"][2] >= 350

    zone_ids = {entry["id"] for entry in data["zones"]}
    assert "zone_old_cemetery" not in zone_ids
    assert "zone_fallen_shrine" not in zone_ids

    disabled_spawns = {entry["id"] for entry in data["spawns"] if not entry["spawnEnabled"]}
    assert "spawn_goblin_camp_elite_future" in disabled_spawns
    assert "spawn_spider_hollow_brood" in disabled_spawns

    height, _ = generate_height(data)

    goblin = terrain_pads["goblin_camp"]
    goblin_center = sample_height(height, data, goblin["center"][0], goblin["center"][2])
    goblin_outer = radial_average(height, data, goblin["center"], goblin["radiusStuds"] + 100)
    assert goblin_center >= goblin_outer + 4.0

    spider = terrain_pads["spider_hollow"]
    spider_center = sample_height(height, data, spider["center"][0], spider["center"][2])
    spider_rim = radial_average(height, data, spider["center"], spider["radiusStuds"] + 100)
    assert spider_center <= spider_rim - 8.0

    cemetery = future["future_old_cemetery"]
    cemetery_center = sample_height(height, data, cemetery["center"][0], cemetery["center"][2])
    cemetery_outer = radial_average(height, data, cemetery["center"], cemetery["radiusStuds"] + 100)
    assert cemetery_center >= cemetery_outer + 8.0

    shrine = future["future_fallen_shrine"]
    shrine_center = sample_height(height, data, shrine["center"][0], shrine["center"][2])
    shrine_outer = radial_average(height, data, shrine["center"], shrine["radiusStuds"] + 100)
    assert shrine_center >= shrine_outer + 8.0

    print("worldgen contract: PASS")


if __name__ == "__main__":
    main()
