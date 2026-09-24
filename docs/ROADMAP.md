# Luna World — Roadmap to v0.1

Roadmap фиксирует текущий продуктовый baseline и оставшиеся gates до первого Vertical Slice. Это не календарный план.

## Текущий checkpoint — 0.1.0-alpha.3 — 2026-09-24

`0.1.0-alpha.3` — принятый playable checkpoint после физического multi-place deployment и мобильной проверки.

Уже приняты и находятся в `main`:

- server-authoritative combat и три архетипа;
- progression, loot, inventory/equipment и persistence `DataVersion = 3`;
- Character Lobby с несколькими персонажами аккаунта;
- Q1–Q7, journal, tracker, map, waypoint и paid travel;
- open-world progression LV1–14 до Ancient Approach;
- текущий Mob Content Pass и open-world elites;
- merchant buy/sell, No-Grade blacksmith crafting и return scroll;
- mobile landscape gameplay HUD/UI baseline — принят как достаточный для v0.1;
- production multi-place architecture `Lobby → Moonfall World → отдельные Dungeon/Region Places` с Studio-only `DevCombined`;
- authored-Moonfall production boundary и one-shot world bake tooling;
- опубликованный Lobby → Moonfall transfer проверен на реальном мобильном Roblox-клиенте.

Текущая multi-place архитектура считается принятой. Дальнейшая разработка v0.1 идёт поверх этого baseline без возврата к combined-production topology.

Alpha checkpoint не означает завершение `0.1.0`. Финальный release gate отслеживается в GitHub Issue #63.

## Завершённые milestones

### M0 — Playground

Доказан базовый multiplayer PvE loop: target, authoritative damage, mob death/respawn и XP.

### M1 — Combat & Skills

Реализованы skills, cooldowns, class resources, crit, attack speed, death/respawn и PvE AUTO поверх server-authoritative combat.

### M2 — Progression, Loot & Persistence

Реализованы levels, progression curve, loot, inventory/equipment, stat recalculation, persistent account/character schema и migrations до `DataVersion = 3`.

### M3 — Luna Village, Quests & Economy

Реализованы Luna Village, Character Lobby, Q1–Q7, NPC flow, merchant, blacksmith, No-Grade crafting, consumables, return scroll и onboarding-контур.

### M4 — Moonfall open world

Реализован основной маршрут:

`Luna Meadows → Moonfall Road → Goblin Camp / Spider Hollow → Dark Woodland → Old Cemetery / Fallen Shrine → Ancient Approach`

Открытый мир покрывает LV1–14. LV15 зарезервирован под Ruins of Selene.

### Architecture stabilization — Gates A–F3

Принята production-oriented архитектура:

- role-based runtime: `Lobby`, `World`, `Dungeon`, Studio-only `DevCombined`;
- client application shell `Boot → Lobby → Transitioning → Gameplay/Error`;
- server-authoritative transfer intent + profile lease handoff;
- отдельные Rojo projects для Lobby, Moonfall, Dungeon и DevCombined;
- runtime worldgen исключён из production Moonfall;
- client feature ownership вынесен в `src/client/features`;
- combat orchestration вынесен в `src/server/features/combat`;
- физический Lobby → Moonfall deployment и published-client teleport acceptance пройдены на мобильном устройстве.

Архитектурный baseline закрыт и считается целевым для дальнейшей разработки.

## M5 — Party & Multiplayer Hardening

Обязательный следующий продуктовый блок:

- party invite / accept / leave;
- до 4 игроков;
- shared kill credit;
- простые XP/drop eligibility rules;
- минимальный party UI;
- join/leave/respawn lifecycle;
- multiplayer exploit/cleanup tests.

### Stabilization gate M5

- smoke с несколькими clients;
- lifecycle/connection cleanup;
- reward eligibility/duplication review;
- server-authority review.

## M6 — Ruins of Selene

Добавить отдельный Dungeon Place и законченный 1–4 player encounter:

`Entrance → mobs → encounter/miniboss → mobs → Selene's Fallen Guardian`

Boss LV15 минимум:

- basic attack;
- telegraphed AoE;
- enrage/усиление на низком HP.

Также нужны completion reward, failure/re-entry paths и защита от reward duplication.

### Stabilization gate M6

- dungeon isolation;
- party lifecycle;
- transfer/rejoin;
- reward idempotency;
- published-client runtime acceptance.

## M7 — 0.1.0 Release Candidate

Собрать полный путь нового игрока:

`Luna Village → Moonfall Valley → Ruins of Selene → final boss`

Перед RC:

- UX cleanup только по реальным blockers/usability-проблемам;
- release-sanity balance pass, необходимый для проходимости vertical slice;
- минимальный art consistency pass без полной замены placeholder-графики;
- sound/music first pass;
- persistence migration verification;
- multiplayer regression;
- known issues;
- внешние playtests без объяснений разработчика.

Текущая неудовлетворительная визуальная детализация мира и системная балансировка мобов сознательно не раздувают scope v0.1: они вынесены в отдельный post-v0.1 блок.

## 0.1.0 release gate

`0.1.0` выпускается только когда:

- Definition of Done из `GAME_DESIGN_V0.1.md` выполнен;
- Party и Ruins of Selene работают;
- полный walkthrough проходит минимум на `1 server + 2 clients`;
- повторный вход восстанавливает progression;
- published Lobby → Moonfall → Dungeon переходы приняты;
- критических data-loss / reward-duplication / remote-validation bugs нет;
- performance sanity выполнен;
- документация соответствует реализации;
- `CHANGELOG.md` и `VERSION` подготовлены;
- создан tag `v0.1.0`.

## Отдельные follow-up задачи alpha

- широкое external mobile playtest нескольких тестировщиков — собрать в M7, не блокируя M5/M6;
- карта мира на mobile визуально неудовлетворительна, но текущий вариант принят для v0.1; полноценная переработка UI карты — post-v0.1 UX/art backlog;
- точечные bugs и usability regressions, найденные при прохождении M5/M6.

## После v0.1 — v0.2 baseline

До результатов полного v0.1 playtest дальнейшие системы не детализируются, но два направления уже зафиксированы как обязательные для v0.2:

### Visual World Pass — Issue #74

Навести визуальную цельность мира и уйти от текущих blockout/placeholder форм:

- персонажи игроков;
- мобы;
- NPC;
- здания и окружение;
- пропсы и landmarks;
- единый art direction Luna Village / Moonfall;
- при необходимости Blender → Roblox asset pipeline;
- без разрушения gameplay hitboxes, читаемости боя и mobile performance.

### Systematic Mob Balance Pass — Issue #75

Провести системную балансировку мобов LV1–15 по данным реального playtest:

- HP / damage / defense / attack speed;
- aggro / social behavior / chase;
- XP и pace прокачки;
- drops и экономика фарма;
- обычные / elite / miniboss / dungeon mobs;
- solo vs party difficulty;
- boss tuning;
- устранение резких скачков сложности между соседними зонами.

После этих двух блоков можно решать, что именно войдёт в дальнейшие v0.2.x / v0.3 направления: расширение мира, class advancement, PvP, более глубокая social/party игра, расширенный crafting/economy и monetization.
