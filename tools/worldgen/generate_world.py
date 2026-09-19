from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


def smooth01(value: np.ndarray) -> np.ndarray:
    clipped = np.clip(value, 0.0, 1.0)
    return clipped * clipped * (3.0 - 2.0 * clipped)


def load_source(path: Path) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    if data.get("version") != 1:
        raise ValueError("world source version must be 1")
    if data.get("worldScaleXZ") != 2.0:
        raise ValueError("v0.1 production world currently requires worldScaleXZ=2.0")
    return data


def build_axis(source: dict) -> tuple[np.ndarray, np.ndarray]:
    bounds = source["boundsStuds"]
    resolution = source["resolution"]
    xs = np.linspace(bounds["minX"], bounds["maxX"], resolution["width"], dtype=np.float32)
    zs = np.linspace(bounds["minZ"], bounds["maxZ"], resolution["height"], dtype=np.float32)
    return xs, zs


def gaussian(
    x_grid: np.ndarray,
    z_grid: np.ndarray,
    cx: float,
    cz: float,
    sx: float,
    sz: float,
    amplitude: float,
) -> np.ndarray:
    return amplitude * np.exp(-(((x_grid - cx) / sx) ** 2 + ((z_grid - cz) / sz) ** 2) / 2.0)

def gaussian_ring(
    x_grid: np.ndarray,
    z_grid: np.ndarray,
    cx: float,
    cz: float,
    radius: float,
    sigma: float,
    amplitude: float,
) -> np.ndarray:
    distance = np.sqrt((x_grid - cx) ** 2 + (z_grid - cz) ** 2)
    return amplitude * np.exp(-((distance - radius) / sigma) ** 2 / 2.0)


def blend_pad(height: np.ndarray, xs: np.ndarray, zs: np.ndarray, pad: dict) -> None:
    cx, _, cz = pad["center"]
    radius = float(pad["radiusStuds"])
    blend = float(pad["blendStuds"])
    target = float(pad["targetY"])
    mode = pad.get("mode", "set")

    min_x, max_x = cx - radius - blend, cx + radius + blend
    min_z, max_z = cz - radius - blend, cz + radius + blend
    ix0 = max(0, int(np.searchsorted(xs, min_x)) - 1)
    ix1 = min(len(xs), int(np.searchsorted(xs, max_x)) + 1)
    iz0 = max(0, int(np.searchsorted(zs, min_z)) - 1)
    iz1 = min(len(zs), int(np.searchsorted(zs, max_z)) + 1)

    xx = xs[ix0:ix1][None, :]
    zz = zs[iz0:iz1][:, None]
    distance = np.sqrt((xx - cx) ** 2 + (zz - cz) ** 2)

    weight = 1.0 - smooth01((distance - radius) / max(blend, 1e-6))
    weight = np.where(distance <= radius, 1.0, weight)
    weight = np.where(distance >= radius + blend, 0.0, weight).astype(np.float32)

    current = height[iz0:iz1, ix0:ix1]
    candidate = current * (1.0 - weight) + target * weight

    if mode == "raise":
        result = np.maximum(current, candidate)
    elif mode == "lower":
        result = np.minimum(current, candidate)
    elif mode == "set":
        result = candidate
    else:
        raise ValueError(f"unsupported terrain pad mode: {mode}")

    height[iz0:iz1, ix0:ix1] = result


def blend_route(
    height: np.ndarray,
    xs: np.ndarray,
    zs: np.ndarray,
    points: list[list[float]],
    core: float,
    blend: float,
) -> None:
    for first, second in zip(points[:-1], points[1:]):
        ax, ay, az = first
        bx, by, bz = second

        min_x = min(ax, bx) - core - blend
        max_x = max(ax, bx) + core + blend
        min_z = min(az, bz) - core - blend
        max_z = max(az, bz) + core + blend

        ix0 = max(0, int(np.searchsorted(xs, min_x)) - 1)
        ix1 = min(len(xs), int(np.searchsorted(xs, max_x)) + 1)
        iz0 = max(0, int(np.searchsorted(zs, min_z)) - 1)
        iz1 = min(len(zs), int(np.searchsorted(zs, max_z)) + 1)

        xx = xs[ix0:ix1][None, :]
        zz = zs[iz0:iz1][:, None]

        vx = bx - ax
        vz = bz - az
        denominator = vx * vx + vz * vz
        t = np.clip(((xx - ax) * vx + (zz - az) * vz) / denominator, 0.0, 1.0)

        nearest_x = ax + t * vx
        nearest_z = az + t * vz
        distance = np.sqrt((xx - nearest_x) ** 2 + (zz - nearest_z) ** 2)
        target = ay + t * (by - ay)

        weight = 1.0 - smooth01((distance - core) / blend)
        weight = np.where(distance <= core, 1.0, weight)
        weight = np.where(distance >= core + blend, 0.0, weight).astype(np.float32)

        current = height[iz0:iz1, ix0:ix1]
        height[iz0:iz1, ix0:ix1] = current * (1.0 - weight) + target * weight


