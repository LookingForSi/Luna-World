#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read(path: str) -> str:
    return (ROOT / path).read_text()

def require(text: str, needle: str, message: str) -> None:
    if needle not in text:
        raise AssertionError(message)

items = read("src/shared/definitions/ItemDefinitions.luau")
loot = read("src/shared/definitions/LootTableDefinitions.luau")
craft = read("src/shared/definitions/CraftingDefinitions.luau")
rules = read("src/shared/economy/EconomyRules.luau")
network = read("src/server/services/EconomyNetworkService.luau")
inventory = read("src/server/services/InventoryService.luau")
world = read("src/server/services/EconomyWorldService.luau")
client = read("src/client/ui/EconomyUi.luau")
main = read("src/server/main.server.luau")

for grade in ('"Newbie"', '"NoGrade"', '"Future"'):
    require(items, grade, f"missing item grade {grade}")
for item_id in ("weapon_iron_blade", "weapon_hunter_bow", "weapon_rune_staff", "armor_guard_head",
                "armor_guard_chest", "armor_guard_gloves", "armor_guard_boots", "accessory_silver_moon_charm"):
    require(craft, item_id, f"missing No-Grade craft {item_id}")
for forbidden in ("weapon_moonsteel_sword", "weapon_moonstring_bow", "weapon_moonveil_staff", "accessory_lunar_sigil"):
    if forbidden in loot:
        raise AssertionError(f"future gear remains obtainable: {forbidden}")

require(rules, "MerchantDefinitions.BuybackRatio", "buyback must use authoritative shared ratio")
require(rules, "InventoryRules.discard", "sell/craft must use canonical inventory removal")
require(network, "EconomyRequestRules.validate", "economy remote must validate schema")
require(network, "RequestMinIntervalSeconds", "economy remote must rate limit")
require(network, "nearby(player, poiId)", "economy remote must validate NPC distance")
require(network, "interactionPosition", "economy distance must follow the visible service NPC")
require(network, '"BlacksmithNpc"', "blacksmith distance must follow its visible NPC")
require(network, '"MerchantNpc"', "merchant distance must follow its visible NPC")
require(world, "ProximityPrompt", "village economy must expose nearby interaction prompts")
require(world, '"Поговорить"', "all service NPC prompts must start with Talk")
require(world, "Enum.KeyCode.E", "keyboard NPC interaction must expose the E binding")
require(world, "Enum.KeyCode.ButtonA", "gamepad NPC interaction must expose a non-skill talk binding")
require(world, '"MerchantNpc"', "merchant interaction must bind to a visible NPC")
require(world, '"BlacksmithNpc"', "blacksmith interaction must bind to a visible NPC")
require(world, "BillboardGui", "economy NPCs must expose readable nameplates")
require(world, "Highlight", "economy NPCs must be visually discoverable")
require(inventory, "ReturnToSettlement", "return scroll effect must be data driven")
require(inventory, "CollectionService:GetTagged(RespawnConfig.AnchorTag)", "return scroll must reuse respawn anchor")
for token in ('"DialogueMerchant"', '"DialogueBlacksmith"', '"Купить"', '"Продать"', '"Ковать"'):
    require(client, token, f"dialogue topic flow missing {token}")
require(client, "level < 6", "level-six session onboarding is missing")
require(main, "EconomyNetworkService.start()", "economy networking is not bootstrapped")
require(main, "EconomyWorldService.stop()", "economy world lifecycle cleanup is missing")

for project in ("default.project.json", "test.project.json"):
    data = read(project)
    for remote in ("EconomyRequest", "EconomySnapshot", "EconomyOpen", "EconomyResult"):
        require(data, remote, f"{project} missing {remote}")

print("loot/craft/economy contract checks passed")
