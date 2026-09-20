#!/usr/bin/env python3
"""Static smoke check for the client cross-platform combat contract."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def require(path: str, token: str, message: str) -> None:
    source = (ROOT / path).read_text(encoding="utf-8")
    if token not in source:
        raise AssertionError(message)


INPUT = "src/client/controllers/CombatInputController.luau"
TARGET = "src/client/controllers/TargetController.luau"
BAR = "src/client/ui/ActionBar.luau"
HUD = "src/client/ui/CombatHud.luau"

for token in ("Enum.KeyCode.F", "Enum.KeyCode.ButtonR2", "Enum.KeyCode.ButtonL2"):
    require(INPUT, token, f"missing combat binding: {token}")
for token in ("Enum.KeyCode.ButtonX", "Enum.KeyCode.ButtonY", "Enum.KeyCode.ButtonB"):
    require(INPUT, token, f"missing gamepad skill binding: {token}")
require(INPUT, "inputState ~= Enum.UserInputState.Begin", "actions must be one-shot Begin intents")
require(INPUT, "navigatingGui(inputObject)", "all gamepad combat callbacks must share the navigation guard")
require(INPUT, "CombatInputController.stop()", "input restart must clean old bindings before rebinding")
require(INPUT, "attackHeld", "held Attack must not emit duplicate intents")
require(TARGET, "getTouchProbeOffsets", "touch target selection must use bounded forgiveness")
require(TARGET, "screenRectDistance", "desktop target selection must use silhouette-aware screen-space forgiveness")
require(TARGET, "GetBoundingBox", "desktop target selection must preserve a fallback bounding box")
require(TARGET, 'model:FindFirstChild("HumanoidRootPart")', "desktop forgiveness must align to the visible mob silhouette")
require(TARGET, "boxCFrame = visibleRoot.CFrame", "screen-space pick bounds must not be dragged by the invisible hitbox")
require(TARGET, "DESKTOP_PICK_PADDING", "desktop target selection must define a bounded pick margin")
require(TARGET, "DESKTOP_PICK_PADDING = 52", "desktop target selection must use the expanded pick margin")
require(TARGET, "GuiService:GetGuiInset()", "pointer coordinates must be converted from screen to viewport space")
require(TARGET, "toViewportPosition", "mouse/touch target selection must compensate for the GUI inset")
require(TARGET, "Enum.KeyCode.ButtonR3", "gamepad must provide a target command")
require(TARGET, "requestNearestVisibleTarget", "target cycling must remain a client candidate request")
require(TARGET, 'targetRequest:FireServer("")', "all devices need a semantic target-clear command")
require(TARGET, "canonicalPlayerTargetId", "friendly players must use canonical target ids")
require(TARGET, "TargetController.stop()", "target restart must clean old connections and actions")
require(TARGET, "shouldIgnoreForGuiNavigation", "gamepad target callbacks must respect GUI navigation")
require(TARGET, '"^player:(%-?%d+)$"', "Studio negative user IDs must parse as canonical player targets")
require(BAR, "UserInputService.TouchEnabled", "mobile must receive a custom enlarged Attack action")
require(BAR, "UISizeConstraint", "action bar must fit narrow mobile viewports")
require(BAR, "SkillCooldownAttributePrefix", "skill cooldown display must use server attributes")
require(BAR, "BasicAttackReadyAtAttribute", "Attack cooldown display must use server attributes")
require(BAR, 'for index = 1, 10 do', "skill bar must expose ten stable slots")
require(BAR, '"SkillBar"', "skills must live in a separate skill bar")
require(BAR, '"ИНВЕНТАРЬ [I]"', "primary actions must expose inventory")
require(BAR, 'button.Text = ""', "locked skills must stay visually hidden until unlock")
require(HUD, "CombatPresentationRules.isSupported", "rejection feedback must validate server presentation")
require(HUD, "getRejectionText", "known server rejection reasons must be rendered")
require(HUD, "TextChatService.ChatWindowConfiguration", "HUD must place the stock chat explicitly")
require(HUD, "Enum.VerticalAlignment.Bottom", "chat window must live at the lower-left")
require(HUD, "Vector2.new(1, 0)", "player status HUD must anchor from the upper-right")
require(HUD, "UDim2.new(1, -HudLayout.CornerMargin, 0, HudLayout.CornerMargin)", "player status HUD must use the shared upper-right corner margin")

server = (ROOT / "src/server/services/CombatService.luau").read_text(encoding="utf-8")
if 'if entityId == "" then' not in server or 'select("#", ...)' not in server:
    raise AssertionError("server target clear must accept only one exact empty-string request")
if "local function facePlayerTowardModel" not in server:
    raise AssertionError("accepted player attacks must automatically face their target")
if "local isFacing = ActionRules.isFacing(" in server:
    raise AssertionError("player attacks must not require manual pre-facing before acceptance")
if "facePlayerTowardModel(player, initialTarget)" not in server:
    raise AssertionError("basic attack acceptance must rotate the actor toward its target")
if "facePlayerTowardModel(player, target.model)" not in server:
    raise AssertionError("facing-required skills must rotate the actor toward their accepted target")

print("Cross-platform combat client contract: PASS")
