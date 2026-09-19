# Luna World — ТЗ на production-rework мира v0.1

Статус: **approved for implementation — 2026-09-19**.

## 1. Цель

Полностью переработать текущий procedural greybox мира v0.1 из набора отдельных Part-платформ в цельный, непрерывный, визуально читаемый и гарантированно проходимый без прыжков игровой ландшафт.

Целевой маршрут v0.1:

`Luna Village → Luna Meadows → Moonfall Road → crossroads → Goblin Camp / Spider Hollow → entrance to Dark Woodland`.

Ruins of Selene в этот world-pass не строятся, но направление и distant-view должны быть зарезервированы.

Текущий Part-based greybox считается **прототипом layout и масштаба**, а не production-геометрией. Stable IDs, approved POI, route topology и принятый масштаб сохраняются как дизайн-контракт; конкретная форма земли и расположение объектов могут быть переработаны.

## 2. Принцип инструментария

### 2.1. Roblox Terrain — основной playable landscape

Использовать Roblox Terrain для:

- основной поверхности мира;
- холмов, откосов, склонов и террас;
- естественных границ;
- русла реки;
- воды;
- берегов;
- грунтовых дорог и широких дорожных коридоров;
- плавных переходов между высотами;
- локального сглаживания вокруг POI.

Не строить основной ландшафт как набор больших тонких Part-плит.

### 2.2. Blender / MeshPart — архитектура и landmarks

Использовать Blender или Studio-моделирование для:

- зданий;
- мостов;
- ворот;
- заборов;
- руин;
- крупных камней;
- корней;
- waystone;
- broken wagon;
- cave mouth;
- Goblin Camp props;
- уникальных landmarks.

Не использовать Blender как единственный инструмент для всей playable поверхности мира. Главный walking surface должен оставаться простым для правок, проверки коллизий и мобильного playtest.

### 2.3. Luau / Rojo — gameplay contract, а не terrain geometry

Luau отвечает за:

- stable IDs;
- zone definitions;
- spawn definitions;
- NPC/quest anchors;
- safe-zone / recovery logic;
- runtime validation;
- debug visualization;
- тесты world-contract;
- optional one-shot generation helpers.

Production terrain и архитектура не должны зависеть от runtime-генерации огромных Part-платформ.

## 3. Размер и масштаб

Принять увеличенный горизонтальный масштаб как новый baseline:

- world X/Z spacing = **2×** относительно первого greybox;
- здания и персонажи не масштабируются;
- ширина main roads ориентировочно 20–28 studs;
- secondary paths 12–18 studs;
- открытые encounter pockets должны быть заметно шире дороги и позволять бой нескольких игроков без упора в край.

Цель по ощущению:

- мир не должен проходиться визуально “за минуту”;
- из одной точки не должны одновременно читаться все POI;
- соседние зоны должны быть связаны направлением и landmarks, но не выглядеть как элементы одного маленького макета;
- игрок должен периодически терять прямую видимость предыдущей зоны за рельефом, деревьями или поворотом дороги.

## 4. Непрерывность и проходимость

Luna World не использует свободный прыжок как нормальную механику traversal.

Обязательные правила:

- весь intended critical path проходится обычным WASD / stick movement без прыжка;
- любой перепад высот между playable surfaces имеет непрерывный walkable slope/ramp;
- нельзя делать one-way ledge, с которого можно спрыгнуть и нельзя вернуться;
- нельзя использовать бордюры / ступени, которые требуют Roblox auto-step для прохождения критического маршрута;
- поверхности дорог, мостов и склонов должны стыковаться без вертикальной губы;
- если используется лестница, она должна иметь walkable collision proxy в виде скрытого slope либо быть отдельно подтверждена runtime-test;
- main traversal route должен работать одинаково на desktop, gamepad и mobile.

### 4.1. Целевые уклоны

Для production greybox ориентироваться на:

