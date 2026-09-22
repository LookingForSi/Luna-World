#!/usr/bin/env python3
"""Gate F1 contract: Lobby and Quest client controllers have real feature ownership."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read(path: str) -> str:
    candidate = ROOT / path
    assert candidate.exists(), f"missing F1 file: {path}"
    return candidate.read_text(encoding="utf-8")

adapter = read("src/client/bootstrap/adapters/ExistingClientComponents.luau")
lobby_feature = read("src/client/features/lobby/CharacterLobbyController.luau")
quest_feature = read("src/client/features/quests/QuestController.luau")
lobby_facade = read("src/client/controllers/CharacterLobbyController.luau")
quest_facade = read("src/client/controllers/QuestController.luau")

assert "clientRoot.features.lobby.CharacterLobbyController" in adapter
assert "clientRoot.features.quests.QuestController" in adapter
assert "clientRoot.controllers.CharacterLobbyController" not in adapter
assert "clientRoot.controllers.QuestController" not in adapter

assert "return require(script.Parent.Parent.features.lobby.CharacterLobbyController)" in lobby_facade
assert "return require(script.Parent.Parent.features.quests.QuestController)" in quest_facade
assert len(lobby_facade.splitlines()) <= 5, "legacy Lobby controller must remain a thin compatibility facade"
assert len(quest_facade.splitlines()) <= 5, "legacy Quest controller must remain a thin compatibility facade"

for token in (
    "ResponsiveLayout.observe",
    "CharacterResult",
    "CharacterRequest",
    "function CharacterLobbyController.start",
    "function CharacterLobbyController.stop",
    "DeleteConfirmation",
    "CreationModal",
    "onEnterWorld(chosen.characterId)",
):
    assert token in lobby_feature, f"feature-owned Lobby implementation missing {token}"

for token in (
    "QuestSnapshotRequest",
    "DialogueOpen",
    "TravelRequest",
    "function QuestController.start",
    "function QuestController.stop",
    "function QuestController.toggleMap",
    "function QuestController.toggleJournal",
    "HudLayout.makeCloseButton",
    "WorldToViewportPoint",
):
    assert token in quest_feature, f"feature-owned Quest implementation missing {token}"

assert "script.Parent.Parent.Parent.ui.ResponsiveLayout" in lobby_feature
assert "script.Parent.Parent.Parent.ui.HudLayout" in quest_feature

print("Gate F1 client feature ownership: PASS")
