# Luna World v0.1 — Design Specification

Date: 2026-09-13
Status: proposed / ready for owner review
Target release: `0.1.0`
Current development version: `0.1.0-dev.0`

## 1. Decision summary

Luna World v0.1 is a **Vertical Slice**, not a tech demo and not a mini-MMO.

The game is a standalone Roblox multiplayer RPG inspired by the *feeling* of Lineage II C4 / Interlude: serious stylized fantasy, spacious environments, target-based PvE, meaningful progression and rare loot. It must not copy Lineage II IP, assets, names, maps, UI, music, lore, or other protected elements.

Movement is modern (`WASD / gamepad / touch`), while combat follows classic MMORPG target-based principles.

The v0.1 route is:

`Luna Village → Moonfall Valley → Ruins of Selene`

Target first-play session: roughly 45–90 minutes.

Level cap: 10.

## 2. Product success criterion

The slice must answer three questions positively:

1. Does the player want to kill one more mob?
2. Does the player want to see what the next meaningful drop is?
3. After the first dungeon boss, does the player want to see more of the world?

Commercial validation is not required for v0.1.

## 3. Required gameplay systems

v0.1 requires:

- character/archetype selection;
- modern character movement;
- target selection and target frame;
- server-authoritative autoattack;
- active skills and cooldowns;
- mob AI with aggro/chase/leash/attack/return;
- XP and levels 1–10;
- loot tables;
- inventory;
- visible equipment changes where practical;
- short quest chain;
- party up to 4 players;
- open-world elite/miniboss;
- instanced dungeon;
- final dungeon boss;
- persistent character progress.

Explicitly excluded: PvP, clans, castle sieges, player trading, auction house, crafting, enchantment, mounts, pets, housing, large raids, battle pass and monetization shop.

## 4. Character archetypes

Three archetypes are sufficient for v0.1:

- Knight — durable melee;
- Ranger — ranged physical DPS;
- Mystic — magic damage with limited support/heal.

Each has a basic attack and approximately three active abilities. Names are working names until content/lore pass.

## 5. World design

### Luna Village

Safe starting settlement with onboarding, NPCs, basic merchant/blacksmith interactions and the road into the world. It must feel like a place, not a button lobby.

### Moonfall Valley

Shared multiplayer PvE region with escalating danger, several visual subareas, multiple mob types, an elite/miniboss and a visible connection toward the dungeon.

### Ruins of Selene

Short 1–4 player instanced dungeon lasting roughly 8–15 minutes. Final boss has at least a basic attack, readable telegraphed AoE and low-HP enrage/escalation.

## 6. Art direction

Reference mood: early Lineage II C4 / Interlude.

Required qualities:

- serious stylized fantasy;
- near-human character proportions;
- stone/wood/forest/ruin visual language;
- restrained saturation;
- moon/silver/cold-light motifs for Luna identity;
- readable silhouettes and combat telegraphs;
- limited visual noise;
- UI inspired by classic PC MMORPG ergonomics but adapted for mobile.

The project deliberately avoids direct replication of any copyrighted game assets or designs.

## 7. Technical architecture

The server is authoritative for gameplay-relevant state.

Client responsibilities: input, camera, target intent, UI, presentation/FX and action requests.

Server responsibilities: validation, combat results, cooldowns, XP, loot, inventory ownership, currency, quests, party eligibility, dungeon rewards and persistence.

Planned source layout:

```text
src/client
src/server
src/shared
tests
docs
```

Planned Rojo mapping:

```text
src/shared  -> ReplicatedStorage/Shared
src/server  -> ServerScriptService/Server
src/client  -> StarterPlayer/StarterPlayerScripts/Client
```

No external backend, PostgreSQL, Redis, custom auth or generic framework is required for v0.1 unless a real platform limitation is demonstrated.

## 8. Persistence

Persistent state includes at minimum:

- archetype;
- level;
- XP;
- currency;
- inventory;
- equipment;
- unlocked skills;
- quest state.

Persistence uses an independent integer `DataVersion` with sequential migrations. Game SemVer does not replace save-schema versioning.

A load/migration failure must never silently become a fresh empty profile.

## 9. Versioning

Game releases follow SemVer.

Development begins at `0.1.0-dev.0`; first accepted vertical slice releases as `0.1.0`.

Meaningful release changes are tracked in `CHANGELOG.md` and release commits are tagged as `vX.Y.Z`.

## 10. Testing

Testing is layered:

- unit tests for deterministic logic;
- integration tests across gameplay systems;
- Roblox runtime/playtests for replication, character lifecycle, UI, physics and platform behavior.

Every gameplay milestone requires a multiplayer smoke test with at least `1 server + 2 clients`.

Every gameplay Remote must also be tested against invalid/malicious requests appropriate to its contract.

Persistence schema changes require migration tests using representative older data.

## 11. Refactoring policy

Each major milestone is followed by a stabilization/refactor gate before the next large feature block begins.

The gate includes:

- green tests;
- regression cleanup;
- dead-code removal;
- duplication reduction;
- module-boundary review;
- network validation review;
- lifecycle/cleanup review;
- persistence migration review;
- documentation update.

Large rewrites without a specific problem and verification strategy are not allowed.

## 12. Implementation order

1. Playground: Wolf target/attack/damage/death/XP/respawn in multiplayer.
2. Combat & Skills.
3. Progression, Loot & Persistence.
4. Luna Village & Quests.
5. Moonfall Valley.
6. Party & Multiplayer Hardening.
7. Ruins of Selene.
8. Full v0.1 alpha candidate and external playtest.

Each step has a stabilization gate as described in `docs/ROADMAP.md`.

## 13. Canonical detailed documents

This spec is the approval snapshot. Detailed living rules are maintained in:

- `docs/PRODUCT_VISION.md`;
- `docs/GAME_DESIGN_V0.1.md`;
- `docs/WORLD_AND_ART_DIRECTION.md`;
- `docs/ARCHITECTURE.md`;
- `docs/DEVELOPMENT_RULES.md`;
- `docs/TESTING_STRATEGY.md`;
- `docs/VERSIONING.md`;
- `docs/ROADMAP.md`;
- `AGENTS.md`.

If implementation discovers a necessary contradiction, the contradiction must be raised and the relevant design document updated deliberately rather than bypassed silently.
