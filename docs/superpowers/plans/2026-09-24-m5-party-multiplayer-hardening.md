# M5 — Party & Multiplayer Hardening — Implementation Plan

Дата: 2026-09-24  
Design: `docs/superpowers/specs/2026-09-24-m5-party-multiplayer-hardening-design.md`  
Tracking: GitHub Issue #76  
Baseline: `main`, `0.1.0-alpha.3`

## Общие правила выполнения

- Работать в отдельной ветке, рекомендуемое имя: `feature/m5-party-multiplayer`.
- Не менять `VERSION` в процессе реализации.
- Не менять persistence `DataVersion`.
- Все gameplay/membership/reward decisions — server authoritative.
- TDD для pure rules и Remote validation.
- После каждого законченного task — отдельный commit + push.
- После Task 5 выполнить первый stabilization/review gate.
- После Task 8 выполнить финальный automated gate.
- Manual Roblox Studio acceptance не объявлять PASS без owner test.
- Не начинать M6 dungeon implementation внутри этого PR.

## Task 1 — Shared party contracts и pure rules

### Создать

- `src/shared/party/PartyConfig.luau`
- `src/shared/party/PartyTypes.luau`
- `src/shared/party/PartyRules.luau`
- `tests/PartyRulesSpec.luau`
- `tests/PartyRewardRulesSpec.luau`

### Зафиксировать

`PartyConfig` минимум:

- `MaxMembers = 4`;
- `InviteTtlSeconds = 30`;
- `InvitePairCooldownSeconds = 3`;
- `RewardRadiusStuds = 120`.

`PartyRules` должен быть pure и покрывать:

- canInvite / canAccept;
- add/remove member;
- deterministic leader successor;
- auto-disband при одном member;
- stable join order;
- XP split без создания дополнительного XP budget;
- round-robin cursor среди eligible userIds;
- invite expiration.

Не передавать Roblox `Player` Instances в pure rules.

### Tests

Минимум:

- 1→2 создание;
- 2→3→4;
- попытка 5-го;
- leader successor;
- member leave;
- leader leave;
- disband;
- XP 40/1, 40/2, 41/3;
- round-robin с temporarily ineligible member;
- expired invite.

### Commit

`feat(party): add shared party rules and reward contracts`

---

## Task 2 — Server PartyService

### Создать

- `src/server/features/party/PartyService.luau`
- service-level tests/fixture в принятом repo стиле.

### Runtime state

Внутренне:

```text
partiesById
partyIdByUserId
pendingInvitesById
invitePairCooldown
service generation/connections
```

Party record:

```lua
{
    id = string,
    revision = number,
    leaderUserId = number,
    memberUserIds = { number },
    nextLootCursor = number,
}
```

### Public API

Нужны семантические методы, а не доступ к mutable tables:

- `start()/stop()`;
- `invite(inviter, target)`;
- `acceptInvite(player, inviteId)`;
- `declineInvite(player, inviteId)`;
- `leave(player)`;
- `getSnapshot(player)`;
- `getPartyId(player)`;
- `getOrderedMembers(player)` / аналогичный read-only API;
- `resolveEligibleMembers(killer, deathPosition)`;
- `selectLootRecipient(killer, eligiblePlayers)`.

Конкретные names допустимо уточнить, если contract остаётся тем же.

### Lifecycle

Подписаться на:

- `Players.PlayerRemoving`;
- при необходимости `PlayerDataService.CharacterReady` только для snapshot sync, не для создания membership.

На disconnect:

- remove pending invites;
- remove membership;
- leader handoff;
- auto-disband;
- никакой persistence mutation.

`stop()` обязан disconnect connections и clear runtime state.

### Security invariants

Внутренние методы не должны доверять partyId от клиента.

### Commit

`feat(party): add authoritative party lifecycle service`

---

## Task 3 — Party networking

### Создать

- `src/server/features/party/PartyNetworkService.luau`
- `tests/PartyRemoteValidationSpec.luau`

При необходимости общий Remote-name/config module размещать в `src/shared/party`.

### Remotes

Использовать небольшой набор:

- `PartyActionRequest`;
- `PartySnapshot`;
- `PartyInviteReceived`;
- `PartyResult`.

