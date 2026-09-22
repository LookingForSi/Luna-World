#!/usr/bin/env python3
"""Semantic mobile landscape contract for GitHub Issue #37."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def source(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


responsive = source("src/client/ui/ResponsiveLayout.luau")
surfaces = source("src/client/ui/MobileSurface.luau")
coordinator = source("src/client/ui/MobileOverlayCoordinator.luau")
lobby = source("src/client/features/lobby/CharacterLobbyController.luau")
economy = source("src/client/features/economy/EconomyUi.luau")
inventory = source("src/client/features/inventory/InventoryUi.luau")
quest = source("src/client/features/quests/QuestController.luau")
actions = source("src/client/ui/ActionBar.luau")
studio = source("src/client/ui/StudioTestPanel.luau")
global_controller = source("src/client/controllers/ResponsiveUiController.luau")

for semantic in ("CompactDialog", "MenuSheet", "FullWorkspace"):
    assert semantic in surfaces, f"missing semantic surface {semantic}"
assert "GuiService:GetGuiInset()" not in responsive
for field in ("usableWidth", "usableHeight", "layoutClass", "touchTarget", "gap"):
    assert field in responsive
for feature in (lobby, economy, inventory, quest):
    assert "Enum.ScreenInsets.CoreUISafeInsets" in feature
assert "Enum.ScreenInsets.DeviceSafeInsets" in source("src/client/ui/CombatHud.luau")
assert "applyModals" not in global_controller

assert "UserInputService.TouchEnabled then return" in studio
assert 'Name = "CreationBody"' in lobby and "AutomaticCanvasSize = Enum.AutomaticSize.Y" in lobby
assert 'Name = "CreationFooter"' in lobby and 'Name = "CreateCharacter"' in lobby
assert 'new("UIListLayout", bodyScroll' in lobby
assert 'Text = if smallTouch then "Удалить"' in lobby
assert 'TextWrapped = false' in lobby

assert '"MenuSheet"' in economy and '"FullWorkspace"' in economy
assert 'mode == "Sell"' in economy and 'mode == "Buy"' in economy
assert 'Instance.new("UIGridLayout")' in economy
assert 'grid.FillDirectionMaxCells = 2' in economy
assert 'mode == "DialogueBlacksmith"' in economy
assert 'SetAttribute("MobileSurface", "FullWorkspace")' in inventory
assert 'MobileOverlayCoordinator.setWorkspaceOpen(root, open)' in inventory
for hud in ("CombatHud", "CombatActionBar", "CombatLog", "StudioTestPanel"):
    assert hud in coordinator

assert 'SetAttribute("MobileSurface", "MenuSheet")' in quest
assert 'SetAttribute("MobileSurface", "CompactDialog")' in quest
assert 'SetAttribute("MobileSurface", "FullWorkspace")' in quest

for label in ("СУМКА", "КАРТА", "КВЕСТЫ"):
    assert label in actions
for hotkey in ('then "КАРТА [M]"', 'then "ЗАДАНИЯ [Y]"', 'then "ИНВЕНТАРЬ [T]"'):
    assert hotkey not in actions

print("Mobile landscape UX semantic contract: PASS")
