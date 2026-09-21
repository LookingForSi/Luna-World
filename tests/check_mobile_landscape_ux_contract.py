from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")

def require(body: str, needle: str, message: str) -> None:
    assert needle in body, message

main = read("src/client/main.client.luau")
project = read("default.project.json")
layout = read("src/client/ui/ResponsiveLayout.luau")
lobby = read("src/client/controllers/CharacterLobbyController.luau")
service = read("src/server/services/CharacterService.luau")
responsive = read("src/client/controllers/ResponsiveUiController.luau")
bar = read("src/client/ui/ActionBar.luau")
hud = read("src/client/ui/CombatHud.luau")
log = read("src/client/ui/CombatLog.luau")
quest = read("src/client/controllers/QuestController.luau")
economy = read("src/client/ui/EconomyUi.luau")
inventory = read("src/client/ui/InventoryUi.luau")
design_doc = read("docs/UI_RESPONSIVE_DESIGN_SYSTEM.md")

require(project, '"ScreenOrientation": "LandscapeSensor"', "StarterGui must request landscape sensor")
require(main, "playerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor", "PlayerGui orientation fallback missing")
assert main.index("ScreenOrientation") < main.index("CharacterLobbyController.start()")

for token in (
    'export type LayoutClass',
    '"CompactLandscape"',
    '"RegularLandscape"',
    '"ExpandedLandscape"',
    '"PortraitFallback"',
    "uiScale",
    "touchTarget",
    "fluidWidth",
    "fluidHeight",
    "scaled",
    "playerStatusSize",
    "targetSize",
    "primaryActionsSize",
    "skillBarSize",
    "combatLogExpandedSize",
    "lobbyRosterWidth",
):
    require(layout, token, f"adaptive responsive policy missing {token}")

require(layout, "return clamp(scale, 0.90, 1.15)", "touch UI scale needs bounded min/max")
require(layout, "ResponsiveLayout.MinimumTouchTarget = 44", "touch target minimum missing")
require(layout, "ResponsiveLayout.MaximumTouchTarget = 56", "touch target maximum missing")
require(layout, "metrics.contentSize.X * widthFraction", "modal width must be relative to safe viewport")
require(layout, "metrics.contentSize.Y * heightFraction", "modal height must be relative to safe viewport")
assert "MobileEdgeMargin" not in layout and "MobileModalHorizontalMargin" not in layout

require(lobby, "ResponsiveLayout.isLandscapeTouch(metrics)", "lobby must use touch landscape policy")
require(lobby, "ResponsiveLayout.lobbyRosterWidth(metrics)", "lobby roster must be fluid/clamped")
require(lobby, "metrics.touchTarget", "lobby controls must use shared touch target")
require(lobby, "ResponsiveLayout.fluidHeight(metrics", "lobby heights must react to viewport")
require(lobby, 'Name = "CreationContent"', "mobile creation central content missing")
require(lobby, "local formPadding = if touchLandscape then ResponsiveLayout.scaled", "creation spacing must be derived")
require(lobby, 'Name = "LegacyIdentityModal"', "legacy completion needs a mobile-safe modal")
require(lobby, 'Name = "DeleteCharacterModal"', "two-step delete modal missing")
require(lobby, 'chosen.nickname or "Без имени"', "unnamed character fallback missing")
assert "DELETE:nil" not in lobby and "DeleteConfirmationPrefix .. tostring" not in service

require(service, "p.confirmed ~= true", "server explicit confirmation missing")
require(service, "if canonical ~= nil then", "unnamed nickname release guard missing")
require(service, "CharacterDeleteRules.removeOwned", "delete behavior must use its tested pure rule")
require(service, 'response(result, player, id, action, false, "CharacterNotOwned")', "ownership validation missing")

require(responsive, "ResponsiveLayout.playerStatusSize(metrics)", "player status must use shared size policy")
require(responsive, "ResponsiveLayout.targetSize(metrics)", "target HUD must use shared size policy")
require(responsive, "ResponsiveLayout.primaryActionsSize(metrics)", "actions must use shared size policy")
require(responsive, "ResponsiveLayout.skillBarSize(metrics, 6)", "touch skill bar must use shared six-slot policy")
require(responsive, "metrics.safeBottomRight.X + metrics.edge", "right safe edge missing")
require(responsive, "metrics.safeTopLeft.Y + metrics.edge", "top safe edge missing")
require(responsive, "metrics.safeBottomRight.Y + metrics.edge", "bottom safe edge missing")

require(bar, "ResponsiveLayout.isLandscapeTouch(metrics)", "action bar must adapt across phone/tablet touch landscape")
require(bar, "local slotCount = if touchLandscape then 6 else 10", "six-slot touch bar missing")
require(bar, "ResponsiveLayout.skillBarSize(metrics, slotCount)", "skill bar size must be viewport driven")
require(bar, "ResponsiveLayout.primaryActionsSize(metrics)", "primary actions must be viewport driven")

require(hud, "local touchLayout = metrics.isTouch", "HUD internals must adapt for all touch layouts")
require(hud, "ResponsiveLayout.targetSize(metrics)", "target internal layout must use responsive size")
require(hud, "ResponsiveLayout.scaled(metrics", "HUD text/bar geometry must be bounded")
require(hud, "value.TextColor3 = Color3.fromRGB(10, 12, 16)", "dark in-bar values missing")

require(log, "ResponsiveLayout.combatLogExpandedSize(metrics)", "expanded log must be constrained")
require(log, "ResponsiveLayout.combatLogCollapsedSize(metrics)", "collapsed log must be constrained")
require(log, "if metrics.isTouch and not wasTouch then expanded = false", "touch log must start collapsed")
require(log, "gui.IgnoreGuiInset = true", "log must share the physical viewport coordinate space")

for body, name in ((quest, "Quest"), (economy, "Economy"), (inventory, "Inventory")):
    require(body, "ScrollingFrame", f"{name} mobile content must scroll")
require(responsive, 'child.Enabled = metrics.layoutClass == "Desktop"', "desktop minimum constraints must be disabled on touch")
require(inventory, 'blocker.Modal = true', "inventory gameplay input blocker missing")
require(economy, 'blocker.Modal = true', "economy gameplay input blocker missing")
require(economy, 'layout.Name = "MobileBlacksmithTopicsGrid"', "mobile blacksmith must use a compact grid")

for concept in ("safe viewport", "Fluid + clamp", "Touch target", "Adaptive composition", "Desktop regression"):
    require(design_doc, concept, f"design-system documentation missing {concept}")

print("mobile landscape adaptive UX contract: PASS")
