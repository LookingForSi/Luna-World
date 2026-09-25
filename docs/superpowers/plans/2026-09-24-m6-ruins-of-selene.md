# M6 — Ruins of Selene — Implementation Plan

Дата: 2026-09-24  
Design: `docs/superpowers/specs/2026-09-24-m6-ruins-of-selene-design.md`  
Tracking: #79, release gate #63

## Batch 1 — contracts, handoff и lifecycle

1. Подключить принятый M5 baseline и добавить pure dungeon config/types/rules.
2. TDD: lifecycle, transition guards, participant validation, TTL/token, duplicate arrival, rejoin, wipe и exactly-once claim.
3. Реализовать MemoryStore handoff/run registry и authoritative Moonfall entry coordinator поверх публичного PartyService snapshot API.
4. Реализовать Dungeon admission/run service и trusted M5 party reconstruction без persistent party state.
5. Stabilization: hostile payload tests, transfer failure/recovery, lifecycle cleanup; commit/push.

## Batch 2 — dungeon content и encounters

1. Добавить deterministic greybox world layout и server-owned prompts/gates.
2. Добавить Selene mob definitions/spawn groups без изменения глобального balance pass.
3. Реализовать encounter sequencer поверх уникальных MobService entity deaths.
4. TDD: ordered unlock, stale/duplicate deaths, невозможность client gate skip.
5. Подключить Dungeon и DevCombined manifests; commit/push.

## Batch 3 — Guardian, failure и rewards

1. Реализовать pure boss transitions и authoritative runtime: base attack, telegraph/impact AoE, one-shot enrage, retarget.
2. Подключить individual respawn/checkpoints, full-wipe encounter reset и disconnect/rejoin TTL.
3. Реализовать exactly-once completion reward через Progression/Economy/Inventory APIs и server-owned exit.
4. TDD: AoE distance/dead checks, target loss, duplicate boss death/completion/reward replay.
5. Stabilization/security review; commit/push.

## Batch 4 — UI, documentation и final gate

1. Добавить минимальный dungeon HUD/presentation и понятный Moonfall entrance/exit feedback.
2. Обновить project mappings, runtime manifests, changelog и deployment/owner instructions без version bump/DataVersion change.
3. Запустить все `tests/check_*.py`, relevant Luau suites, canonical Rojo builds и `git diff --check`.
4. Исправить findings, обновить Draft PR ledger и оставить manual checks как **DEFERRED — pending owner runtime acceptance**.

## Owner Studio checklist (не автоматический PASS)

- SOLO: Moonfall entry → teleport → spawn → packs → miniboss → boss mechanics → one reward → exit/return.
- PARTY (`1 server + 2 clients` минимум): leader starts; один run/server; HUD; shared combat/rewards; one member death/respawn; boss; both return with valid party.
- FAILURE: disconnect/rejoin, full wipe/reset, repeated entry, leader disconnect, stale party snapshot/token, duplicate requests.
- DEV-COMBINED: local dungeon iteration доступна, production role boundaries/worldgen exclusion сохранены.
- PUBLISHED: реальный Lobby → Moonfall → reserved Dungeon → Moonfall teleport в test Experience; Studio Play не заменяет эту проверку.

## Integration/hardening pass

- [x] Profile lease release/acquire встроен в entry и return handoff.
- [x] Dungeon return и trusted M5 reconstruction подключены.
- [x] Scoped rejoin ticket направляет игрока в исходный reserved server.
- [x] Humanoid-based wipe, checkpoints и deterministic encounter reset подключены.
- [x] Guardian telegraph/enrage feedback и reset generation подключены.
- [x] Studio-only DevCombined adapter использует production dungeon services.
- [x] Entrance confirmation, objective HUD, completion/return и failure feedback добавлены.
- [x] TTL namespaces, structured diagnostics и replay/duplicate guards добавлены.
- [ ] **DEFERRED — OWNER ACCEPTANCE REQUIRED:** Studio multiplayer и published multi-Place проверки.
