#!/usr/bin/env python3
"""Static contract check for the client-only no-free-jump controller."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CONTROLLER = ROOT / "src/client/controllers/MovementController.luau"
BOOTSTRAP = ROOT / "src/client/main.client.luau"


def require(source: str, token: str, message: str) -> None:
    if token not in source:
        raise AssertionError(message)


controller = CONTROLLER.read_text(encoding="utf-8")
bootstrap = BOOTSTRAP.read_text(encoding="utf-8")

require(controller, "BindActionAtPriority", "jump input must be consumed at explicit priority")
require(controller, "Enum.PlayerActions.CharacterJump", "all standard jump bindings must be consumed")
require(controller, "UnbindAction", "stop must remove the jump binding")
require(controller, "CharacterAdded:Connect", "character replacement must reapply the setting")
require(controller, "characterToken += 1", "each character application must invalidate older callbacks")
require(controller, "characterToken ~= expectedCharacterToken", "late humanoid waits must validate their character token")
require(controller, "Players.LocalPlayer.Character ~= character", "late humanoid waits must validate the active character")
require(controller, "SetStateEnabled(Enum.HumanoidStateType.Jumping, false)", "humanoid jump must be disabled")
if "SetStateEnabled(Enum.HumanoidStateType.Freefall" in controller:
    raise AssertionError("the controller must not change the freefall state")
require(controller, "JumpButton", "the standard mobile jump button must be hidden")
require(controller, "DescendantAdded:Connect", "late-created mobile controls must also be handled")
require(controller, 'GetPropertyChangedSignal("Visible")', "the standard jump button must stay hidden if CoreScripts toggle it")
require(controller, "jumpButtonVisibleConnection:Disconnect()", "jump button replacement must disconnect its listener")
require(controller, "jumpButtonWasVisible", "stop must preserve and restore the button's original visibility")
require(controller, "Disconnect()", "stop must disconnect lifecycle listeners")
require(bootstrap, "MovementController.start()", "client bootstrap must start movement controls")
require(bootstrap, "MovementController.stop()", "client bootstrap must stop movement controls")

print("Movement controller contract: PASS")
