#!/usr/bin/env python3
"""Studio Ruins shortcut must exercise the production profile-change pipeline."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


server = read("src/server/services/StudioDebugService.luau")
client = read("src/client/ui/StudioTestPanel.luau")
rules = read("src/shared/dungeon/DungeonUnlockRules.luau")
entrance = read("src/server/features/dungeon/DungeonEntranceService.luau")
quest = read("src/server/services/QuestService.luau")

all_runtime = server + client
for removed in ("StudioGrantTestItems", "ТЕСТ ЛУТ +"):
    if removed in all_runtime:
        raise AssertionError(f"obsolete Studio loot shortcut remains: {removed}")

for token in (
    "if started or not RunService:IsStudio() then return end",
    'createRemote("StudioUnlockRuins")',
    "PlayerDataService.mutate(player",
    "QuestDefinitions[DungeonUnlockRules.QuestId]",
    "DungeonUnlockRules.prepareStudioUnlock(profile.Quests, definition)",
):
    if token not in server:
        raise AssertionError(f"Studio-only authoritative unlock contract missing: {token}")

for token in (
    'WaitForChild("StudioUnlockRuins", 5)',
    'makeLevelButton("UnlockRuins", "RUINS OPEN", 8, 140)',
    "unlockRuinsRemote:FireServer()",
):
    if token not in client:
        raise AssertionError(f"Studio panel Ruins control missing: {token}")

for token in (
    "existing.State == \"Completed\"",
    "for _, objective in definition.objectives do",
    "progress[objective.id] = objective.required",
    'State = "ReadyToTurnIn"',
):
    if token not in rules:
        raise AssertionError(f"schema-valid debug quest preparation missing: {token}")

for token in (
    "PlayerDataService.ProfileChanged:Connect(refreshPlayer)",
    "UnlockRules.isUnlocked(profile.Quests)",
    "createPortal()",
    "if portalStone ~= nil and portalStone.Parent ~= nil then return end",
):
    if token not in entrance:
        raise AssertionError(f"production entrance refresh/idempotency missing: {token}")

# Production credit remains conditional on an already-active quest. The debug
# shortcut must not be folded into canonical kill handling.
if 'if record.State ~= "Active" then continue end' not in read("src/shared/quests/QuestRules.luau"):
    raise AssertionError("production Warden kill must not activate an absent quest")
if "DungeonUnlockRules.prepareStudioUnlock" in quest:
    raise AssertionError("production QuestService must not invoke the Studio shortcut")

print("Studio Ruins unlock contract: PASS")
