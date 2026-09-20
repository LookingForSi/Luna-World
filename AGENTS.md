# Luna World — Agent Rules

This file defines mandatory rules for AI coding agents working in this repository.

## 1. Read before changing

At the start of a new worktree / feature branch, or after a context reset, read:

1. `README.md`
2. `docs/PRODUCT_VISION.md`
3. `docs/GAME_DESIGN_V0.1.md`
4. `docs/ARCHITECTURE.md`
5. `docs/DEVELOPMENT_RULES.md`
6. `docs/REFACTORING_POLICY.md`
7. `docs/TESTING_STRATEGY.md`
8. `docs/VERSIONING.md`

Then read the active specification / implementation plan for the task, if one exists.

Within the same uninterrupted implementation batch, do not repeatedly re-read unchanged standing documents just to satisfy process. Re-open only the documents or sections that are relevant to the current task, changed since the previous read, or are needed to resolve an ambiguity.

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
- crafting professions, collectible recipes, affixes or crafting tiers beyond the approved No-Grade blacksmith catalog;
- enchantment systems;
- mounts;
- pets;
- housing;
- battle pass;
- monetization shop;
- large raid systems.

The narrow village economy approved for v0.1 (merchant buy/sell, materials, No-Grade blacksmith crafting without recipe items, consumables and return scroll) is explicitly in scope.

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

## 14. Agent orchestration and context efficiency

Quality and correctness come first, but multi-agent workflows are not free. Use the least expensive workflow that still gives the task an appropriate level of independent scrutiny. Reduce duplicated context and duplicated review work before reducing tests, validation, or safety checks.

### 14.1 Default execution mode

For an approved specification and implementation plan, the default is one implementation agent executing a small coherent batch of related tasks, normally about 3–5 plan tasks or up to the next stabilization gate.

Within that batch:

- use TDD where applicable;
- self-check each task before committing it;
- commit and push each completed task separately so no finished work exists only in an ephemeral workspace;
- run one independent specification / code-quality review at the end of the batch or stabilization gate;
- fix review findings and re-run the relevant checks before continuing.

Do not automatically launch a fresh implementer, a separate specification reviewer, and a separate code-quality reviewer for every small or mechanical task. Use that heavier pattern only when task risk justifies the extra context and review cost.

### 14.2 When multiple agents are justified

Prefer a dedicated or fresh independent agent for work that has a materially high cost of subtle mistakes, especially:

- architecture or module-boundary changes;
- server-authority, RemoteEvent / RemoteFunction validation, abuse resistance, or other networking/security-sensitive work;
- persistence schemas and migrations;
- concurrency, delayed tasks, connection cleanup, lifecycle ownership, or race-prone state;
- substantial refactors that change interfaces across multiple systems;
- AI/pathfinding/state-machine changes with non-trivial shared state;
- difficult debugging after the normal systematic-debugging pass has not isolated the cause;
- any task for which the owner explicitly requests an independent implementation/review pass.

Use parallel agents only for tasks that are genuinely independent: they must not require the same mutable files, shared intermediate state, or sequential design decisions. If tasks depend on each other, run them sequentially.

### 14.3 Preferred workflow by task type

When the relevant workflow/skill is available, prefer:

- **brainstorming** — new product/design behavior, ambiguous requirements, or a choice that changes player-facing intent; do not use it for routine implementation of an already approved spec;
- **writing-plans** — an approved design that still needs a multi-step implementation plan;
- **executing-plans** — the default for implementing an approved plan in coherent batches;
- **subagent-driven-development** — high-risk implementation where fresh implementers/reviewers materially reduce risk, not as the default for every task;
- **test-driven-development** — features and bug fixes with testable behavior, especially pure/shared rules;
- **systematic-debugging** — any unexpected test/runtime failure before proposing fixes;
- **dispatching-parallel-agents** — two or more independent tasks with no shared mutable state or ordering dependency;
- **requesting-code-review** — stabilization gates, high-risk boundary changes, and final PR review; avoid repeating full review passes after trivial mechanical changes unless they can affect behavior;
- **receiving-code-review** — when acting on review feedback;
- **verification-before-completion** — before claiming a task, gate, bug fix, milestone, or PR is complete;
- **using-git-worktrees** — substantial feature work that should be isolated from the current workspace;
- **finishing-a-development-branch** — after implementation and verification, when deciding how to integrate the branch.