def generate_height(source: dict) -> tuple[np.ndarray, np.ndarray]:
    xs, zs = build_axis(source)
    x_grid = xs[None, :]
    z_grid = zs[:, None]
    bounds = source["boundsStuds"]

    height = (
        10.0
        + 1.8 * np.sin(x_grid / 170.0)
        + 1.2 * np.sin(z_grid / 250.0)
        + 0.8 * np.sin((x_grid + z_grid) / 310.0)
    ).astype(np.float32)

    # Macro silhouettes are authoring data, not hard-coded terrain policy.
    for landform in source["features"]["macroLandforms"]:
        cx, cz = landform["centerXZ"]
        sx, sz = landform["sigmaXZ"]
        height += gaussian(
            x_grid,
            z_grid,
            float(cx),
            float(cz),
            float(sx),
            float(sz),
            float(landform["amplitude"]),
        )

    for ring in source["features"].get("localRings", []):
        cx, cz = ring["centerXZ"]
        height += gaussian_ring(
            x_grid,
            z_grid,
            float(cx),
            float(cz),
            float(ring["radiusStuds"]),
            float(ring["sigmaStuds"]),
            float(ring["amplitude"]),
        )

    edge_x = np.minimum(x_grid - bounds["minX"], bounds["maxX"] - x_grid)
    south_edge = z_grid - bounds["minZ"]
    north_edge = bounds["maxZ"] - z_grid

    height += 54.0 * smooth01((250.0 - edge_x) / 250.0)
    height += 38.0 * smooth01((220.0 - south_edge) / 220.0)

    north_ridge = 46.0 * smooth01((260.0 - north_edge) / 260.0)
    north_notch = 1.0 - np.exp(-(x_grid / 300.0) ** 2)
    height += north_ridge * north_notch

    for pad in source["features"]["terrainPads"]:
        blend_pad(height, xs, zs, pad)

    for reservation in source["features"].get("futureTerrainReservations", []):
        blend_pad(height, xs, zs, reservation)

    route_parameters = {
        "main": (26.0, 110.0),
        "moonfall": (24.0, 95.0),
        "goblin": (22.0, 80.0),
        "spider": (22.0, 75.0),
        "spider_return": (20.0, 70.0),
        "ancient_approach": (30.0, 120.0),
    }
    for route_name, (core, blend) in route_parameters.items():
        blend_route(height, xs, zs, source["routes"][route_name], core, blend)

    # Regular terrain must never collapse to the import floor. The river is carved after this.
    height = np.maximum(height, 4.0)

    bridge_id = source["features"]["river"]["bridgePoiId"]
    bridge = next(poi for poi in source["pois"] if poi["id"] == bridge_id)
    bridge_x, _, bridge_z = bridge["position"]

    river = source["features"]["river"]
    river_center_z = bridge_z + 0.065 * (x_grid - bridge_x) + 28.0 * np.sin((x_grid + 180.0) / 280.0)
    river_distance = np.abs(z_grid - river_center_z)

    half_width = float(river["halfWidthStuds"])
    bank_blend = float(river["bankBlendStuds"])
    bed_height = 1.5 + 0.4 * np.sin(x_grid / 240.0)

    river_weight = 1.0 - smooth01((river_distance - half_width) / bank_blend)
    river_weight = np.where(river_distance <= half_width, 1.0, river_weight)
    river_weight = np.where(river_distance >= half_width + bank_blend, 0.0, river_weight).astype(np.float32)

    height = height * (1.0 - river_weight) + np.minimum(height, bed_height) * river_weight

    low, high = source["heightRangeStuds"]
    height = np.clip(height, float(low), float(high))
    water_mask = (river_distance <= half_width).astype(np.uint8) * 255
    return height, water_mask


