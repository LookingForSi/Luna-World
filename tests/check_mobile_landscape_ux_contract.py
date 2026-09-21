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

require(project, '"ScreenOrientation": "LandscapeSensor"', "StarterGui must request landscape sensor")
require(main, "playerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor", "PlayerGui orientation fallback missing")
assert main.index("ScreenOrientation") < main.index("CharacterLobbyController.start()")

for token in ("MobileLandscape", "MobileEdgeMargin", "MinimumTouchTarget", "MobileModalHorizontalMargin"):
    require(layout, token, f"shared mobile policy missing {token}")
require(lobby, "mobileLandscape", "lobby must have a mobile landscape composition")
require(lobby, 'Name = "DeleteCharacterModal"', "two-step delete modal missing")
require(lobby, 'chosen.nickname or "Без имени"', "unnamed character fallback missing")
assert "DELETE:nil" not in lobby and "DeleteConfirmationPrefix .. tostring" not in service
require(service, "p.confirmed ~= true", "server explicit confirmation missing")
require(service, "if canonical ~= nil then", "unnamed nickname release guard missing")
require(service, 'response(result, player, id, action, false, "CharacterNotOwned")', "ownership validation missing")

require(responsive, "Vector2.new(1, 0)", "player status top-right anchor missing")
require(responsive, "metrics.safeBottomRight.X + metrics.margin", "right safe edge missing")
require(responsive, "UDim2.new(0.5, 0, 0, metrics.safeTopLeft.Y", "target top-center missing")
require(responsive, "metrics.safeBottomRight.Y + metrics.margin", "bottom edge placement missing")
require(bar, "local slotCount = if mobileLandscape then 6 else 10", "six-slot mobile bar missing")
require(hud, "value.TextColor3 = Color3.fromRGB(10, 12, 16)", "dark in-bar values missing")
require(hud, 'bar.Position = UDim2.fromOffset(8, y)', "mobile in-bar layout missing")
require(log, "if ResponsiveLayout.isSmallTouch(metrics) and not wasSmallTouch then expanded = false", "mobile log must start collapsed")

for body, name in ((quest, "Quest"), (economy, "Economy"), (inventory, "Inventory")):
    require(body, "ScrollingFrame", f"{name} mobile content must scroll")
require(responsive, "child.Enabled = metrics.mode == \"Desktop\"", "desktop minimum constraints must be disabled on mobile")
require(inventory, 'blocker.Modal = true', "inventory gameplay input blocker missing")
require(economy, 'blocker.Modal = true', "economy gameplay input blocker missing")
require(economy, 'layout.Name = "MobileBlacksmithTopicsGrid"', "mobile blacksmith must use a compact 2x2 grid")

print("mobile landscape UX contract: PASS")
