from __future__ import annotations

import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "tools" / "worldgen" / "world_v01.json"

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


def main() -> None:
    data = json.loads(SOURCE.read_text(encoding="utf-8"))

    assert data["version"] == 1
    assert data["worldScaleXZ"] == 2.0
    assert data["resolution"] == {"width": 650, "height": 1200}

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

    disabled_spawns = {entry["id"] for entry in data["spawns"] if not entry["spawnEnabled"]}
    assert "spawn_goblin_camp_elite_future" in disabled_spawns
    assert "spawn_spider_hollow_brood" in disabled_spawns

    print("worldgen contract: PASS")


if __name__ == "__main__":
    main()