def world_to_pixel(source: dict, x: float, z: float) -> tuple[int, int]:
    bounds = source["boundsStuds"]
    resolution = source["resolution"]
    px = round((x - bounds["minX"]) / (bounds["maxX"] - bounds["minX"]) * (resolution["width"] - 1))
    py = round((z - bounds["minZ"]) / (bounds["maxZ"] - bounds["minZ"]) * (resolution["height"] - 1))
    return int(px), int(py)


def save_heightmap(source: dict, height: np.ndarray, output_dir: Path) -> None:
    low, high = source["heightRangeStuds"]
    encoded = np.round((height - low) / (high - low) * 65535.0)
    encoded = np.clip(encoded, 0, 65535).astype(np.uint16)
    Image.fromarray(encoded).save(output_dir / "world_v01_heightmap.png")


def save_topdown(source: dict, height: np.ndarray, water_mask: np.ndarray, output_dir: Path) -> None:
    bounds = source["boundsStuds"]
    resolution = source["resolution"]

    dz = (bounds["maxZ"] - bounds["minZ"]) / (resolution["height"] - 1)
    dx = (bounds["maxX"] - bounds["minX"]) / (resolution["width"] - 1)
    grad_z, grad_x = np.gradient(height, dz, dx)
    shade = np.clip(0.78 + (-grad_x * 0.25 - grad_z * 0.15), 0.5, 1.15)

    normalized = np.clip(height / 120.0, 0.0, 1.0)
    rgb = np.zeros((*height.shape, 3), dtype=np.float32)
    rgb[..., 0] = 82.0 + 68.0 * normalized
    rgb[..., 1] = 118.0 - 30.0 * normalized
    rgb[..., 2] = 70.0 - 15.0 * normalized

    rock = height > 78.0
    rgb[rock] = np.array([120.0, 116.0, 105.0], dtype=np.float32)
    rgb *= shade[..., None]
    rgb = np.clip(rgb, 0, 255).astype(np.uint8)
    rgb[water_mask > 0] = np.array([44, 104, 148], dtype=np.uint8)

    base = Image.fromarray(rgb, "RGB")

    route_overlay = Image.new("RGBA", base.size, (0, 0, 0, 0))
    route_draw = ImageDraw.Draw(route_overlay)
    route_colors = {
        "main": (225, 205, 155, 240),
        "moonfall": (205, 175, 125, 240),
        "goblin": (190, 115, 80, 240),
        "spider": (165, 145, 185, 240),
        "spider_return": (145, 125, 165, 210),
        "ancient_approach": (220, 210, 150, 235),
    }
    for route_name, points in source["routes"].items():
        route_draw.line(
            [world_to_pixel(source, point[0], point[2]) for point in points],
            fill=route_colors[route_name],
            width=5,
            joint="curve",
        )
    route_overlay.save(output_dir / "world_v01_routes_overlay.png")

    poi_overlay = Image.new("RGBA", base.size, (0, 0, 0, 0))
    poi_draw = ImageDraw.Draw(poi_overlay)
    for poi in source["pois"]:
        x, _, z = poi["position"]
        px, py = world_to_pixel(source, x, z)
        poi_draw.ellipse(
            (px - 4, py - 4, px + 4, py + 4),
            fill=(255, 220, 80, 255),
            outline=(20, 20, 20, 255),
        )
        poi_draw.text(
            (px + 6, py - 6),
            poi["id"].replace("poi_", ""),
            fill=(255, 255, 235, 255),
        )

    world_width = bounds["maxX"] - bounds["minX"]
    for spawn in source["spawns"]:
        x, _, z = spawn["position"]
        px, py = world_to_pixel(source, x, z)
        color = (225, 70, 70, 230) if spawn["spawnEnabled"] else (125, 125, 125, 180)
        radius_px = max(4, round(spawn["radius"] / world_width * resolution["width"]))
        poi_draw.ellipse(
            (px - radius_px, py - radius_px, px + radius_px, py + radius_px),
            outline=color,
            width=2,
        )

    for reservation in source["features"].get("futureTerrainReservations", []):
        x, _, z = reservation["center"]
        px, py = world_to_pixel(source, x, z)
        radius_px = max(
            5,
            round(reservation["radiusStuds"] / world_width * resolution["width"]),
        )
        poi_draw.ellipse(
            (px - radius_px, py - radius_px, px + radius_px, py + radius_px),
            outline=(180, 120, 230, 220),
            width=2,
        )
        poi_draw.text(
            (px + radius_px + 4, py - 7),
            reservation["displayName"] + " (future)",
            fill=(230, 205, 255, 235),
        )

    poi_overlay.save(output_dir / "world_v01_poi_spawn_overlay.png")

    zone_overlay = Image.new("RGBA", base.size, (0, 0, 0, 0))
    zone_draw = ImageDraw.Draw(zone_overlay)
    for zone in source["zones"]:
        cx, _, cz = zone["center"]
        sx, _, sz = zone["size"]
        p0 = world_to_pixel(source, cx - sx / 2.0, cz - sz / 2.0)
        p1 = world_to_pixel(source, cx + sx / 2.0, cz + sz / 2.0)
        zone_draw.rectangle(
            (p0[0], p0[1], p1[0], p1[1]),
            outline=(230, 230, 230, 130),
            width=2,
        )
        zone_draw.text(
            (p0[0] + 4, p0[1] + 4),
            zone["displayName"],
            fill=(245, 245, 245, 210),
        )
    zone_overlay.save(output_dir / "world_v01_zones_overlay.png")

    composite = Image.alpha_composite(base.convert("RGBA"), zone_overlay)
    composite = Image.alpha_composite(composite, route_overlay)
    composite = Image.alpha_composite(composite, poi_overlay)
    composite.convert("RGB").save(output_dir / "world_v01_topdown.png", quality=95)


