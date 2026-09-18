# Luna World — план реализации Milestone 2: Progression, Loot & Persistence

Дата: 2026-09-18  
Статус: **Approved — готов к реализации**  
Спецификация: `docs/superpowers/specs/2026-09-18-milestone-2-progression-loot-persistence-design.md`

## 1. Цель

Реализовать первый persistent RPG progression loop поверх принятого Milestone 1:

`бой → XP/loot → level-up → equipment → stronger stats → save → relog → restored state`.

Главный технический риск Milestone 2 — не UI и не числа баланса, а **целостность persistent state**. Поэтому persistence, item ownership и anti-duplication рассматриваются как high-risk boundaries и получают отдельные review gates.

## 2. Ветка и PR

После owner approval спецификации:

- создать `feature/milestone-2-progression-loot-persistence` от актуального `main`;
- открыть Draft PR;
- вести краткий task ledger в body PR;
- push после каждого принятого task/batch;
- merge только после owner runtime acceptance и stabilization gate.

Design-ветка не содержит gameplay implementation.

## 3. Правила выполнения

- server authority для XP, level, loot, item ownership, equipment, currency и saves;
- TDD для pure rules;
- persistence/schema/session-lock work получает отдельный independent review;
- один implementer может выполнять coherent batch 3–5 tasks;
- Roblox Studio manual gates можно объединять, если downstream не зависит от результата;
- никакого silent reset profile при load/migration error;
- не добавлять PvP, party loot, quests, merchant, crafting или ground-drop gameplay вне утверждённого scope.

## 4. Предлагаемая структура

Ориентировочно:

```text
src/
  shared/
    config/
      ProgressionConfig.luau
      InventoryConfig.luau
      PersistenceConfig.luau
    definitions/
      ItemDefinitions.luau
      LootTableDefinitions.luau
    progression/
      ProgressionRules.luau
      StatRules.luau
    inventory/
      InventoryRules.luau
      EquipmentRules.luau
    loot/
      LootRules.luau
    persistence/
      ProfileSchema.luau
      MigrationRules.luau
    types/
      ProgressionTypes.luau
      ItemTypes.luau
      PersistenceTypes.luau

  server/
    services/
      PlayerDataService.luau
      ProgressionService.luau
      StatsService.luau
      InventoryService.luau
      LootService.luau
    persistence/
      RobloxProfileStore.luau

  client/
    controllers/
      InventoryController.luau
    ui/
      InventoryUi.luau
      PlayerStatusHud.luau

tests/
  progression/...
  inventory/...
  loot/...
  persistence/...
```

Точные пути можно слегка адаптировать к текущему repository layout без изменения границ ответственности.

---

# Phase A — progression без persistence

## Task 1. Baseline gate после Milestone 1

Перед изменениями:

- checkout актуального `main`;
- запустить существующие Python/static checks;
- `rojo build default.project.json`;
- `rojo build test.project.json`;
- полный Studio TestRunner;
- сохранить baseline count;
- короткий solo smoke текущего combat loop.

Если есть новый regression в main — исправить/зарегистрировать до Milestone 2.

**Commit:** нет, если изменений нет.

## Task 2. ProgressionConfig + ProgressionRules

Добавить pure definitions/rules:

- level cap 10;
- XP curve;
- `requiredXP(level)`;
- `applyXP(level, xp, reward)`;
- несколько level-ups одним reward;
- cap behavior;
- reject negative/nonfinite input.

Тесты:

- level 1→2;
- exact boundary;
- multi-level reward;
- level 9→10;
- cap ignores overflow;
- invalid input.

**Commit:** `feat: add level progression rules`

## Task 3. Skill unlock rules

Добавить data-driven unlock levels:

- skill 1 at 2;
- skill 2 at 4;
- skill 3 at 6;
- basic attack always unlocked.

`CombatService` не должен принимать locked skill даже при forged `SkillRequest`.

Action bar показывает locked state.

Тесты:

- level boundaries;
- forged request rejected;
- unlock после level-up;
- Studio-only debug seam не доступен production client.

**Commit:** `feat: gate skills by player level`

## Task 4. Level growth + pure StatRules

Расширить canonical stat model:

- maxHealth;
- maxResource;
- regen;
- physical/magic attack;
- defense;
- crit;
- attack speed;
- movement speed.

Реализовать:

`base archetype + level growth + equipment modifiers`.

Пока equipment modifiers можно подавать пустыми.

Тесты по каждому archetype и level 1/5/10.

