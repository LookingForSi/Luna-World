# Playable World Blockout Pass — production checklist

Дата: 2026-09-19  
База: `terrain-v05`  
Статус: **IMPLEMENTED — owner traversal pending**  
Цель: превратить принятый macro-terrain в пешком проверяемый игровой мир без попытки сделать final art.

## 1. Общие обязательные требования

### Обязательно
- не менять macro heightmap `terrain-v05` после этого correction pass без нового owner traversal review;
- все объекты, зависящие от земли, ground-snapped к фактическому Roblox Terrain через raycast;
- никакой обязательный маршрут не требует прыжка;
- прыжок отключён в preview;
- основной spawn находится в Luna Village;
- мир имеет invisible collision boundary и recovery для падения ниже terrain;
- permanent debug labels не используются;
- название зоны показывается кратким UI-toast только при входе в новую зону;
- дороги визуально читаемы, но их overlay не должен создавать ступеньки;
- generated blockout rebuild идемпотентен и удаляет только собственный managed root.

### Желательно
- единая restrained blockout palette;
- POI считываются по силуэту ещё до final assets;
- enemy placeholders показывают назначение encounter-space, но не реализуют combat;
- весь preview собирается из repo через Rojo.

### Потом
- final meshes/materials;
- Blender/Blender Studio asset replacement;
- foliage density pass;
- final lighting/VFX;
- actual quests/NPC logic;
- production mob spawning.

## 2. Luna Village

### Обязательно
- main gate;
- village square;
- well/landmark;
- blacksmith volume;
- merchant stall;
- residential houses;
- elder house;
- shrine;
- несколько ограждений/подпорных стен;
- spawn point.

### Желательно
- training yard;
- дополнительный house silhouette;
- sightline на северную долину.

### Потом
- final modular village kit;
- interiors;
- final NPCs/shops.

## 3. Moonfall Farm + early wolves

### Обязательно
- farmhouse;
- barn;
- fenced sheep pen;
- well/hay props;
- 3 sheep placeholders;
- farmer/future-NPC silhouettes;
- nearby wolf placeholders around `spawn_young_wolf_farm`;
- farm remains part of southern Meadows, not northern encounter block.

### Желательно
- broken fence / wolf-threat storytelling;
- cart/hay stacks.

### Потом
- animated sheep;
- farmer quest;
- actual wolf AI from gameplay branch.

## 4. River + bridge + Meadows

### Обязательно
- visible temporary water surface following authored river;
- collidable bridge;
- no-jump bridge approaches;
- main road from Village through Meadows;
- stone circle;
- wolf early-area placeholders;
- **никакого отдельного spider encounter сразу за мостом**: пауки начинаются только в Spider Hollow.

### Желательно
- roadside rocks / fences;
- broken wagon nearer Moonfall.

### Потом
- Terrain Water replacement;
- shoreline/material polish.

## 5. Moonfall Road

### Обязательно
- visually continuous road;
- crossroads landmark;
- broken wagon;
- waystone;
- readable forks to Goblin/Spider;
- road continues to Dark Woodland.

### Потом
- final signs/props;
- quest encounter dressing.

## 6. Goblin Camp

### Обязательно
- raised shelf remains visually readable;
- palisade;
- 2–3 hut/tent blockouts;
- central fire;
- watch point/tower;
- crates/rough props;
- goblin placeholders;
- route in/out needs no jump.

### Желательно
- partial enclosure rather than complete wall;
- stronger silhouette from crossroads.

### Потом
- final goblin architecture kit;
- actual AI/spawners.

## 7. Spider Hollow

### Обязательно
- low basin remains readable;
- cave-mouth landmark;
- rocks/roots/dead trunks;
- web blockouts;
- spider placeholders;
- intended descent and return route remain open.

### Желательно
- denser perimeter than center.

### Потом
- final cave mesh/web kit;
- ambient VFX.

## 8. Dark Woodland

### Обязательно
- obvious tree-line threshold;
- central passable corridor;
- no hard wall across main route;
- zone-entry toast.

### Желательно
- denser lateral tree masses;
- stone gate/ruin marker.

### Потом
- forest biome pass;
- fog/audio/lighting transition.

## 9. Old Cemetery

### Обязательно
- raised terrain terrace remains visible;
- cemetery boundary/fence;
- gravestones;
- small mausoleum/ruin silhouette;
- no gameplay logic yet.

### Потом
- crypt/undead content;
- final cemetery kit.

## 10. Fallen Shrine

### Обязательно
- raised promontory remains visible;
- columns;
- altar;
- broken arch/ruin silhouette;
- no gameplay logic yet.

### Потом
- final shrine kit;
- VFX/quest content.

## 11. Ancient Approach

### Обязательно
- broad high terrain remains dominant;
- main approach road visually continues through it;
- paired monumental pylons/columns;
- northern gateway silhouette toward Selene;
- zone-entry toast;
- no stairs required for traversal.

### Желательно
- progressively larger architecture toward north.

### Потом
- final ancient architecture kit;
- entrance logic to Ruins of Selene.

## 12. Acceptance — owner traversal

Owner walks from Village spawn through the world with jump disabled and checks:

1. Village → Farm → river/bridge.
2. Meadows early mob spaces.
3. Moonfall crossroads.
4. Goblin Camp round trip.
5. Spider Hollow descent + return.
6. Dark Woodland threshold.
7. Old Cemetery.
8. Fallen Shrine.
9. Ancient Approach.
10. No mandatory jump, invisible wall trap, floating major object, unrecoverable drop, or permanent debug-label spam.
11. Zone names appear only as temporary entry toasts.
12. Overall pacing/scale feels suitable before Blender art replacement.

Only after this traversal review should terrain-v04 be considered macro-frozen for the first art pass.


## 13. Реализованный preview pass

В ветке собран runtime blockout поверх импортированного `terrain-v05`:

- terrain-raycast grounding для всех крупных объектов;
- Luna Village;
- Moonfall Farm с farmhouse/barn/pen/овцами/NPC placeholders;
- early wolf placeholders и early spider pocket;
- временная water surface + collidable bridge + no-jump approaches;
- visual roads;
- Moonfall landmarks;
- Goblin Camp;
- Spider Hollow;
- Dark Woodland threshold;
- Old Cemetery;
- Fallen Shrine;
- Ancient Approach + distant Selene silhouette;
- invisible world boundaries;
- recovery при падении ниже мира;
- temporary zone-entry toast;
- jump disabled in preview, включая попытку скрыть touch jump button.

Production combat/AI специально не подключены: mob figures здесь являются spatial placeholders для traversal и масштаба.

Следующий gate: owner run-through по acceptance checklist раздела 12.


## 14. Owner traversal correction — combat block south shift

По результатам первого полного пешего прогона зафиксирована вторая пространственная итерация:

- Ancient Approach и направление на Ruins of Selene остаются на принятых координатах;
- Goblin Camp, Spider Hollow, Old Cemetery и Fallen Shrine сдвинуты южнее, ближе к реке и Moonfall crossroads;
- footprint четырёх combat-зон увеличен примерно на 10–15%;
- между верхней парой combat-зон и Ancient Approach оставлен более длинный переход;
- terrain pads / macro landforms / POI / spawn markers / branch roads сдвинуты синхронно;
- Spider Hollow сохраняет принятую owner'ом геометрию low basin;
- случайный early spider pocket в Meadows за мостом удалён полностью;
- Goblin Camp и Spider Hollow остаются по сторонам, утверждённым концептом;
- Ancient Approach и Selene horizon этой правкой не меняются.

Следующий gate: повторный owner traversal на `terrain-v05`.
