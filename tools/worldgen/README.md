# Worldgen v0.1

Этот каталог содержит authoring-generator первого production-oriented рельефа Luna World v0.1.

Generator **не запускается в Roblox runtime**. Его задача — воспроизводимо построить исходный heightmap, карту мира и debug overlays, после чего heightmap импортируется в Roblox Terrain Editor и локально дорабатывается инструментами Terrain.

## Источник

\`world_v01.json\` — production authoring source для macro-layout:

- масштаб X/Z;
- bounds карты;
- POI;
- spawn areas;
- route graph;
- river;
- широкие terrain grounding areas.

Gameplay stable IDs остаются совместимыми с \`src/shared/world/WorldLayout.luau\`.

Текущий baseline: **2×** относительно первого greybox.

## Установка

Из корня репозитория:

\`\`\`powershell
python -m pip install -r tools/worldgen/requirements.txt
\`\`\`

## Генерация

\`\`\`powershell
python tools/worldgen/generate_world.py
\`\`\`

По умолчанию создаётся:

\`artifacts/worldgen/v01/\`

Файлы:

- \`world_v01_heightmap.png\` — 16-bit grayscale heightmap;
- \`world_v01_water_mask.png\` — reference mask русла;
- \`world_v01_topdown.png\` — сводная top-down карта;
- \`world_v01_routes_overlay.png\` — прозрачный overlay маршрутов;
- \`world_v01_poi_spawn_overlay.png\` — POI и spawn areas;
- \`world_v01_zones_overlay.png\` — presentation volumes;
- \`world_v01_manifest.json\` — параметры генерации и расчётные уклоны.

Generated PNG не являются ручным source-of-truth: при изменении \`world_v01.json\` их надо пересоздать.

## Размер первой карты

Authoring bounds:

- X: \`-1300 .. 1300\`;
- Z: \`-650 .. 4150\`;
- размер: **2600 × 4800 studs**;
- height range: \`0 .. 128 studs\`;
- image resolution: **650 × 1200**.

Центр import-region:

- X = \`0\`;
- Y = \`64\`;
- Z = \`1750\`.

Размер import-region:

- X = \`2600\`;
- Y = \`128\`;
- Z = \`4800\`.

Эти значения должны использоваться как исходные при импорте heightmap в Roblox Terrain Editor. Если Studio округляет region под voxel-grid, допускается ближайшее кратное 4 studs; после импорта надо повторно проверить bridge/road anchors.

## Что уже формирует v1

Macro terrain:

- высокий Luna Village hill;
- плавный спуск Village → Meadows;
- широкая Meadows basin;
- реальное русло через Meadows в районе моста;
- Moonfall Road spine;
- повышенный western shoulder и Goblin Camp;
- пониженный Spider Hollow;
- Dark Woodland approach;
- высокие natural boundary ridges по внешнему периметру с проходом в сторону будущего Dark Woodland.

Routes не строятся плоскими Part-плитами. Generator мягко формирует terrain вокруг centerline и target elevation, поэтому переходы остаются частью земли.

## Ограничения v1

Это macro-terrain pass, а не final terrain.

После импорта в Studio ещё обязательны:

- Terrain Smooth/Sculpt вокруг ключевых точек;
- реальный Terrain Water по water mask/reference;
- формирование берегов;
- проверка bridge approaches;
- forest/cliff containment;
- grounding зданий/props через terrain surface;
- no-jump traversal acceptance;
- mobile/gamepad runtime test.

Не начинать final art/foliage pass до принятия macro terrain и traversal.
