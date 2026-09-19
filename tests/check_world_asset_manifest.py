import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "tools/world_assets/world_asset_manifest_v01.json"
COMPOSITION = ROOT / "src/server/world/WorldCompositionBlockout.luau"

REQUIRED_CURRENT = {
    "village_house",
    "village_roof",
    "rock",
    "tree",
    "dead_tree",
    "ancient_ruin",
    "field_strip",
}


def main() -> None:
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    assert data["version"] == 1
    assert data["rules"]["no_direct_game_clone_assets"] is True
    assert data["rules"]["pivot"] == "ground_center"
    assert data["rules"]["up_axis"] == "+Y"

    categories = data["categories"]
    ids = [entry["id"] for entry in categories]
    assert len(ids) == len(set(ids)), "asset category ids must be unique"

    by_id = {entry["id"]: entry for entry in categories}
    for category_id in REQUIRED_CURRENT:
        assert category_id in by_id, f"missing asset category {category_id}"
        assert by_id[category_id]["current_blockout"] is True
        assert by_id[category_id]["target_variants"] >= 1

    source = COMPOSITION.read_text(encoding="utf-8")
    referenced = set(re.findall(r'attrs\("([a-z_]+)"\)', source))
    referenced.update(re.findall(r'ReplacementCategory", "([a-z_]+)"', source))

    unknown = referenced - set(ids)
    assert not unknown, f"composition references unknown asset categories: {sorted(unknown)}"

    assert "BlenderStudioAssetPass" in source
    print("world asset manifest contract: PASS")


if __name__ == "__main__":
    main()
