#!/usr/bin/env python3
"""Static integration guard for the dev0.2 quest authority and client surfaces."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def read(path): return (ROOT/path).read_text(encoding='utf-8')
def require(source, needle, message):
    if needle not in source: raise AssertionError(message)
quest=read('src/server/services/QuestService.luau')
rules=read('src/shared/quests/QuestRules.luau')
profile=read('src/shared/persistence/ProfileSchema.luau')
migration=read('src/shared/persistence/MigrationRules.luau')
client=read('src/client/controllers/QuestController.luau')
action=read('src/client/ui/ActionBar.luau')
for project in ('default.project.json','test.project.json'):
    value=read(project)
    for remote in ('QuestAcceptRequest','QuestTurnInRequest','QuestSnapshotRequest','QuestSnapshot','QuestActionResult','DialogueOpen'):
        require(value, f'"{remote}"', f'{project} lacks {remote}')
require(quest,'MobService.MobDied:Connect','kill credit must consume authoritative MobDied')
require(quest,'humanoid.Health>0','location credit must require a living character')
require(quest,'nearLivingNpc','quest requests must validate NPC proximity')
require(quest,'select("#", ...) ~= 2','quest action schema must enforce exact argument count')
assert 'objective' not in ''.join(line for line in quest.splitlines() if 'OnServerEvent' in line).lower(), 'clients must not submit objective progress'
require(rules,'record.State = "Completed"','quest completion state is missing')
require(rules,'profile.Luna += definition.rewardLuna','quest Luna reward is missing')
require(profile,'ProfileSchema.DataVersion = 2','profile schema must be v2')
require(migration,'[1] = function','v1 to v2 migration is missing')
require(client,'Enum.KeyCode.M','map keyboard binding is missing')
require(client,'WorldToViewportPoint','screen waypoint projection is missing')
require(client,'QuestMarker','NPC quest markers are missing')
require(client,'npcTargetPosition','quest navigation must respect NPC position offsets')
require(client,'objective.displayText or objective.id','quest tracker must show readable objective text')
require(client,'value.message','quest dialogue must render NPC quest copy')
require(client,'Player position is valuable even before the first quest exists.','map must show the player without requiring an active quest')
require(client,'addZoneBlocks','map must show zone separation')
require(client,'addRiver','map must include the river')
require(client,'addRoutes','map must include authored routes')
require(client,'1 - math.clamp(x, 0, 1)','map X axis must be rotated 180 degrees')
require(client,'1 - math.clamp(z, 0, 1)','map Z axis must be rotated 180 degrees')
require(client,'"N ↑"','map must expose north-up orientation')
require(client,'HudLayout.makeCloseButton','map and quest dialog must use the shared close control')
require(client,'workspace.DescendantAdded','quest markers must recover from replication order races')
require(action,'КАРТА [M]','action block map button is missing')
require(action,'mapBindingText','map hint must adapt to the active input device')
print('Quest system authority, persistence, navigation, and UI contract: PASS')
