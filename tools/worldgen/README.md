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
- выраженная приподнятая Goblin Camp shelf с внешним rough rim;
- пониженный Spider Hollow с отдельным enclosing rim;
- Dark Woodland approach;
- future terrain reservations под Old Cemetery и Fallen Shrine — как приподнятые площадки, но пока без gameplay zones;
- высокие natural boundary ridges по внешнему периметру с проходом в сторону будущего Dark Woodland;
- крупный Selene horizon massif за северной границей playable area.

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


## Terrain v0.2 — характер зон

Вторая macro-итерация намеренно разделяет **playable core** и **silhouette**:

- Goblin Camp имеет относительно спокойное внутреннее поле боя, но сидит на поднятой shelf и окружён rough terrain rim. Позже этот силуэт усиливается палисадом, huts, кострами и rock kit.
- Spider Hollow имеет проходимое ядро, но находится в заметной чаше с отдельным rim. Позже граница усиливается rocks, roots, dark trees и web kit.
- Old Cemetery и Fallen Shrine пока **не входят в gameplay scope v0.1**. Generator резервирует для них terrain silhouette из approved concept, чтобы дальнейшее расширение мира не потребовало ломать Selene-side geography.
- regular terrain имеет authoring floor выше нуля; к низкой отметке опускается только специально вырезанное русло. Это предотвращает случайные holes в Terrain import.

Высота import-region увеличена до 192 studs, потому что Selene massif больше не должен обрезаться верхней границей heightmap.