If model/reasoning-effort selection is available, use the lowest-capability configuration that is still reliable for deterministic mechanical work (formatting, straightforward translations, simple config edits, repetitive test scaffolding). Reserve higher reasoning effort for architecture, networking/security, persistence, complex debugging, and cross-system design. Do not choose a heavier configuration merely because a task is long.

### 14.4 Context-budget rules

At the beginning of a new feature/worktree or after a context reset, read the standing documents from section 1 plus the active spec/plan. During the same implementation batch:

- do not repeatedly re-read unchanged standing documents;
- load only the active spec/plan sections and source files needed for the current task;
- prefer concise references to paths/commits over pasting unchanged documents or large diffs into status messages;
- use the PR body / task ledger as the compact source of current progress instead of recreating the project history in every prompt;
- do not create duplicate status documents unless they have a clear long-lived purpose;
- avoid re-running expensive full reviews/builds after changes that cannot affect them, except where a required gate/final verification explicitly demands it.

Before a context, token, usage, or execution-time limit is reached:

1. finish the smallest safe unit of work;
2. commit it;
3. push it;
4. update the Draft PR/task ledger with the exact HEAD, completed tasks, checks run, deferred manual checks, and the next task;
5. leave the worktree clean whenever practical.

Never rely on an ephemeral agent workspace as the only copy of completed work.

### 14.5 Review granularity

Independent review should follow risk, not task count.

A single review can cover several closely related low/medium-risk tasks when they form one coherent subsystem and are followed by a stabilization gate. Require a dedicated review before continuing when a task changes a high-risk boundary listed in section 14.2.

Reviewers should inspect only the relevant diff plus the required contracts/spec sections whenever possible. They do not need to reconstruct the entire project history for every review.

### 14.6 Manual Roblox Studio checkpoints

Automated checks may continue without the owner. Manual Roblox Studio acceptance must never be silently converted into PASS.

If the owner explicitly permits deferring manual checkpoints:

- mark them `DEFERRED — pending owner runtime acceptance`;
- continue only when downstream work does not technically depend on the result of that manual test;
- record the risk that later work is temporarily built on an unverified runtime assumption;
- combine deferred checks into one minimal, non-duplicative owner acceptance checklist where practical.

If a later implementation decision genuinely depends on the manual result, stop at that point instead of guessing.

### 14.7 Usage-limit priority

When usage limits become a constraint, optimize in this order:

1. remove redundant agent handoffs and duplicated reviews;
2. batch related implementation tasks between stabilization gates;
3. reduce repeated context loading and status narration;
4. use lighter model/reasoning settings for mechanical work when available;
5. preserve required tests, server-authority checks, malicious-client checks, lifecycle cleanup review, and final verification.

Never save usage by skipping correctness checks that protect gameplay state, networking, persistence, or player data.

### 14.8 Direct repository changes when write access exists

When the agent has authorized write access to this repository and the owner asks for a code, documentation, configuration, or test change, perform the change directly in the repository whenever it is safe and technically possible.

Do not respond with copy-paste code snippets, manual patch instructions, or "you can change this line" guidance as the default workflow when the agent can make the edit itself. Do not ask the owner to edit source files merely to save agent effort.

Owner actions should be requested only when they genuinely require owner-side interaction, such as:

- Roblox Studio runtime / visual acceptance;
- device, gamepad, or touch testing unavailable to the agent;
- permissions, authentication, secrets, billing, or account-level actions;
- an unresolved product/design decision that materially changes intended behavior;
- destructive or irreversible actions requiring explicit approval.

After direct edits, report concisely what changed, the branch/HEAD when useful, what automated checks were run, and only the minimum manual acceptance still required.


## 15. World blockout integration constraints

The accepted v0.1 world topology is now a gameplay dependency, not a disposable preview.

- Terrain-touching architecture, fences, rocks, bridges and structural props must visibly meet or slightly overlap the ground. Visible floating gaps are acceptance failures even when collision still works.
- Main roads and intended walking tracks must read as cleared surfaces rather than grass with a road texture underneath.
- Encounter floors must be physically closed. Decorative depressions, caves and basins must not expose voids or endless-fall pockets.
- Water hazards use the shared traversal-recovery behavior; adding another water body must not create a second independent death/teleport contract.
- Deliberately non-traversable cliff faces may enforce routing, but their intended bypass road must remain walkable without jumping.
- WorldLayout.SpawnMarkers is the integration seam for authoritative mob placement. Do not restore hard-coded playground spawn coordinates in MobService.
- World blockout mob models are presentation placeholders only. Once a matching authoritative mob definition exists, the gameplay service owns the real entity and the corresponding placeholder must not coexist visually.
