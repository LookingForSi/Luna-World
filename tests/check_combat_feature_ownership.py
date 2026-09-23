#!/usr/bin/env python3
"""Server combat feature ownership contract."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    candidate = ROOT / path
    assert candidate.exists(), f"missing combat feature file: {path}"
    return candidate.read_text(encoding="utf-8")


adapter = read("src/server/bootstrap/adapters/ExistingServerComponents.luau")
coordinator = read("src/server/features/combat/CombatCoordinator.luau")

assert "serverRoot.features.combat.CombatCoordinator" in adapter
assert "serverRoot.services.CombatService" not in adapter
assert not (ROOT / "src/server/services/CombatService.luau").exists(), "obsolete CombatService compatibility facade returned"

seams = {
    "PlayerCombatState": ("function PlayerCombatState.new", "skillSlot = SkillActionLifecycle.createSlot()"),
    "TargetingService": ("function TargetingService.findPlayerByCanonicalTargetId", "CFrame.lookAt"),
    "BasicAttackService": ("function BasicAttackService.getDefinition", "DamageRules.getBasicAttackInterval"),
    "SkillExecutionService": ("function SkillExecutionService.evaluate", "SkillRules.canAccept"),
    "AutoAttackService": ("function AutoAttackService.evaluateEnable", "function AutoAttackService.evaluateTick"),
}
for module_name, implementation_tokens in seams.items():
    source = read(f"src/server/features/combat/{module_name}.luau")
    assert f"require(script.Parent.{module_name})" in coordinator
    for token in implementation_tokens:
        assert token in source, f"{module_name} lost real implementation token {token}"
    assert len(source.splitlines()) > 20, f"{module_name} regressed to a placeholder"

for remote in ("targetRequest", "attackRequest", "autoAttackModeRequest", "skillRequest"):
    assert f"{remote}.OnServerEvent:Connect" in coordinator, f"Coordinator lost authoritative {remote} ownership"

assert "function CombatCoordinator.start" in coordinator
assert "function CombatCoordinator.stop" in coordinator

print("Combat feature ownership: PASS")
