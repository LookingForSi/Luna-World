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
COMBAT = "src/server/features/combat/CombatCoordinator.luau"
ECONOMY = "src/server/services/EconomyService.luau"
STARTER = "src/shared/economy/StarterGearRules.luau"
ITEMS = "src/shared/definitions/ItemDefinitions.luau"
CLIENT_DEBUG = "src/client/ui/StudioTestPanel.luau"
HUD = "src/client/ui/CombatHud.luau"
MOBS = "src/shared/definitions/MobDefinitions.luau"
SERVER_MAIN = "src/server/bootstrap/adapters/ExistingServerComponents.luau"
CLIENT_MAIN = "src/client/bootstrap/adapters/ExistingClientComponents.luau"
DEFAULT_PROJECT = "default.project.json"

# The debug switch must be absent from the static production Rojo tree and created only by a Studio-gated server service.
if "StudioSetArchetype" in read(DEFAULT_PROJECT):
    raise AssertionError("StudioSetArchetype must not be statically exposed by the production Rojo project")
require(SERVER_DEBUG, "RunService:IsStudio()", "Studio archetype switching must be gated by RunService:IsStudio on the server")
require(SERVER_DEBUG, 'Instance.new("RemoteEvent")', "Studio archetype remote must be created dynamically by the Studio-only service")
require(SERVER_DEBUG, 'createRemote("StudioSetArchetype")', "Studio archetype remote name is missing")
require(SERVER_DEBUG, 'createRemote("StudioSetLevel")', "Studio level remote name is missing")
require(SERVER_DEBUG, 'createRemote("StudioToggleSpeed")', "Studio x5 speed remote name is missing")
require(SERVER_DEBUG, "ProgressionService._setLevelForStudio", "Studio debug service must delegate level changes to ProgressionService")
require(SERVER_DEBUG, "CombatCoordinator._setMovementMultiplierForStudio", "Studio debug service must delegate speed changes to CombatService")
require(SERVER_DEBUG, "CombatCoordinator._setArchetypeForStudio", "Studio debug service must delegate lifecycle reset to CombatService")
require(SERVER_DEBUG, "EconomyService._switchArchetypeForStudio", "Studio class switch must persist the selected archetype and starter weapon")
require(ECONOMY, "StarterGearRules.switchArchetype", "economy service must perform the authoritative starter-gear transition")
require(STARTER, "grantAndEquipForArchetype", "starter gear must support explicit class transitions")
require(STARTER, 'ranger = "weapon_ash_bow"', "ranger starter weapon mapping is missing")
require(STARTER, 'mystic = "weapon_ash_staff"', "mystic starter weapon mapping is missing")
require(ITEMS, '"Учебный лук"', "ranger starter display name must be Учебный лук")
require(ITEMS, '"Учебный посох"', "mystic starter display name must be Учебный посох")
require(COMBAT, "function CombatCoordinator._setArchetypeForStudio", "CombatCoordinator Studio archetype seam is missing")
require(COMBAT, 'assert(RunService:IsStudio()', "Studio archetype seam must hard-fail outside Studio")
require(COMBAT, "clearPlayerState(player, true)", "class switch must discard the old authoritative combat state before respawn")
require(COMBAT, "player:SetAttribute(ARCHETYPE_ATTRIBUTE, archetypeId)", "new archetype must be written after old combat state cleanup")
require(COMBAT, "player:LoadCharacter()", "class switch must rebuild combat state through the existing character lifecycle")
require(COMBAT, "function CombatCoordinator._setMovementMultiplierForStudio", "CombatCoordinator Studio movement seam is missing")
require(COMBAT, 'assert(RunService:IsStudio()', "Studio combat seams must hard-fail outside Studio")
require(SERVER_MAIN, "StudioDebugService.start()", "DevCombined compatibility lifecycle must start the Studio debug service")

# Client debug controls also have their own Studio guard; live clients must never render them.
require(CLIENT_DEBUG, "RunService:IsStudio()", "Studio class panel must be gated on the client")
for archetype_id in ("knight", "ranger", "mystic"):
    require(CLIENT_DEBUG, archetype_id, f"Studio class panel is missing {archetype_id}")
for token in ('"LevelDown"', '"LevelUp"', '"LevelMax"'):
    require(CLIENT_DEBUG, token, f"Studio level controls are missing {token}")
for token in ('"SpeedX5"', '"SPEED x5"', '"StudioToggleSpeed"'):
    require(CLIENT_DEBUG, token, f"Studio speed control is missing {token}")
require(CLIENT_MAIN, "StudioTestPanel.start()", "client bootstrap must start the Studio-only panel")

# Player HUD has four rows: PvP-only CP, HP, archetype resource, and XP.
for token in (
    '"CombatPoints"',
    '"CombatPointsFill"',
    '"PlayerHealth"',
    '"PlayerHealthFill"',
    '"PlayerResource"',
    '"PlayerResourceFill"',
    '"LevelXP"',
    '"LevelXPFill"',
):
    require(HUD, token, f"player HUD is missing row contract {token}")
require(HUD, "current / maximum", "player HP bar must be driven by the local Humanoid")
require(HUD, "currentValue / maximumValue", "resource bar must be driven by authoritative replicated resource values")
require(HUD, "Vector2.new(1, 0)", "player status HUD must anchor from the upper-right")
require(HUD, "HudLayout.CornerMargin", "player status HUD must use the shared corner margin")
require(HUD, "gui.IgnoreGuiInset = true", "player status top margin must not include the Roblox top inset")
require(HUD, '"STM"', "knight stamina HUD abbreviation is missing")
require(HUD, '"FCS"', "ranger focus HUD abbreviation is missing")
require(HUD, '"MP"', "mystic mana HUD abbreviation is missing")
require(HUD, '"PlayerName"', "player HUD must render the character name in its header")
require(HUD, "CharacterConfig.NicknameAttribute", "player HUD name must come from the selected Luna character")
require(HUD, "updatePlayerName", "player HUD must refresh the selected character nickname")
require(HUD, '"PlayerLevel"', "player HUD must render level on the same header line")
require(HUD, "ProgressionRules.requiredXP(level)", "XP HUD must reset against each current-level threshold")
require(CLIENT_MAIN, "SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)", "Roblox stock health display must not duplicate the custom HP HUD")

# Grey wolf damage is deliberately above the knight's current defense so an ordinary PvE hit is visible in acceptance testing.
require(MOBS, "basicAttackDamage = 20", "grey wolf needs visible post-mitigation damage against the knight test archetype")

print("Studio debug and player HUD contract: PASS")
