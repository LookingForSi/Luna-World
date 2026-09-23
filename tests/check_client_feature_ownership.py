#!/usr/bin/env python3
"""Client feature ownership contract for Lobby and Quest."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    candidate = ROOT / path
    assert candidate.exists(), f"missing client feature file: {path}"
    return candidate.read_text(encoding="utf-8")


adapter = read("src/client/bootstrap/adapters/ExistingClientComponents.luau")
lobby_feature = read("src/client/features/lobby/CharacterLobbyController.luau")
quest_feature = read("src/client/features/quests/QuestController.luau")

assert "clientRoot.features.lobby.CharacterLobbyController" in adapter
assert "clientRoot.features.quests.QuestController" in adapter
assert "clientRoot.controllers.CharacterLobbyController" not in adapter
assert "clientRoot.controllers.QuestController" not in adapter

for legacy_path in (
    "src/client/controllers/CharacterLobbyController.luau",
    "src/client/controllers/QuestController.luau",
):
    assert not (ROOT / legacy_path).exists(), f"obsolete compatibility facade returned: {legacy_path}"

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

print("Client Lobby/Quest feature ownership: PASS")
