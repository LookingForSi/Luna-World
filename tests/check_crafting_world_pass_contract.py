#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
read = lambda path: (ROOT / path).read_text()
craft = read("src/shared/definitions/CraftingDefinitions.luau")
rules = read("src/shared/economy/EconomyRules.luau")
service = read("src/server/services/EconomyService.luau")
ui = read("src/client/ui/EconomyUi.luau")
merchant = read("src/shared/definitions/MerchantDefinitions.luau")

for token in ('"Knight"', '"Ranger"', '"Mystic"', '"Material"', "requiredLevel", "outputQuantity", "sortOrder"):
    assert token in craft, f"missing recipe metadata {token}"
for item_id in ("material_sturdy_thread", "material_iron_billet", "material_arcane_thread",
                "armor_hunter_head", "armor_hunter_chest", "armor_hunter_gloves", "armor_hunter_boots",
                "armor_adept_head", "armor_adept_chest", "armor_adept_gloves", "armor_adept_boots"):
    assert item_id in craft or item_id in read("src/shared/definitions/ItemDefinitions.luau"), f"missing {item_id}"
assert 'return nil, "LevelTooLow"' in rules
assert "recipe.outputQuantity" in rules
assert "disciplineOrder" in service
for label in ("Ковать — Рыцарь", "Ковать — Следопыт", "Ковать — Мистик", "Обработать материалы"):
    assert label in ui, f"missing topic {label}"
for forbidden in ("material_cured_leather", "material_sturdy_thread", "material_iron_billet", "material_arcane_thread",
                  "weapon_iron_blade", "weapon_hunter_bow", "weapon_rune_staff", "armor_guard_head"):
    assert f'"{forbidden}"' not in merchant, f"merchant sells {forbidden}"
print("crafting world pass contract checks passed")
