# Luna World — Roadmap to v0.1

Roadmap описывает порядок доказательства основных рисков vertical slice. Это не обещание календарных сроков.

## Текущий checkpoint — dev0.1 / 0.1.0-dev.2 — 2026-09-20

Первая целостная playable-база собрана в `main`-кандидат: combat/skills, progression/persistence, Luna Village и открытая карта до Ancient Approach, полный Mob Content Pass и узкая No-Grade деревенская экономика работают как единый контур.

Это development checkpoint, а не закрытие полного v0.1 release gate. Quest chain, party, Ruins of Selene, финальный boss и последующие polish/multiplayer acceptance остаются впереди.

## Milestone 0 — Playground

Цель: доказать базовую multiplayer combat loop на серой тестовой арене.

Минимум:

- 1 player character;
- 1 Wolf;
- target selection;
- target frame;
- autoattack;
- authoritative damage;
- mob death;
- XP award;
- mob respawn;
- test с 1 server + 2 clients.

Результат: мы умеем корректно синхронизировать основной PvE interaction.

### Stabilization gate M0

- зафиксировать combat contract;
- убрать временные debug shortcuts;
- проверить Remote validation;
- покрыть damage/validation базовыми тестами.

## Milestone 1 — Combat & Skills — завершён 2026-09-18

Статус: принят владельцем после ручной Roblox Studio приёмки и stabilization gate. PvP сознательно не входит в этот milestone; CP подготовлен как отдельный будущий PvP-слой.

Реализовано:

- несколько типов mobs;
- aggro/chase/leash;
- resource/cooldowns;
- первые skills;
- crit / attack speed в минимальном объёме;
- death/respawn player;
- basic combat FX/animation hooks.

Результат: бой уже ощущается как RPG, а не как технический hit test.

### Stabilization gate M1 — пройден

Проверены module boundaries Combat/Mob/Progression, multiplayer regressions, lifecycle cleanup, RemoteEvent validation и owner runtime acceptance.

Отдельный обязательный balance sanity-pass трёх архетипов:
- сравнить время убийства одинаковых PvE-целей, дистанцию риска, мобильность, расход ресурса и полезность полного набора умений;
- особенно проверить Следопыта как потенциально доминирующий набор: Snare + Power Shot + Rapid Shot + ranged basic attack;
- убрать очевидный безусловный выбор одного класса, но не пытаться финализировать численный баланс до появления levels/equipment и более полного PvE-контента.

Следующий крупный продуктовый фокус после checkpoint: **закрытие оставшихся M3–M6 блоков полного v0.1**.

## Milestone 2 — Progression, Loot & Persistence — реализован в dev0.1

Добавить:

- levels 1–10;
- progression curve;
- loot tables;
- inventory;
- equipment;
- stat recalculation;
- persistent player schema;
- DataVersion + migrations;
- save/load tests.

Результат: появляется долгосрочный progression loop и смысл редкого drop.

### Stabilization gate M2

Базовый контур progression/inventory/equipment/persistence интегрирован. DataVersion остаётся отдельным контрактом; перед финальным v0.1 требуется повторная multiplayer/save-load приёмка.

## Milestone 3 — Luna Village & Quests — реализован, ожидает runtime-приёмку

Добавить:

- greybox / first art pass Luna Village;
- стартовые NPC;
- quest chain;
- merchant;
- blacksmith/equipment interaction;
- узкий No-Grade crafting catalog без профессий и recipe items;
- merchant buy/sell, материалы, consumables и return scroll;
- onboarding;
- respawn/safe zone flow.

Текущее состояние dev0.2: реализованы Q1–Q7, persistent quest progress, общий quest dialogue, tracker, карта, waypoint и NPC markers. Multiplayer/visual acceptance в Roblox Studio остаётся обязательным перед merge.

Результат milestone после завершения quests: проект впервые выглядит как маленькая игра, а не набор systems.

### Stabilization gate M3

Проверить onboarding без подсказок разработчика и убрать технические заглушки, мешающие playtest.

## Milestone 4 — Moonfall Valley — основной open-world контур реализован

Добавить полноценную первую open-world зону:

- несколько участков сложности;
- нужный набор mobs;
- landmarks;
- open-world elite/miniboss;
- progression от village к ruins;
- первый целостный art/environment pass.

Текущее состояние dev0.1: маршрут Luna Meadows → Moonfall Road → Goblin Camp / Spider Hollow → Dark Woodland → Cemetery / Shrine → Ancient Approach населён authoritative mobs уровней 1–10 и open-world elites.

Результат: игровой маршрут 1–10 существует в одном общем мире. Art/environment и balance passes продолжаются.

### Stabilization gate M4

Performance review AI/world, navigation, spawn lifecycle, mobile readability.

## Milestone 5 — Party & Multiplayer Hardening

Добавить / довести:

- party invite/accept/leave;
- shared kill credit;
- XP/drop eligibility rules;
- party UI;
- multiplayer exploit tests;
- server behavior при join/leave/respawn.

Результат: совместная игра является нормальным сценарием, а не случайно работающим дополнением.

### Stabilization gate M5

Stress/smoke testing с несколькими clients и cleanup review.

## Milestone 6 — Ruins of Selene

Добавить:

- dungeon entry/session;
- dungeon mobs;
- encounter/miniboss;
- Selene's Fallen Guardian;
- telegraphed AoE;
- enrage phase;
- completion reward;
- повторный вход / failure paths.

Результат: vertical slice имеет полноценную кульминацию.

### Stabilization gate M6

Проверить dungeon isolation, reward duplication protection и party lifecycle.

## Milestone 7 — v0.1 Alpha Candidate

Собрать полный путь нового игрока:

`Luna Village → Moonfall Valley → Ruins of Selene`

Работы:

- UX cleanup;
- balance pass;
- art consistency pass;
- sound/music first pass;
- mobile pass;
- persistence migration verification;
- multiplayer regression suite;
- known issues list;
- внешние playtests без объяснений разработчика.

## v0.1 release gate

Перед `v0.1.0`:

- Definition of Done из `GAME_DESIGN_V0.1.md` выполнен;
- milestone tests проходят;
- критических data-loss / reward-duplication / remote-validation bugs нет;
- `1 server + 2 clients` полный walkthrough проходит;
- повторный вход восстанавливает progress;
- документация соответствует реализации;
- `CHANGELOG.md` подготовлен;
- `VERSION` обновлён до `0.1.0`;
- создан tag `v0.1.0`.

## После v0.1

v0.2 не проектируется детально до результатов playtest v0.1.

Возможные направления (не commitments):

- расширение мира;
- class advancement;
- более глубокая party/social игра;
- экономика;
- PvP;
- профессии и расширенный crafting;
- monetization cosmetics/convenience.

Приоритеты определяются поведением реальных игроков, а не желанием заранее реализовать полный список MMO-функций.
