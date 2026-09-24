#!/usr/bin/env python3
"""M5 party service ordering and shared composition contract."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
adapter = (ROOT / "src/server/bootstrap/adapters/ExistingServerComponents.luau").read_text()
world = (ROOT / "src/server/bootstrap/manifests/WorldServerManifest.luau").read_text()

for token in ("PartyService", "PartyNetworkService", "KillCreditService"):
    assert f'component("{token}"' in adapter, f"missing shared {token} component"

ordered = ["Components.party()", "Components.partyNetwork()", "Components.mobs()",
           "Components.killCredit()", "Components.loot()", "Components.quests()"]
positions = [world.index(token) for token in ordered]
assert positions == sorted(positions), "World party/reward consumers have unsafe startup order"

dev_ordered = ["PartyService.start()", "PartyNetworkService.start()", "MobService.start()",
               "KillCreditService.start()", "LootService.start()", "QuestService.start()"]
positions = [adapter.index(token) for token in dev_ordered]
assert positions == sorted(positions), "DevCombined must use the same party feature graph"

print("Party runtime composition contract: PASS")
