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

## 3. World traversal and elevation

Luna World does not use free jumping as a normal traversal mechanic.

All playable world geometry must therefore be traversable with ordinary ground movement:

- never require the player to jump to enter, leave, or move between intended playable areas;
- whenever one playable territory, terrace, road, camp, platform, or zone is raised above another, provide a continuous walkable transition such as an inclined ramp / slope / transition slab;
- elevation changes must be intentionally connected in both directions unless a one-way transition is an explicit product decision;
- do not leave playable ledges that allow the player to drop down but provide no ground path back;
- stairs may be used only when their collision and step height are verified to be walkable without jumping; for greybox work, prefer explicit sloped transition geometry;
- world-block acceptance must include a traversal check that all intended routes can be completed without jumping.
- bridges and other crossings must overlap their bank / landing geometry enough that a character cannot fall into a seam between terrain and the crossing;
- any intentionally non-walkable water body or deep traversal hazard must define a recovery behavior to the most recent safe grounded position; do not allow no-jump players to become trapped below a bank or inside a decorative trench;

This rule applies to greybox generation as well as final terrain and environment art.

### 3.1. Environment art and external asset packs

Approved world geography and traversal drive the art pass, not the other way around.

- Do not reshape accepted roads, encounter footprints, elevation transitions, sightlines, or zone topology merely to fit a purchased / downloaded asset pack.
- Blender / Blender Studio / marketplace assets are modular source material. Replace accepted blockout silhouettes category by category instead of importing a prebuilt map.
- Verify that the specific asset license permits the intended export and in-game use before committing it to the project. A subscription alone is not proof that every asset has the same license.
- Preserve the footprint and collision intent of the accepted placeholder unless a deliberate level-design change is approved.
- Use simple collision proxies for environment meshes. Decorative crowns, webs, foliage and small clutter should normally be non-collidable.
- Never let decorative props create a jump requirement, hidden step, one-way ledge, narrow critical-route choke, or collision trap.
- Keep Roblox Terrain as the primary playable landscape; MeshParts are for architecture, landmarks, rocks, roots, ruins and other modular environment art.

## 4. Server authority is mandatory

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

## 5. Module boundaries

Prefer small modules with one clear responsibility.

Do not create catch-all modules such as `GameManager`, `EverythingService`, or a single service that owns combat, inventory, quests, persistence, and UI at once.

Public module interfaces must be understandable without reading their internals. Avoid hidden cross-module mutation.

Shared definitions belong in shared modules; server-only logic must not be moved to replicated client-visible locations.

## 6. Data-driven content

Items, mobs, skills, quests, classes, and progression values should be represented as data/configuration where practical rather than duplicated across scripts.

Do not hardcode the same balance value in multiple modules.

Stable IDs are preferred over display names for persistent references.

## 7. Persistence safety

Persistent data has its own schema version (`DataVersion`) independent of the game release version.

Never change a persisted structure without considering existing saves.

Any breaking save-schema change requires a migration path and tests covering an older representative save.

Never write transient runtime instances or Roblox objects directly into persistent data.

## 8. Testing

Behavior changes require tests at the lowest practical layer.

Before declaring a gameplay milestone complete, run the relevant unit/integration tests and perform a Roblox multiplayer playtest with at least:

- 1 server;
- 2 clients.

For networking features, test invalid / malicious client requests as well as normal requests.

Do not remove or weaken a failing test merely to make the suite pass unless the underlying requirement was explicitly changed.

## 9. Refactoring discipline

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

## 10. Scope control

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

## 11. Language and code style

- Project, product, design, architecture, roadmap, testing, versioning, release and implementation-plan documentation must be written in Russian.
- `AGENTS.md` is the only standing exception and may remain in English so that coding agents can consume the rules consistently.
- Source code identifiers: English.
- Code comments: English unless a specific domain explanation is materially clearer in Russian.
- Do not create new English-language documentation files unless the owner explicitly requests an exception.
- Prefer explicit Luau types on module boundaries and important data structures.
- Avoid magic numbers; place tunable values in configuration.
- Keep warnings/errors actionable and include useful context without exposing secrets.

## 12. Dependencies and tooling

Do not introduce a third-party dependency without explaining why the Roblox platform / standard Luau code is insufficient.

Tool versions should be managed through the repository toolchain (Rokit where applicable).

Do not edit Rojo-managed scripts only inside Roblox Studio. Source files in Git are authoritative.

## 13. Versioning and changelog

Follow `docs/VERSIONING.md`.

User-visible or behaviorally meaningful changes must be reflected in `CHANGELOG.md` when preparing a release.

Do not bump versions casually during intermediate edits; version changes happen as part of a release or explicitly requested milestone transition.

## 14. Completion rule

Never claim a task, milestone, refactor, migration, or bug fix is complete without evidence from the relevant checks/tests.

If verification cannot be performed, state exactly what remains unverified.
