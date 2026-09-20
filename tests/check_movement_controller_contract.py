#!/usr/bin/env python3
"""Static contract for land no-jump plus stock Terrain swimming controls."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTROLLER = ROOT / "src/client/controllers/MovementController.luau"
BOOTSTRAP = ROOT / "src/client/main.client.luau"


def require(source: str, token: str, message: str) -> None:
    if token not in source:
        raise AssertionError(message)


controller = CONTROLLER.read_text(encoding="utf-8")
bootstrap = BOOTSTRAP.read_text(encoding="utf-8")

require(controller, "BindActionAtPriority", "jump input must be handled at explicit priority")
require(controller, "Enum.PlayerActions.CharacterJump", "standard jump action must be intercepted")
require(controller, "Enum.HumanoidStateType.Swimming", "swimming state must be recognized")
require(controller, "Enum.ContextActionResult.Pass", "swimming jump/swim-up input must pass to Roblox")
require(controller, "Enum.ContextActionResult.Sink", "land free-jump input must remain blocked")
require(controller, "humanoid.StateChanged:Connect", "swim transitions must update mobile controls")
require(controller, "swimming = nextState == Enum.HumanoidStateType.Swimming", "swimming state must drive policy")
require(controller, "humanoid.Jump = false", "held swim-up input must not leak into land jumping")
require(controller, "desiredJumpButtonVisible", "mobile jump button must use state-aware visibility")
require(controller, "return swimming", "mobile jump button must only be visible while swimming")
require(controller, "JumpButton", "stock mobile jump button must be managed")
require(controller, "DescendantAdded:Connect", "late-created mobile controls must also be managed")
require(controller, 'GetPropertyChangedSignal("Visible")', "CoreScript visibility changes must be reconciled")
require(controller, "jumpButtonWasVisible", "stop must restore original mobile button visibility")
require(controller, "CharacterAdded:Connect", "character replacement must reapply movement policy")
require(controller, "characterToken += 1", "late character callbacks must be invalidated")
require(controller, "UnbindAction", "stop must remove the jump binding")
require(controller, "Disconnect()", "stop must disconnect lifecycle listeners")

if "SetStateEnabled(Enum.HumanoidStateType.Jumping, false)" in controller:
    raise AssertionError("Jumping state must stay available so stock swimming can leave the water")
if "JumpPower = 0" in controller or "JumpHeight = 0" in controller:
    raise AssertionError("MovementController must not zero Roblox jump/swim physics")

require(bootstrap, "MovementController.start()", "client bootstrap must start movement controls")
require(bootstrap, "MovementController.stop()", "client bootstrap must stop movement controls")

print("Movement controller swimming contract: PASS")
