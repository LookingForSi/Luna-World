#!/usr/bin/env python3
"""Статический контракт responsive UI для GitHub Issue #27."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def source(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


policy = source("src/client/ui/ResponsiveLayout.luau")
controller = source("src/client/controllers/ResponsiveUiController.luau")
actions = source("src/client/ui/ActionBar.luau")
quest = source("src/client/controllers/QuestController.luau")
economy = source("src/client/ui/EconomyUi.luau")
inventory = source("src/client/ui/InventoryUi.luau")

for mode in ("Desktop", "TouchLarge", "MobilePortrait", "MobileLandscape"):
    assert f'"{mode}"' in policy, f"нет режима {mode}"

assert "GuiService:GetGuiInset()" in policy, "safe-area inset должен входить в метрики"
assert 'GetPropertyChangedSignal("ViewportSize")' in policy, "resize viewport должен обновлять layout"
assert 'GetPropertyChangedSignal("CurrentCamera")' in policy, "смена камеры должна перепривязывать resize"
assert "math.min(desktopSize.X, metrics.contentSize.X)" in policy
assert "math.min(desktopSize.Y, metrics.contentSize.Y)" in policy
assert "MinimumTouchTarget = 44" in policy, "touch targets не должны быть меньше 44 px"

assert 'UserInputType.Touch then "БЫСТРО"' in actions
assert 'then "AUTO"' in actions, "touch UI не должен показывать desktop hotkey AUTO"
assert 'inventory.Position = UDim2.fromOffset(0, 28)' in controller
assert 'cart.Position = UDim2.fromOffset(0, 270)' in controller
assert 'cart.Position = UDim2.new(0.51, 0, 0, 28)' in controller
assert 'Name = "SellConfirm"' in economy

assert 'Name = "DescriptionScroll"' in quest, "описание quest offer должно прокручиваться"
assert "HudLayout.makeCloseButton(questOffer" in quest
assert "blocker.Modal = true" in quest
assert "blocker.Modal = true" in economy
assert "blocker.Modal = true" in inventory
assert "blocker.BackgroundTransparency = 1" in quest
assert "blocker.BackgroundTransparency = 1" in economy
assert "blocker.BackgroundTransparency = 1" in inventory
assert "screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling" in economy

print("Responsive UI contract: PASS")
