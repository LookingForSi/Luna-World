# Worldgen v0.1

Этот каталог содержит authoring-generator production-oriented рельефа Luna World v0.1.

Generator **не запускается в Roblox runtime**. Он воспроизводимо строит heightmap, water reference и debug maps, после чего heightmap импортируется в Roblox Terrain Editor.

## Source of truth

`world_v01.json` — authoring source для:

- world bounds и X/Z scale;
- POI и spawn areas;
- route graph;
- river;
- macro landforms;
- terrain pads;
- future terrain reservations.

Gameplay stable IDs синхронизируются с `src/shared/world/WorldLayout.luau`.

Текущий horizontal baseline: **2×** относительно первого Part-greybox.

## Установка

Из корня репозитория:

```powershell
python -m pip install -r tools/worldgen/requirements.txt
```

## Генерация

```powershell
python tools/worldgen/generate_world.py
python tests/check_worldgen_contract.py
```

Текущий artifact revision:

```text
terrain-v05
```

По умолчанию outputs создаются здесь:

```text
artifacts/worldgen/v01/terrain-v05/
```

Основной файл для Roblox:

- `world_v01_heightmap.png` — 16-bit grayscale heightmap.

Дополнительные outputs:

- `world_v01_water_mask.png` — reference mask русла;
- `world_v01_topdown.png` — сводная top-down карта;
- `world_v01_routes_overlay.png` — маршруты;
- `world_v01_poi_spawn_overlay.png` — POI, spawn areas и future reservations;
- `world_v01_zones_overlay.png` — zone volumes;
- `world_v01_manifest.json` — параметры генерации и slope stats.

Generated PNG не являются source-of-truth и не коммитятся. Каждый значимый terrain-pass получает отдельный `artifactRevision`.

## Roblox Terrain import

Authoring bounds:

- X: `-1300 .. 1300`;
- Z: `-650 .. 4150`;
- размер: **2600 × 4800 studs**;
- height encoding: **0 .. 192 studs**;
- heightmap resolution: **650 × 1200**.

Terrain Editor import region:

```text
Center:
X = 0
Y = 96
Z = 1750

Size:
X = 2600
Y = 192
Z = 4800
```

Если Studio округляет region под voxel-grid, допустимо ближайшее кратное 4 studs. После импорта всё равно нужен runtime traversal review.

## Terrain v0.5 — композиция

Целевая progression-композиция с юга на север:

```text
Luna Village
  ↓
Luna Meadows / river
  ↓
Moonfall Road / crossroads
 ↙                     ↘
Goblin Camp       Spider Hollow
          ↓
     Dark Woodland
 ↙                     ↘
Old Cemetery      Fallen Shrine
          ↓
    Ancient Approach
          ↓
 Ruins of Selene horizon
```

Terrain-v04 исправляет северный блок после owner review:

- сокращена крупная пустая равнина после реки;
- Moonfall crossroads и encounter-зоны подтянуты южнее;
- Goblin Camp и Spider Hollow поменяны сторонами относительно terrain-v03, чтобы imported Studio-view совпадал с approved concept;
- Old Cemetery и Fallen Shrine тоже подтянуты южнее и сохранены на concept-side;
- Ancient Approach теперь отдельная **крупная высокая центральная зона**, а не часть северней границы;
- Selene massif остаётся distant horizon/containment.

## Правило локального экстремума

Zone-defining terrain обязан иметь главный локальный экстремум в intended gameplay pocket.

Поддерживаются режимы:

- `raise` — только поднимать к target, никогда не вырезать яму в уже высокой земле;
- `lower` — только опускать;
- `set` — задавать абсолютную высоту; используется только там, где это действительно нужно.

Текущий contract:

- Goblin Camp — centered raised shelf;
- Spider Hollow — centered basin с более высоким rim;
- Old Cemetery — centered raised future terrace;
- Fallen Shrine — centered raised future promontory;
- Ancient Approach — centered broad high future approach.

Automated contract генерирует height field и численно проверяет эти отношения.

## Что ещё не final

Это production blockout macro-terrain, а не art pass.

После принятия geography обязательны:

- Terrain Smooth/Sculpt локальных стыков;
- реальный Terrain Water;
- bridge approaches;
- forest/cliff containment;
- grounding зданий/props;
- modular Blender kit;
- no-jump runtime traversal;
- desktop/gamepad/mobile acceptance.

Не начинать final foliage/material polish до принятия macro terrain и traversal.


Terrain-v05 — owner traversal correction:

- сдвигает Goblin Camp / Spider Hollow / Old Cemetery / Fallen Shrine южнее;
- расширяет combat-zone footprints примерно на 10–15%;
- сохраняет Ancient Approach и Selene horizon на прежнем месте;
- увеличивает переход между верхними side-zones и Ancient Approach;
- удаляет отдельный ранний spider encounter из Meadows.