**Commit:** `feat: add level based stat growth`

### Gate A — progression review

Независимо проверить:

- XP boundary math;
- skill unlock authorization;
- отсутствие client authority;
- stat formulas/data separation;
- M1 combat regressions.

---

# Phase B — persistent schema и profile lifecycle

## Task 5. Profile schema v1

Добавить typed default schema:

- DataVersion = 1;
- Level;
- XP;
- Luna;
- ArchetypeId;
- Items;
- Inventory;
- Equipment.

Добавить validator/invariant checks:

- valid DataVersion;
- level 1–10;
- XP within sensible range;
- valid item records;
- inventory refs exist;
- equipment refs exist;
- один instance не одновременно inventory/equipment;
- quantity positive integer;
- known slots.

Не подключать DataStore.

**Commit:** `feat: define persistent player profile v1`

## Task 6. Migration framework

Добавить:

- sequential migration registry;
- current-version validation;
- synthetic v0 fixture → v1 test path;
- future version rejection;
- migration failure returns error, not default profile.

Даже если production v0 не существовал, framework должен быть проверяемым до появления v2.

**Commit:** `feat: add profile migration framework`

## Task 7. ProfileStore abstraction

Ввести narrow server-only adapter contract:

- load/claim;
- save/renew;
- release.

Unit/integration tests используют in-memory fake.

Gameplay services не импортируют `DataStoreService` напрямую.

**Commit:** `refactor: isolate profile persistence adapter`

## Task 8. RobloxProfileStore + session lease

Реализовать production adapter на `DataStoreService`:

- `UpdateAsync` claim;
- session token;
- lease timeout;
- bounded retry/backoff;
- save renew;
- release;
- Studio/dev namespace isolation.

Тесты pure lease decisions через injected clock/store fake.

Обязательный independent review: persistence/session ownership.

**Commit:** `feat: add leased roblox profile store`

## Task 9. PlayerDataService

Lifecycle:

- PlayerAdded → Loading → Ready;
- load/migrate/validate;
- autosave;
- PlayerRemoving save/release;
- BindToClose flush/release;
- Error path не создаёт пустой save.

API server-only:

- `isReady(player)`;
- `getProfile(player)` read-only/copy semantics по необходимости;
- scoped mutation callback или узкие update helpers;
- `ProfileReady` / `ProfileChanged` signals.

Не добавлять XP/item business logic внутрь сервиса.

**Commit:** `feat: add authoritative player data lifecycle`

### Gate B — persistence architecture review

Проверить отдельно:

- no silent reset;
- lease atomicity;
- retry idempotency;
- shutdown path;
- player leave race;
- migration ownership;
- никакой mutable profile reference клиенту;
- никакой gameplay mutation в persistence retry loop.

Manual Studio/DataStore acceptance пока может быть DEFERRED, если downstream использует in-memory test adapter.

---

# Phase C — progression поверх profile

## Task 10. Перевести ProgressionService с SessionXP на profile

Убрать временную модель `SessionXP` как source of truth.

ProgressionService:

- читает Level/XP из Ready profile;
- awardXP атомарно применяет pure rules;
- публикует Level/XP attributes для HUD;
- отправляет presentation event XP/LevelUp;
- multiple level-ups работают;
- death/respawn не сбрасывает progression.

До готовности profile игрок не получает gameplay rewards.

**Commit:** `feat: persist player level and xp`

## Task 11. StatsService и интеграция CombatService

Создать canonical derived stats service.

Источники:

- archetype;
- level;
- equipment modifiers.

CombatService:

- перестаёт самостоятельно считать конечный snapshot только из `CombatConfig.ArchetypeStats`;
- получает baseline из StatsService;
- временные buffs/debuffs остаются combat-owned;
- stat refresh не сбрасывает cooldown/action lifecycle;
- HP/resource maxima обновляются без бесплатного heal.

Регрессии всех M1 skills обязательны.

**Commit:** `refactor: centralize derived player combat stats`

### Gate C — combat/progression integration

Full TestRunner + targeted manual:

- level-up;
- unlocked skill;
- damage before/after level;
- no cooldown reset;
- no heal exploit.

---

# Phase D — item model и inventory

## Task 12. ItemTypes + ItemDefinitions

Добавить около 25 definitions из spec:

- 9 weapons;
- 10 shared armor/accessories;
- 5 material/consumable;
- 1 reserved epic.

Каждый definition:

