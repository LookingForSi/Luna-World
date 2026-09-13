# Luna World — Agent Rules

This file defines mandatory rules for AI coding agents working in this repository.

## 1. Read before changing

Before implementing or modifying behavior, read:

1. `README.md`
2. `docs/PRODUCT_VISION.md`
3. `docs/GAME_DESIGN_V0.1.md`
4. `docs/ARCHITECTURE.md`
5. `docs/DEVELOPMENT_RULES.md`
6. `docs/REFACTORING_POLICY.md`
7. `docs/TESTING_STRATEGY.md`
8. `docs/VERSIONING.md`

If a task conflicts with these documents, stop and report the conflict instead of silently overriding the design.

## 2. Preserve project intent

Luna World is a serious stylized fantasy RPG inspired by the *feeling* of classic MMORPGs such as Lineage II C4 / Interlude. It is not a clone.

Do not add copyrighted names, music, models, UI, lore, maps, characters, logos, icons, or other protected assets from Lineage II or any other game.

Do not convert the visual or gameplay direction into bright arcade / simulator / obby / gacha conventions unless an explicit product decision changes the design.

## 3. Server authority is mandatory

The server is the source of truth for all gameplay-relevant state, including:

- damage and healing;
- target validation;
- skill eligibility and cooldowns;
- XP and level changes;
- loot rolls;
- inventory changes;
- equipment changes;
- currency;
- quest completion;
- dungeon rewards;
- persistent player data.

Clients may request actions and render feedback. Clients must not decide authoritative outcomes.

Every RemoteEvent / RemoteFunction handling player input must validate its arguments and the requesting player's eligibility on the server.

## 4. Module boundaries

Prefer small modules with one clear responsibility.

Do not create catch-all modules such as `GameManager`, `EverythingService`, or a single service that owns combat, inventory, quests, persistence, and UI at once.

Public module interfaces must be understandable without reading their internals. Avoid hidden cross-module mutation.

Shared definitions belong in shared modules; server-only logic must not be moved to replicated client-visible locations.

## 5. Data-driven content

Items, mobs, skills, quests, classes, and progression values should be represented as data/configuration where practical rather than duplicated across scripts.

Do not hardcode the same balance value in multiple modules.

Stable IDs are preferred over display names for persistent references.

## 6. Persistence safety

Persistent data has its own schema version (`DataVersion`) independent of the game release version.

Never change a persisted structure without considering existing saves.

Any breaking save-schema change requires a migration path and tests covering an older representative save.

Never write transient runtime instances or Roblox objects directly into persistent data.

## 7. Testing

Behavior changes require tests at the lowest practical layer.

Before declaring a gameplay milestone complete, run the relevant unit/integration tests and perform a Roblox multiplayer playtest with at least:

- 1 server;
- 2 clients.

For networking features, test invalid / malicious client requests as well as normal requests.

Do not remove or weaken a failing test merely to make the suite pass unless the underlying requirement was explicitly changed.

## 8. Refactoring discipline

Follow `docs/REFACTORING_POLICY.md`.

Refactoring and feature work should be separated when practical.

Between major milestones, perform a stabilization pass before starting the next large feature block:

- make tests green;
- remove dead code;
- reduce duplication;
- repair unclear module boundaries;
- remove temporary debug paths;
- review Remote validation;
- review persistence migrations;
- update documentation.

Do not carry known structural debt indefinitely because “the next feature is small”.

## 9. Scope control

v0.1 is a vertical slice. Do not add out-of-scope systems without explicit approval.

Examples currently out of scope:

- PvP;
- clans / guild wars;
- castle sieges;
- player trading;
- auction house;
- crafting;
- enchantment systems;
- mounts;
- pets;
- housing;
- battle pass;
- monetization shop;
- large raid systems.

When a requested change implies one of these systems, call it out instead of silently expanding the project.

## 10. Language and code style

- Project, product, design, architecture, roadmap, testing, versioning, release and implementation-plan documentation must be written in Russian.
- `AGENTS.md` is the only standing exception and may remain in English so that coding agents can consume the rules consistently.
- Source code identifiers: English.
- Code comments: English unless a specific domain explanation is materially clearer in Russian.
- Do not create new English-language documentation files unless the owner explicitly requests an exception.
- Prefer explicit Luau types on module boundaries and important data structures.
- Avoid magic numbers; place tunable values in configuration.
- Keep warnings/errors actionable and include useful context without exposing secrets.

## 11. Dependencies and tooling

Do not introduce a third-party dependency without explaining why the Roblox platform / standard Luau code is insufficient.

Tool versions should be managed through the repository toolchain (Rokit where applicable).

Do not edit Rojo-managed scripts only inside Roblox Studio. Source files in Git are authoritative.

## 12. Versioning and changelog

Follow `docs/VERSIONING.md`.

User-visible or behaviorally meaningful changes must be reflected in `CHANGELOG.md` when preparing a release.

Do not bump versions casually during intermediate edits; version changes happen as part of a release or explicitly requested milestone transition.

## 13. Completion rule

Never claim a task, milestone, refactor, migration, or bug fix is complete without evidence from the relevant checks/tests.

If verification cannot be performed, state exactly what remains unverified.