def route_slope_stats(source: dict) -> dict:
    result = {}
    for route_name, points in source["routes"].items():
        slopes = []
        for first, second in zip(points[:-1], points[1:]):
            horizontal = math.hypot(second[0] - first[0], second[2] - first[2])
            slopes.append(math.degrees(math.atan2(abs(second[1] - first[1]), horizontal)))
        result[route_name] = {
            "maxDegrees": round(max(slopes), 2),
            "segments": len(slopes),
        }
    return result


def save_manifest(source: dict, height: np.ndarray, output_dir: Path) -> None:
    manifest = {
        "generatorVersion": 5,
        "artifactRevision": source.get("artifactRevision", "unversioned"),
        "worldScaleXZ": source["worldScaleXZ"],
        "boundsStuds": source["boundsStuds"],
        "resolution": source["resolution"],
        "heightRangeStuds": source["heightRangeStuds"],
        "actualHeightStuds": {
            "min": round(float(height.min()), 2),
            "max": round(float(height.max()), 2),
        },
        "waterLevelStuds": source["waterLevelStuds"],
        "routeSlopeStats": route_slope_stats(source),
        "outputs": [
            "world_v01_heightmap.png",
            "world_v01_water_mask.png",
            "world_v01_topdown.png",
            "world_v01_routes_overlay.png",
            "world_v01_poi_spawn_overlay.png",
            "world_v01_zones_overlay.png",
        ],
    }
    (output_dir / "world_v01_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate Luna World v0.1 authoring heightmap and debug maps."
    )
    parser.add_argument(
        "--source",
        type=Path,
        default=Path(__file__).with_name("world_v01.json"),
        help="Path to the production world source JSON.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=None,
        help="Output directory. Defaults to artifacts/worldgen/v01/<artifactRevision>.",
    )
    args = parser.parse_args()

    source = load_source(args.source)
    if args.output is None:
        revision = source.get("artifactRevision", "unversioned")
        args.output = Path("artifacts/worldgen/v01") / revision
    args.output.mkdir(parents=True, exist_ok=True)

    height, water_mask = generate_height(source)
    save_heightmap(source, height, args.output)
    Image.fromarray(water_mask, "L").save(args.output / "world_v01_water_mask.png")
    save_topdown(source, height, water_mask, args.output)
    save_manifest(source, height, args.output)

    print(f"Generated Luna World v0.1 terrain draft in {args.output}")
    print(f"Artifact revision: {source.get('artifactRevision', 'unversioned')}")
    print(f"World scale X/Z: {source['worldScaleXZ']}x")
    print(f"Height range: {height.min():.2f}..{height.max():.2f} studs")
    for name, stats in route_slope_stats(source).items():
        print(f"{name}: max centerline slope {stats['maxDegrees']:.2f} deg")


if __name__ == "__main__":
    main()