- stable itemId;
- displayName;
- category;
- rarity;
- stackability/maxStack;
- equipment slot если применимо;
- requiredLevel;
- archetype restrictions;
- stat modifiers;
- presentation metadata без per-player state.

Тест uniqueness всех IDs и schema completeness.

**Commit:** `feat: add milestone two item definitions`

## Task 13. InventoryRules

Pure rules:

- create instance record;
- add stackable;
- add nonstackable;
- capacity = 40;
- stack max 99;
- remove quantity;
- discard;
- ownership/location invariants.

Instance ID generator инъецируется.

Тесты full inventory, merge stack, split/new stack, duplicate IDs.

**Commit:** `feat: add inventory ownership rules`

## Task 14. EquipmentRules

Pure validation:

- instance owned;
- currently in inventory;
- category equippable;
- slot compatible;
- required level;
- archetype allowed;
- unequip requires free bag slot;
- one item per slot.

Equip/unequip mutation должна быть transactional относительно canonical profile state.

**Commit:** `feat: add equipment validation rules`

## Task 15. InventoryService

Server-only facade над profile:

- add/grant item;
- remove;
- equip;
- unequip;
- discard;
- consume entry point;
- sanitized snapshot for client;
- changed signal.

Никаких клиентских setters.

**Commit:** `feat: add authoritative inventory service`

## Task 16. Equipment → StatsService

После accepted equip/unequip:

- пересчитать derived stats ровно один раз;
- CombatService получает новый baseline;
- preserve HP/resource percentage;
- no duplicate modifier application after respawn/relog.

Тесты:

- duplicate equip replay;
- relog snapshot;
- wrong slot;
- full bag unequip;
- combat damage actually changes.

**Commit:** `feat: apply equipment modifiers to combat stats`

### Gate D — item integrity review

Independent review:

- referential integrity;
- instance IDs;
- transaction boundaries;
- equip duplication;
- profile mutation safety.

---

# Phase E — loot и currency

## Task 17. LootTableDefinitions + LootRules

Добавить `lootTableId` в mob definitions.

Pure loot roll:

- Luna range/chance;
- independent item entries;
- quantity;
- injected RNG.

Начальные tables для young wolf / grey wolf / spider.

Не превращать rarity в roll formula.

**Commit:** `feat: add server loot tables and roll rules`

## Task 18. LootService

Подписать на authoritative `MobDied`.

Для каждого entity lifecycle:

- XP один раз;
- loot roll один раз;
- Luna grant;
- item grant через InventoryService;
- full inventory result logged;
- anti-duplicate ledger cleanup after lifecycle.

До Milestone 5 eligibility = last valid attacker.

Перенести текущую awardXP wiring из `main.server.luau` в явный reward flow без god-object bootstrap logic.

**Commit:** `feat: grant loot and currency on mob death`

## Task 19. Consumables

Реализовать:

- Minor Healing Draught;
- Minor Resource Draught;
- 5 s shared consumable cooldown;
- alive check;
- server-owned effect;
- stack decrement только после acceptance;
- no overheal/over-resource;
- no use on other player.

Remote replay не списывает/применяет дважды.

**Commit:** `feat: add basic consumable item use`

### Gate E — reward duplication review

Проверить:

- one death/one roll;
- duplicate event/request;
- inventory full;
- disconnect during reward;
- save retry не повторяет reward.

---

# Phase F — UI и network contracts

## Task 20. Inventory remotes

Создать минимальные validated remotes:

- InventoryActionRequest;
- InventorySnapshot;
- InventoryActionResult.

Actions только whitelist:

- Equip;
- Unequip;
- Consume;
- Discard.

Добавить per-player request rate limit.

Malformed/unknown/foreign instance IDs ничего не меняют.

**Commit:** `feat: expose validated inventory actions`

## Task 21. Inventory/equipment UI

Desktop-first функциональный UI:

- `I` toggles;
- inventory list/grid;
- equipment slots;
- item details;
- Equip/Unequip/Use/Discard;
- Luna;
- used/40.

Gamepad/mobile semantic actions подключить через существующий input abstraction.

Без обязательного drag-and-drop.

**Commit:** `feat: add inventory and equipment interface`

## Task 22. Real level/XP HUD

Заменить временный `SessionXpHudReference`.

Status HUD:

- CP;
- HP;
- STM/FCS/MP;
- `LVL N · XP current / required`;
- level 10 → `MAX`.

Combat log:

- XP gained;
- level-up;
- Luna;
- loot;
- inventory full.

