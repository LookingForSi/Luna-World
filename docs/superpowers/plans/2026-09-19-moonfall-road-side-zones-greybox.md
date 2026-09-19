# Luna World — план реализации World Block 2: Moonfall Road + Side Zones

Статус: **approved for implementation — 2026-09-19**.

## 1. Цель

Реализовать второй воспроизводимый greybox-блок поверх принятой структуры World Block 1:

`exit_moonfall_road → Moonfall Road → crossroads → Goblin Camp / Spider Hollow → Dark Woodland entrance`.

Работа ведётся отдельной stacked-веткой от `feature/luna-village-meadows-greybox`, без смешивания с gameplay Milestone 2.

## 2. Branch / PR

- base: `feature/luna-village-meadows-greybox`;
- feature: `feature/moonfall-road-side-zones-greybox`;
- PR остаётся Draft до owner Studio acceptance;
- merge в `main` не выполнять отдельно от решения по World Block 1.

## 3. Ключевые контракты

- один managed root: `Workspace/LunaWorldGreybox`;
- `WorldLayout` остаётся canonical source координат;
- существующий `Route` остаётся маршрутом Village/Meadows ради совместимости;
- второй блок получает отдельные data-driven routes;
- stable IDs из spec обязательны;
- Moonfall Road остаётся проходным без обязательного захода в side pockets;
- Goblin Camp выше main road;
- Spider Hollow ниже main road и имеет отдельный return trail;
- Dark Woodland реализуется только как визуальный threshold + handoff marker;
- gameplay authority, quests, loot и Mob AI в этот world-pass не входят.

## 4. Задачи

### Task 1 — расширить WorldLayout

Добавить:

- zones: `zone_moonfall_road`, `zone_goblin_camp`, `zone_spider_hollow`;
- POI/entry IDs из approved spec;
- goblin/spider spawn markers;
- `MoonfallRoadRoute`;
- `GoblinCampRoute`;
- `SpiderHollowRoute`;
- `SpiderReturnRoute`.

Существующий `Route` не расширять, чтобы Luna Meadows не строила собственную геометрию поверх второго блока.

### Task 2 — усилить validation/tests

Проверять:

- required stable IDs;
- уникальность IDs между zones / POIs / spawn markers;
- корректные zone references spawn markers;
- route minimum lengths и Vector3 entries;
- Moonfall route начинается в `exit_moonfall_road`;
- Moonfall route заканчивается в `entry_dark_woodland`;
- Goblin Camp выше crossroads;
- Spider Hollow ниже crossroads;
- Dark Woodland глубже по +Z;
- старые World Block 1 regressions сохраняются.

### Task 3 — адаптировать Meadows

- фильтровать spawn markers только по `zone_luna_meadows`;
- сохранить ожидание ровно трёх meadows spawn areas;
- spider pocket выбирать только из meadows;
- `exit_moonfall_road` указывает на реальный `zone_moonfall_road`.

### Task 4 — Moonfall Road builder

Создать:

- широкий terrain/ground corridor;
- main road по `MoonfallRoadRoute`;
- broken wagon;
- crossroads clearing;
- old waystone + low stone remnants;
- road-side goblin scout marker;
- Dark Woodland threshold с boundary stones / dark tree silhouettes;
- `entry_dark_woodland` marker без teleport.

### Task 5 — Goblin Camp builder

Создать:

- elevated terrace;
- branch road;
- controlled entrance / palisade fragments;
- 2–3 hut volumes;
- central fire/encounter clearing;
- lookout;
- crate/barrel blockout;
- spawn markers outer / warrior / future elite.

### Task 6 — Spider Hollow builder

Создать:

- descending branch;
- lower hollow floor;
- incomplete rock perimeter;
- large dark tree/root silhouettes;
- cave-mouth / rock arch landmark;
- brood pocket;
- separate return trail to main route;
- outer / mid / brood spawn markers.

### Task 7 — integrate managed builder

Подключить три focused builders в существующий `WorldGreyboxBuilder` без второго root и без destructive changes к чужим Workspace objects.

## 5. Automated verification

Перед owner acceptance выполнить, если toolchain доступен:

- JSON parse `world.project.json` / `world.test.project.json`;
- `rojo build world.project.json`;
- `rojo sourcemap world.project.json`;
- `rojo build world.test.project.json`;
- `rojo sourcemap world.test.project.json`;
- Luau compile/static checks, если compiler доступен;
- `git diff --check`.

Roblox Studio runtime/visual acceptance остаётся owner-only.

## 6. Owner Studio acceptance

Проверить:

1. бесшовный выход из Meadows;
2. main road читается без UI;
3. crossroads визуально очевиден;
4. Goblin Camp заметно выше дороги и читается слева;
5. Spider Hollow заметно ниже и читается справа;
6. side pockets не блокируют продолжение по main road;
7. hollow имеет отдельный возврат;
8. Dark Woodland threshold выглядит как следующий регион;
9. walkability/collisions приемлемы;
10. rebuild повторяем и не затрагивает чужие Workspace objects.

## 7. Definition of Done

World Block 2 готов к merge только после automated checks + owner Studio acceptance. Корректировка размеров/координат после playtest допустима; stable IDs сохраняются.