RemoteEvent preferred; не превращать party state в client-owned request/response object.

### Action payload

Допустимые actions:

```lua
{ action = "Invite", targetUserId = number }
{ action = "Accept", inviteId = string }
{ action = "Decline", inviteId = string }
{ action = "Leave" }
```

Всё остальное reject.

### Rate limiting

Нужен per-player request throttle плюс pair cooldown на invite.

Rate limit должен удаляться при PlayerRemoving.

### Tests

Hostile cases:

- nil/string/non-table payload;
- unknown action;
- NaN/fractional/negative targetUserId;
- self invite;
- target not in server;
- target not CharacterReady;
- nonleader invite;
- full party;
- accept чужого invite;
- expired id;
- duplicate accept;
- spam;
- leave solo.

### Commit

`feat(party): add validated party networking`

---

## Task 4 — Canonical kill context

### Изменить

- `src/server/services/MobService.luau`
- создать `src/server/features/party/KillCreditService.luau`
- добавить tests.

### MobService

На death вычислить `deathPosition` до уничтожения/respawn lifecycle и расширить event:

```lua
MobDied:Fire(lastAttackerOrNil, definition.id, entityId, deathPosition)
```

Не менять существующий last-attacker ownership.

### KillCreditService

Подписаться на `MobService.MobDied`.

Формировать resolved context один раз:

- killer;
- mobId;
- entityId;
- deathPosition;
- eligiblePlayers;
- lootRecipient.

Если killer solo, context должен сохранить существующее поведение.

Выдать server-side `KillResolved` event.

### Critical invariant

`LootService` и `QuestService` далее используют один и тот же resolved context. Не оставлять два независимых eligibility calculation path.

### Tests

- solo;
- party nearby;
- far member;
- dead member;
- not-ready member;
- disconnected member;
- same party only;
- loot recipient round-robin.

### Commit

`feat(party): resolve shared kill eligibility once`

---

## Task 5 — XP, loot и quest integration

### Изменить

- `src/server/services/LootService.luau`
- `src/server/services/QuestService.luau`
- при необходимости узкие shared reward helpers.

### LootService

Переключить с прямого `MobService.MobDied` на `KillCreditService.KillResolved`.

Сохранить `rewardedEntityIds` ledger.

Для каждого resolved kill:

1. если нет eligible recipients — rewards не выдавать;
2. поделить `definition.rewardXP` через pure `PartyRules`;
3. каждому вызвать существующий `ProgressionService.awardMobXP`;
4. loot table roll выполнить ровно один раз;
5. весь Luna/item result выдать `lootRecipient`;
6. не reroll/reassign item при InventoryFull.

Solo output должен быть функционально эквивалентен baseline.

### QuestService

KillMob credit выдать каждому `eligiblePlayers`.

Остальные quest objectives не менять.

### Regression tests

Обязательны:

- solo XP точно не меняется;
- solo loot roll count = 1;
- party loot roll count = 1;
- party XP sum по base shares = rewardXP;
- shared quest credit;
- far/dead no quest credit;
- same entity не reward-ится повторно.

### Stabilization gate A

После Task 5:

- полный automated test suite;
- canonical Rojo builds;
- independent review diff Task 1–5;
- исправить замечания до перехода к UI.

### Commit

`feat(party): distribute shared combat rewards and quest credit`

---

## Task 6 — Server runtime integration

### Изменить

- `src/server/bootstrap/adapters/ExistingServerComponents.luau`;
- `src/server/bootstrap/manifests/WorldServerManifest.luau`;
- DevCombined gameplay composition;
- при необходимости Dungeon manifest только на уровне безопасного contract placeholder.

### Требование порядка

Party runtime и KillCredit должны стартовать до Loot/Quest consumers.

Не создавать альтернативный party implementation для DevCombined.

### Tests

Добавить/расширить manifest contract tests:

- World включает party;
- DevCombined включает тот же feature;
- start/stop order допустим;
- no production fallback;
- service stop idempotent.

### Commit

`refactor(runtime): wire party services into gameplay manifests`

---

## Task 7 — PartyController и PartyUi

### Создать

