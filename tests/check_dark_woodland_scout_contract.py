#!/usr/bin/env python3
"""Regression contract for the Moonfall Road -> Dark Woodland scout handoff."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


npcs = read("src/shared/definitions/NpcDefinitions.luau")
quests = read("src/shared/definitions/QuestDefinitions.luau")
travel = read("src/shared/definitions/TravelDefinitions.luau")
layout = read("src/shared/world/WorldLayout.luau")
quest_service = read("src/server/services/QuestService.luau")

for token in (
    'npc_moonfall_scout = { id = "npc_moonfall_scout", displayName = "Дозорный Moonfall Road", poiId = "poi_moonfall_crossroads"',
    'npc_dark_woodland_scout = { id = "npc_dark_woodland_scout", displayName = "Дозорный Dark Woodland", poiId = "poi_dark_woodland_gate", modelName = "DarkWoodlandScoutNpc"',
):
    if token not in npcs:
        raise AssertionError(f"NPC split contract missing: {token}")

if '{ id = "poi_dark_woodland_gate", position =' not in layout:
    raise AssertionError("Dark Woodland scout POI must remain in authoritative WorldLayout")

expected_quest_fragments = (
    'quest_spider_hollow = {',
    'giverNpcId="npc_moonfall_scout", turnInNpcId="npc_moonfall_scout", prerequisiteQuestIds={"quest_goblin_threat"}',
    'quest_dark_woodland = {',
    'giverNpcId="npc_dark_woodland_scout", turnInNpcId="npc_dark_woodland_scout", prerequisiteQuestIds={"quest_spider_hollow"}',
    'quest_ancient_approach = {',
    'giverNpcId="npc_dark_woodland_scout", turnInNpcId="npc_dark_woodland_scout", prerequisiteQuestIds={"quest_dark_woodland"}',
    'У границы Dark Woodland стоит другой дозорный',
)
for token in expected_quest_fragments:
    if token not in quests:
        raise AssertionError(f"quest ownership/chain contract missing: {token}")

for token in (
    'id = "travel_farm"',
    'id = "travel_moonfall"',
    'id = "travel_dark_woodland"',
    'unlockQuestId = "quest_spider_hollow"',
    'villageNpcId = "npc_gatekeeper"',
    'fieldNpcId = "npc_dark_woodland_scout"',
):
    if token not in travel:
        raise AssertionError(f"travel regression contract missing: {token}")

# Quest markers and travel topics must remain data-driven from giver/turn-in IDs.
for token in (
    'definition.giverNpcId == npcId',
    'definition.turnInNpcId == npcId',
    'TravelRules.destinationNpcId(definition, npcId)',
):
    if token not in quest_service:
        raise AssertionError(f"server-driven NPC topic contract missing: {token}")

print("Dark Woodland scout handoff contract: PASS")