**Commit:** `feat: show persistent progression rewards`

---

# Phase G — persistence runtime proof

## Task 23. Save/load round-trip integration

Проверить через fake store автоматически:

- new profile;
- mutate XP/inventory/equipment/Luna;
- save;
- release;
- load;
- exact canonical restore;
- derived stats restore.

Добавить corruption fixtures.

**Commit:** `test: cover milestone two profile round trip`

## Task 24. Real Roblox DataStore manual checkpoint

Требует owner/Studio runtime.

Проверить в isolated dev store:

1. join;
2. получить XP/loot;
3. equip item;
4. записать level/XP/Luna/item/equipment;
5. leave;
6. join снова;
7. состояние восстановлено;
8. Studio restart не создаёт duplicate item;
9. simulated load failure не создаёт пустой profile.

Если Studio API access требует настройки account/place, это фиксируется как owner action, а не обходится фейковой persistence.

**Статус до выполнения:** `DEFERRED — pending owner runtime acceptance`.

---

# Phase H — security, regression, acceptance

## Task 25. Malicious inventory/persistence remote audit

Проверить:

- wrong types;
- extra args;
- oversized IDs;
- unknown instance;
- foreign instance;
- equip wrong archetype;
- equip above level;
- consume while dead;
- spam;
- replay;
- discard equipped item;
- unequip with full bag.

Ни один request не может задать XP/Level/Luna/Quantity напрямую.

**Commit:** `test: harden milestone two progression remotes`

## Task 26. Full automated regression

Запустить:

- all Luau TestRunner specs;
- Python/static contracts;
- Rojo builds;
- sourcemap checks;
- existing M0/M1 regressions;
- profile migration/round-trip;
- duplicate reward suite.

Зафиксировать count в PR.

**Commit при fix:** `fix: resolve milestone two automated regressions`

## Task 27. Owner manual acceptance

### Solo

- XP and level-up;
- unlock 2/4/6;
- loot/Luna;
- inventory;
- equip/unequip;
- stats affect combat;
- consumables;
- death/respawn retains progression;
- relog persists.

### 1 server + 2 clients

- separate profiles;
- no cross-player inventory;
- simultaneous kill no double reward;
- disconnect/rejoin;
- equipment replication/presentation;
- malicious requests;
- no recurring Output errors.

### Device

- desktop;
- gamepad;
- mobile emulator.

## Task 28. Final stabilization M2

После owner acceptance:

- remove temporary `SessionXP` compatibility;
- remove dead tuning hooks;
- audit item IDs;
- audit profile invariants;
- audit session leases;
- audit DataStore retry and BindToClose;
- review module boundaries;
- review remote validation;
- update architecture/testing/changelog/roadmap;
- record conscious debt.

**Commit:** `refactor: complete milestone two stabilization gate`

## 5. Review strategy

Отдельный independent review обязателен после:

- Task 8 — RobloxProfileStore/session lease;
- Tasks 15–16 — item ownership/equipment mutation;
- Task 18 — loot/reward anti-duplication;
- Task 28 — final stabilization.

Остальные соседние low/medium-risk tasks можно review пакетами.

## 6. Owner checkpoints

Чтобы не тратить время владельца по мелочам, предполагаются только три обязательных ручных checkpoint:

1. **после Gate C** — коротко проверить level/skills/stats;
2. **Task 24** — реальный save/load DataStore;
3. **Task 27** — итоговая acceptance.

UI/числовые tuning-поправки между checkpoint можно делать по скриншотам без отдельного approval на каждый commit.

## 7. Definition of Done M2

Milestone 2 готов только если:

- level 1–10 работает;
- skill unlocks server-authoritative;
- loot/currency server-authoritative;
- inventory/equipment ownership защищён;
- equipment реально влияет на combat;
- DataVersion = 1;
- save/load round-trip подтверждён;
- session lease защищает от двух writable sessions;
- load error не создаёт пустой profile;
- duplicate reward tests проходят;
- full test suite green;
- 1 server + 2 clients green;
- owner manual acceptance green;
- stabilization gate завершён.

## 8. Что намеренно переносится

На последующие milestones:

- physical ground loot presentation — кандидат на M4;
- merchant/blacksmith spending — M3;
- quest rewards — M3;
- shared party XP/loot — M5;
- boss Epic reward — M6;
- PvP/CP spending — после v0.1 или отдельное решение;
- random affixes/enchant/crafting — не v0.1.
