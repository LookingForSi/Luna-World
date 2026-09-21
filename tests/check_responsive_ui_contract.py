#!/usr/bin/env python3
"""Статический контракт responsive UI: safe viewport + adaptive/fluid policy."""

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
    assert f'"{mode}"' in policy, f"нет compatibility mode {mode}"
for layout_class in ("CompactLandscape", "RegularLandscape", "ExpandedLandscape", "PortraitFallback"):
    assert f'"{layout_class}"' in policy, f"нет layout class {layout_class}"

assert "GuiService:GetGuiInset()" in policy, "safe-area inset должен входить в метрики"
assert 'GetPropertyChangedSignal("ViewportSize")' in policy, "resize viewport должен обновлять layout"
assert 'GetPropertyChangedSignal("CurrentCamera")' in policy, "смена камеры должна перепривязывать resize"
assert "fluidWidth" in policy and "fluidHeight" in policy
assert "MinimumTouchTarget = 44" in policy and "MaximumTouchTarget = 56" in policy
assert "return clamp(scale, 0.90, 1.15)" in policy
assert "metrics.contentSize.X * widthFraction" in policy
assert "metrics.contentSize.Y * heightFraction" in policy

assert 'UserInputType.Touch then "БЫСТРО"' in actions
assert 'then "AUTO"' in actions, "touch UI не должен показывать desktop hotkey AUTO"
assert "ResponsiveLayout.skillBarSize(metrics, slotCount)" in actions
assert "ResponsiveLayout.primaryActionsSize(metrics)" in actions

assert "ResponsiveLayout.playerStatusSize(metrics)" in controller
assert "ResponsiveLayout.targetSize(metrics)" in controller
assert "ResponsiveLayout.primaryActionsSize(metrics)" in controller
assert "ResponsiveLayout.skillBarSize(metrics, 6)" in controller
assert 'child.Enabled = metrics.layoutClass == "Desktop"' in controller

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

print("Responsive adaptive UI contract: PASS")