- main route: обычно до 12°;
- secondary route: обычно до 18°;
- короткие optional slopes: до 22° только после runtime acceptance;
- переходы между крупными высотами лучше удлинять, а не делать крутыми.

## 5. Вертикальная модель мира

Вместо “платформа над платформой” использовать природную топографию:

- Luna Village — поселение на **крупном широком холме**, который целиком несёт деревню; это не локально поднятый край карты и не искусственная площадка;
- вершина Village Hill должна иметь достаточно спокойную широкую корону для застройки, а переход в Meadows должен читаться как естественный спуск с холма;
- Luna Meadows — широкая низина относительно Village;
- Goblin Camp — выраженная высокая терраса/склон;
- Spider Hollow — природная впадина;
- Moonfall Road — постепенно меняет высоту, но остаётся очевидным spine;
- Dark Woodland threshold — снова лёгкий подъём и сжатие пространства;
- противоположный северный горизонт долины замыкает **крупный Selene mountain massif**, визуально резервирующий дальнейшее направление к Ruins of Selene и восстанавливающий approved concept silhouette.

Высотные уровни должны быть соединены землёй, а не висящими плитами.

## 6. Естественные границы мира

Игрок не должен ощущать “невидимую коробку”, но и не должен свободно убегать на baseplate / за пределы контента.

Приоритет способов ограничения:

1. склоны / cliff faces;
2. плотный лес / крупные камни;
3. вода / овраг;
4. разрушенные стены / natural chokepoints;
5. invisible collision только там, где визуальная граница уже объясняет остановку;
6. server recovery остаётся fallback-защитой, но не заменяет level design.

Если игрок всё же вышел за playable area или провалился, recovery возвращает его на последнюю безопасную точку.

## 7. Grounding contract для объектов

Нельзя задавать production Y-position здания/NPC исключительно вручную и предполагать, что земля останется на той же высоте.

Для каждого ground-bound объекта:

- X/Z задаются layout/anchor;
- фактическая Y-позиция определяется поверхностью terrain / placement raycast / authoring snap;
- pivot здания должен стоять на земле;
- NPC anchor должен быть на проходимой поверхности;
- spawn center должен быть внутри проходимой зоны;
- после terrain-edit должна существовать автоматическая или ручная grounding-validation.

Не допускаются:

- висящие здания;
- NPC над землёй;
- props, наполовину утонувшие из-за изменения terrain;
- marker, расположенный в воздухе над склоном.

## 8. Река и мост

Luna Meadows должна иметь **реальную реку**, а не только мост.

Требования:

- Terrain Water;
- русло визуально читается до и после моста;
- берега имеют плавный рельеф;
- bridge deck стыкуется с дорогой без ступеньки;
- игрок не обязан входить в воду для продолжения;
- река служит landmark и локальной естественной границей;
- ширина и глубина не должны превращать её в огромную непреодолимую карту-границу.

## 9. Luna Village

Назначение: безопасная стартовая точка и компактный RPG-hub.

Обязательные элементы:

- main gate;
- training ground;
- blacksmith;
- village square;
- merchant;
- residential cluster;
- elder house;
- shrine;
- viewpoint toward future Ruins direction;
- с ключевых точек Village должен читаться дальний горный горизонт Selene, а не плоский край terrain.

Топография:

- поселение на возвышенности;
- 2–3 читаемых уровня допустимы;
- между всеми уровнями есть широкие проходные slopes;
- игрок может обойти village без прыжков;
- здания стоят непосредственно на terrain/pads, а не на висящих plate-terraces;
- выход к Meadows читается из Village Square / main route.

## 10. Luna Meadows

Назначение: первая открытая PvE-зона, безопасное обучение исследованию мира.

Обязательные элементы:

- переход из Village;
- Moonfall Farm;
- река;
- мост;
- Young Wolf area;
- Grey Wolf / Stone Circle area;
- Meadow Spider pocket;
- основной путь к Moonfall Road.