- `src/client/features/party/PartyController.luau`
- `src/client/features/party/PartyUi.luau`

### Изменить

- `src/client/bootstrap/adapters/ExistingClientComponents.luau`;
- `src/client/controllers/ResponsiveUiController.luau` только если нужно;
- существующий action block/HUD layout только минимально.

### UI behavior

Entry point: кнопка **ГРУППА**.

Solo panel:

- список CharacterReady players server;
- nickname + LVL;
- Invite.

Party panel:

- leader marker;
- member list;
- Leave;
- Invite section доступна leader, пока <4.

Invite compact dialog:

- inviter nickname;
- Принять;
- Отклонить.

Party HUD:

- под own status;
- до 3 rows;
- nickname;
- LVL;
- HP;
- DEAD;
- leader marker.

### Live HP

Membership приходит server snapshot.

HP UI наблюдает replicated Character/Humanoid соответствующего Player; membership не вычисляется локально.

### Responsive constraints

Проверить:

- desktop 1920×1080;
- iPhone 16 Pro landscape baseline 874×402;
- ещё один phone-landscape preset;
- tablet landscape.

Не перекрывать:

- target frame;
- ATTACK;
- skill bar;
- Core UI;
- existing mobile overlays.

### Cleanup

`stop()` уничтожает UI и disconnect все connections.

### Commit

`feat(party): add responsive party UI and client controller`

---

## Task 8 — Multiplayer hardening и diagnostics

### Automated

Добавить tests/fixtures для:

- leader disconnect;
- member disconnect;
- death → respawn;
- repeated start/stop;
- invite removed when source/target leaves;
- party full race;
- two simultaneous accepts of final slot — максимум один success;
- duplicate reward/event race;
- malicious request cannot alter another party.

Где race трудно детерминированно воспроизвести в Luau unit tests, вынести state transition в pure atomic rule/service method и тестировать его напрямую.

### Studio diagnostics

Разрешается добавить минимальную Studio-only диагностику, если она сокращает owner acceptance:

- partyId;
- leader;
- member UserIds;
- current loot cursor.

Она не должна попадать в обычный player UI.

### Full automated gate

Запустить:

- все Luau tests;
- Python/static contract checks;
- canonical `rojo build` для Lobby, Moonfall, Dungeon, DevCombined;
- formatter/linter/type checks, существующие в repo.

Исправить все regressions.

### Commit

`test(party): harden multiplayer lifecycle and abuse cases`

---

## Task 9 — Manual acceptance handoff

Codex/agent не объявляет этот task completed самостоятельно.

Подготовить owner checklist:

### 1 server + 2 clients

1. A и B входят в Moonfall;
2. A приглашает B;
3. B принимает;
4. оба видят HUD;
5. два последовательных mob kills:
   - shared quest credit;
   - XP split;
   - loot owner rotates;
6. B отходит >120 studs;
7. следующий kill reward только eligible;
8. B возвращается и умирает;
9. kill рядом с dead B не reward-ит B;
10. B respawn, party сохранена;
11. B leave;
12. party disband.

### Дополнительно

- leader disconnect;
- party 4 + попытка 5-го;
- mobile phone-landscape visual sanity;
- desktop sanity.

Результат owner test записать в Issue #76/PR.

---

## Task 10 — Release preparation after owner PASS

Выполнять только после принятого manual M5.

- устранить blockers;
- финальный review;
- обновить `CHANGELOG.md`;
- обновить `README.md` status;
- при решении сформировать следующий prerelease checkpoint (ожидаемо `0.1.0-alpha.4`);
- release/version bump отдельным commit;
- закрыть Issue #76 только после доказательств;
- M6 начинать отдельной веткой/PR.

## PR Definition of Ready

Draft PR можно открывать после Task 3. В body держать ledger:

- текущий HEAD;
- completed tasks;
- automated checks;
- manual checks = pending;
- known risks;
- next task.

## Completion rule

Нельзя заявлять M5 завершённым только потому, что UI показывает party.

Нужны одновременно:

- authoritative membership;
- reward semantics;
- lifecycle;
- abuse validation;
- tests/builds;
- owner multiplayer acceptance.
