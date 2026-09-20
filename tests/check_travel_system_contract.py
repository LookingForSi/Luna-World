#!/usr/bin/env python3
"""Static contract for quest-unlocked paid travel."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def read(path): return (ROOT/path).read_text(encoding="utf-8")
defs=read("src/shared/definitions/TravelDefinitions.luau")
rules=read("src/shared/travel/TravelRules.luau")
service=read("src/server/services/TravelService.luau")
quest=read("src/server/services/QuestService.luau")
client=read("src/client/controllers/QuestController.luau")
main=read("src/server/main.server.luau")
for token in (
    'id = "travel_farm"',
    'unlockQuestId = "quest_young_wolf_problem"',
    'fieldNpcId = "npc_farmer"',
    'representativeLootTableId = "loot_young_wolf"',
    'id = "travel_moonfall"',
    'unlockQuestId = "quest_stone_circle_pack"',
    'fieldNpcId = "npc_moonfall_scout"',
    'representativeLootTableId = "loot_grey_wolf"',
    'killEquivalent = 4',
):
    if token not in defs: raise AssertionError(f"travel definition missing: {token}")
for token in (
    'record.State == "Completed"',
    '(loot.lunaMin + loot.lunaMax) / 2',
    'math.ceil(averageLuna * definition.killEquivalent)',
    'sourceNpcId == definition.villageNpcId',
    'sourceNpcId == definition.fieldNpcId',
):
    if token not in rules: raise AssertionError(f"travel rule missing: {token}")
for token in (
    'select("#", ...) ~= 2',
    'nearNpc(player, sourceNpcId :: string)',
    'TravelRules.isUnlocked(profile.Quests, definition)',
    'value.Luna < cost',
    'value.Luna -= cost',
    'character:PivotTo',
    'value.Luna += cost',
    '"TeleportFailed"',
):
    if token not in service: raise AssertionError(f"travel authority missing: {token}")
for token in (
    'kind="Travel"',
    'costLuna=TravelRules.costLuna(definition)',
):
    if token not in quest: raise AssertionError(f"quest dialogue travel topic missing: {token}")
for token in (
    'Телепорт: %s · %d Luna',
    'travelRequest:FireServer(topic.travelId, value.npcId)',
    'InsufficientLuna = "Недостаточно Luna для телепорта."',
):
    if token not in client: raise AssertionError(f"travel client surface missing: {token}")
for token in ("TravelService.start()", "TravelService.stop()"):
    if token not in main: raise AssertionError(f"travel lifecycle missing: {token}")
print("Quest-unlocked travel contract: PASS")