Moonfall Farm:

- farmhouse;
- barn;
- fenced sheep pen;
- well;
- 3 sheep placeholders;
- future NPC anchors;
- отдельная локальная обработка terrain без искусственной “платформы”.

Enemy areas должны находиться на естественно доступной земле. Никаких ступеней вокруг spawn-area.

## 11. Moonfall Road

Назначение: визуальный spine второй половины блока.

Обязательные элементы:

- дорога начинается естественно после Meadows;
- broken wagon;
- постепенное изменение настроения;
- old waystone;
- central crossroads;
- прямое продолжение к Dark Woodland.

Игрок должен всегда понимать:

- откуда пришёл;
- где main road;
- где ответвление Goblin Camp;
- где ответвление Spider Hollow.

Развилка должна читаться геометрией мира без UI-маркера.

## 12. Goblin Camp

Назначение: optional elevated humanoid-enemy pocket.

Требования:

- расположен заметно выше main road;
- доступен по широкому наклонному подъёму;
- вход и выход проходятся без прыжка;
- camp core — относительно спокойная площадка для боя;
- вокруг core рельеф образует **rough raised shelf / broken rim**, чтобы лагерь читался географически ещё до появления props;
- rim не должен превращаться в замкнутую чашу: intended entrance остаётся широким и pathable;
- terrain silhouette позже усиливается палисадом, huts, fire clearing, lookout, rocks и вытоптанной землёй;
- основная дорога не требует зачистки лагеря;
- лагерь должен быть заметен с crossroads, но не полностью раскрыт издалека;
- future elite reservation остаётся disabled.

## 13. Spider Hollow

Назначение: optional lower hostile pocket.

Требования:

- находится ниже main road;
- descent path полностью walkable;
- отдельный return path;
- hollow читается как **явная естественная чаша / ложбина**, а не ровная поляна;
- playable core остаётся достаточно ровным для боя;
- внешний rim/склоны географически отделяют pocket от Moonfall Road;
- один из краёв остаётся намеренно открыт под descent path, второй — под return route;
- rock perimeter;
- large roots / dark trees;
- cave mouth landmark;
- outer/mid spider zones;
- brood area остаётся future reservation;
- нельзя попасть вниз прыжком быстрее, чем intended path, и затем застрять.

## 13.1. Future Selene-side terrain reservations

Approved concept уже задаёт две будущие side-зоны за Dark Woodland: **Old Cemetery** и **Fallen Shrine**.

Они не становятся gameplay zones в текущем v0.1 pass, но macro terrain обязан заранее резервировать для них читаемую географию:

- Old Cemetery — **raised terrace / shelf**, а не яма или terrain-hole;
- Fallen Shrine — **raised promontory / shelf**, а не низкая впадина;
- обе площадки должны быть доступны для дальнейшего подключения дорог без перестройки всего Selene massif;
- debug/top-down overlay помечает их как `future`;
- gameplay zone IDs, mobs и rewards для них пока не создаются.

## 14. Dark Woodland threshold

Строится только вход / teaser следующего региона:

- более плотная растительность;
- более узкий visual corridor;
- boundary stones;
- dark tree silhouettes;
- дорога явно продолжается;
- нет полноценного Dark Woodland gameplay в этом pass.

## 15. World labels и debug presentation

Player-facing:

- при входе в новую зону краткая screen-title плашка;
- NPC labels отображаются только на разумной дистанции;
- enemy labels — по gameplay rules;
- никаких `poi_*`, `spawn_*`, stable IDs в обычном player-view.

Developer debug:

- debug markers могут включаться отдельным Studio-only toggle;
- stable IDs доступны через attributes / Explorer;
- debug visualization не входит в normal runtime presentation.

## 16. Collision и navigation

Для каждой зоны проверить:

- no jump required;
- no vertical lips на стыках terrain ↔ bridge ↔ mesh;
- нет узких щелей между terrain и props;
- игрок не застревает между buildings/fences;
- main road не перекрывается декоративными объектами;
- MeshPart collision для крупных props либо простой proxy collision, либо явно проверенный mode;
- future Mob AI должен иметь pathable corridor не уже player route.

## 17. Art direction для production blockout

Это всё ещё blockout, но уже world-shaped, а не набор кубов.

Нужно добиться:

- continuous landmass;
- читаемых силуэтов зон;
- natural slopes;
- hills that occlude distant POI;
- дороги как часть terrain;
- ясных landmarks;
- restrained serious fantasy tone.

Не требуется на этом pass:

- финальная архитектура;
- финальные текстуры;
- foliage density production-level;
- VFX polish;
- final lighting pass;
- decorative clutter everywhere.

## 18. Tool pipeline

### Stage A — layout source

В Git сохраняются:

- stable IDs;
- zone/POI/spawn definitions;
- high-level route graph;
- world scale;
- acceptance constraints.

### Stage B — macro terrain

Основной вариант:

- создаётся versioned heightmap / terrain source;
- импортируется в Roblox Terrain Editor;
- локально дорабатывается Sculpt/Smooth/Flatten/Paint;
- вода создаётся Terrain Water.

Heightmap должен покрывать весь текущий v0.1 world-block одним непрерывным landscape.

Для первой production-карты принять authoring bounds **2600 × 4800 studs** и heightmap **650 × 1200**, чтобы сохранять достаточную детализацию при масштабе 2×.

### Stage C — architecture / landmarks

Blender или Studio:

- здания;
- мост;
- rocks;
- gate;
- ruins;
- camp props.

Предпочтительный interchange:

- glTF для статической геометрии, где удобно;
- официальный Roblox Blender plugin допустим для ускорения iteration.

### Stage D — gameplay anchors

После terrain/layout pass:

- ground-snap POI/spawn anchors;
- validate stable IDs;
- place NPCs/mobs;
- run traversal and escape tests.

## 19. Автоматизация

Желательно сделать repo-tool, который из canonical world layout генерирует:

- heightmap draft;
- debug top-down map;
- POI overlay;
- spawn overlay;
- route overlay.

Это позволит менять масштаб/координаты без ручного пересоздания карты с нуля.

Runtime procedural terrain generation не является целью; generator нужен как authoring-tool.

## 20. Acceptance criteria

### Traversal

- spawn → Village → Meadows → Moonfall Road → Dark Woodland entrance без прыжка;
- crossroads → Goblin Camp → crossroads без прыжка;
- crossroads → Spider Hollow → return route → main road без прыжка;
- все intended height transitions двусторонние.

### Grounding

- 0 висящих зданий;
- 0 intended NPC anchors в воздухе;
- 0 critical-road vertical lips;
- bridge flush с обоими берегами.

### World containment

- нельзя беспрепятственно выбежать на baseplate;
- очевидные края мира закрыты environment geometry;
- fallback recovery возвращает игрока на safe point;
- нет softlock после падения.

### Readability

- Village, Farm, Stone Circle, Crossroads, Goblin Camp, Spider Hollow и Dark Woodland threshold имеют собственный silhouette/landmark;
- одновременно не читается вся карта целиком;
- main road можно найти без waypoint UI.

### Runtime

- desktop;
- gamepad;
- mobile emulator;
- 1 server + 2 clients;
- no recurring Output errors.

## 21. Что делать с текущим greybox

Текущие Part-based branches/PR сохраняются как reference implementation layout, но не полируются до production-quality.

После одобрения этого ТЗ:

1. PR #9 помечается как prototype/superseded для geometry;
2. новая работа идёт в `feature/world-v01-production-rework`;
3. stable IDs и gameplay contracts переносятся;
4. Part-platform terrain постепенно удаляется по мере появления нового Terrain-based world;
5. owner принимает мир по зонам и traversal, а не по отдельным техническим объектам.
