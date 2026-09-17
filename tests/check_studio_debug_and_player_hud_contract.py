#!/usr/bin/env python3
"""Static smoke check for Studio-only archetype switching, player HUD bars, and visible wolf damage."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    candidate = ROOT / path
    if not candidate.exists():
        raise AssertionError(f"missing required file: {path}")
    return candidate.read_text(encoding="utf-8")


def require(path: str, token: str, message: str) -> None:
    if token not in read(path):
        raise AssertionError(message)


SERVER_DEBUG = "src/server/services/StudioDebugService.luau"
CLIENT_DEBUG = "src/client/ui/StudioTestPanel.luau"
HUD = "src/client/ui/CombatHud.luau"
MOBS = "src/shared/definitions/MobDefinitions.luau"
SERVER_MAIN = "src/server/main.server.luau"
CLIENT_MAIN = "src/client/main.client.luau"
DEFAULT_PROJECT = "default.project.json"

# The debug switch must be absent from the static production Rojo tree and created only by a Studio-gated server service.
if "StudioSetArchetype" in read(DEFAULT_PROJECT):
    raise AssertionError("StudioSetArchetype must not be statically exposed by the production Rojo project")
require(SERVER_DEBUG, "RunService:IsStudio()", "Studio archetype switching must be gated by RunService:IsStudio on the server")
require(SERVER_DEBUG, 'Instance.new("RemoteEvent")', "Studio archetype remote must be created dynamically by the Studio-only service")
require(SERVER_DEBUG, 'created.Name = "StudioSetArchetype"', "Studio archetype remote name is missing")
require(SERVER_DEBUG, "ArchetypeDefinitions[archetypeId]", "server must validate requested archetypes")
require(SERVER_DEBUG, "player:LoadCharacter()", "class switch must rebuild combat state through the existing character lifecycle")
require(SERVER_MAIN, "StudioDebugService.start()", "server bootstrap must start the Studio debug service")

# Client debug controls also have their own Studio guard; live clients must never render them.
require(CLIENT_DEBUG, "RunService:IsStudio()", "Studio class panel must be gated on the client")
for archetype_id in ("knight", "ranger", "mystic"):
    require(CLIENT_DEBUG, archetype_id, f"Studio class panel is missing {archetype_id}")
require(CLIENT_MAIN, "StudioTestPanel.start()", "client bootstrap must start the Studio-only panel")

# Player HUD needs two bar containers: HP and class resource. Numeric resource text is intentionally not the primary presentation.
for token in ("PlayerHealthBar", "PlayerHealthFill", "PlayerResourceBar", "PlayerResourceFill"):
    require(HUD, token, f"player HUD is missing {token}")
require(HUD, "humanoid.Health / humanoid.MaxHealth", "player HP bar must be driven by the local Humanoid")
require(HUD, "currentValue / maximumValue", "resource bar must be driven by authoritative replicated resource values")

# Grey wolf damage is deliberately above the knight's current defense so an ordinary PvE hit is visible in acceptance testing.
require(MOBS, "basicAttackDamage = 22", "grey wolf needs visible post-mitigation damage against the knight test archetype")

print("Studio debug and player HUD contract: PASS")
