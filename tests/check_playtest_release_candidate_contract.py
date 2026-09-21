#!/usr/bin/env python3
"""High-level static contract for the consolidated playtest release candidate."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
read = lambda p: (ROOT / p).read_text(encoding="utf-8")

account = read("src/shared/persistence/AccountSchema.luau")
lobby = read("src/client/controllers/CharacterLobbyController.luau")
responsive = read("src/client/ui/ResponsiveLayout.luau")
craft = read("src/shared/definitions/CraftingDefinitions.luau")
mobs = read("src/shared/definitions/MobDefinitions.luau")
world = read("src/server/world/NorthernZonesBlockout.luau")
movement = read("src/client/controllers/MovementController.luau")
progression = read("src/server/services/ProgressionService.luau")
combat = read("src/server/services/CombatService.luau")
server = read("src/server/main.server.luau")
client = read("src/client/main.client.luau")
target_controller = read("src/client/controllers/TargetController.luau")
quest_client = read("src/client/controllers/QuestController.luau")
quest_server = read("src/server/services/QuestService.luau")
player_data = read("src/server/services/PlayerDataService.luau")
respawn = read("src/server/services/RespawnService.luau")
hud = read("src/client/ui/CombatHud.luau")
inventory_ui = read("src/client/ui/InventoryUi.luau")

assert "DataVersion = 3" in account
assert "CharacterOrder" in account and "Characters" in account
assert "ResponsiveLayout.observe" in lobby and "MobilePortrait" in lobby
assert "MobileLandscape" in responsive and "MinimumTouchTarget = 44" in responsive

for discipline in ('"Knight"', '"Ranger"', '"Mystic"', '"Material"'):
    assert discipline in craft

assert 'displayName = "Ядовитый паук", level = 6' in mobs
assert 'displayName = "Паук-матка", level = 8' in mobs
assert 'aggressionMode = "Passive"' in mobs

assert "fillCurvedRidge" in world
assert "lake generation is intentionally disabled" in world
assert "\n\tcreateGoblinCemeteryLake(north, positions)\n" not in world

assert "Enum.HumanoidStateType.Swimming" in movement
assert "Enum.ContextActionResult.Pass" in movement
assert "levelsGained > 0" in progression
assert "restorePlayerVitalsAfterLevelUp" in progression
assert "humanoid.Health = humanoid.MaxHealth" in combat
assert "restoreCombatPoints(player)" in combat

assert "player:SetAttribute(CombatConfig.ArchetypeAttribute, character.ArchetypeId)" in player_data
assert "CharacterConfig.NicknameAttribute" in player_data
assert "humanoid.DisplayName = nickname" in respawn
assert "initializeReadyPlayer" in combat
assert "Never manufacture the default knight before Character Lobby selection" in combat
assert "CharacterConfig.NicknameAttribute" in hud
assert "blocker.BackgroundTransparency = 1" in inventory_ui
assert "panel.BackgroundTransparency = 0.03" in inventory_ui

assert server.index("Players.CharacterAutoLoads = false") < server.index('WaitForChild("LunaWorldPlayableBlockout"')
assert client.index("TargetController.start") < client.index("EconomyUi.start")
assert client.index("TargetController.start") < client.index("QuestController.start")
assert client.index("syncActionBar()") < client.index("EconomyUi.start")
assert "localGuiBlocksPointer" in target_controller
assert "firstSnapshotReceived" in quest_client
assert "0.35, 0.9, 1.8, 3.0" in quest_client
assert "task.defer(QuestService.push, player)" in quest_server

print("Consolidated playtest release candidate contract: PASS")
