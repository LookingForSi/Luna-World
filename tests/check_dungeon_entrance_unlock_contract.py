#!/usr/bin/env python3
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def read(path): return (ROOT/path).read_text()
layout=read('src/shared/world/WorldLayout.luau')
worldgen=read('tools/worldgen/moonfall/NorthernZonesBlockout.luau')
service=read('src/server/features/dungeon/DungeonEntranceService.luau')
debug=read('src/server/services/StudioDebugService.luau')
rules=read('src/shared/dungeon/DungeonUnlockRules.luau')
transfer=read('src/server/features/dungeon/DungeonTransferService.luau')
quest=read('src/shared/definitions/QuestDefinitions.luau')
map_client=read('src/client/features/quests/QuestController.luau')
manifest=read('src/server/bootstrap/manifests/WorldServerManifest.luau')
assert 'RuinsOfSeleneEntranceQuery' in layout
assert '"RuinsOfSeleneEntranceSpawn"' in worldgen and 'P.groundedPart' in worldgen
assert 'TerrainGrounding.surfaceAt(WorldLayout.RuinsOfSeleneEntranceQuery)' in service
assert 'assert(hit,' in service
assert 'UnlockRules.isUnlocked' in service and 'KillCreditService.KillResolved' in service
assert 'PlayerDataService.ProfileChanged:Connect(refreshPlayer)' in service
assert 'if portalStone ~= nil and portalStone.Parent ~= nil then return end' in service
assert 'RunService:IsStudio()' in service and 'Moonbound Warden killed, but Ruins remain locked' in service
assert 'createRemote("StudioUnlockRuins")' in debug and 'RunService:IsStudio()' in debug
assert 'PlayerDataService.mutate' in debug and 'DungeonUnlockRules.prepareStudioUnlock' in debug
assert 'definition.objectives' in rules and 'State = "ReadyToTurnIn"' in rules
assert 'StudioGrantTestItems' not in debug
assert 'DungeonTransferService.bindEntrancePrompt(prompt)' in service
assert 'local partyUnlocked=false' in transfer and 'UnlockRules.isUnlocked(profile.Quests)' in transfer
assert 'Древняя печать ещё не разрушена.' in transfer
assert 'marker.Position=Vector3.new(35,5,35)' not in transfer
assert 'Components.dungeonEntrance()' in manifest
assert 'Источник зла находится не здесь' in quest and 'Страж повержен' in quest
assert 'RuinsOfSeleneUnlocked' in map_client and 'RuinsOfSeleneMapMarker' in map_client
print('Dungeon entrance Guardian unlock contract: PASS')
