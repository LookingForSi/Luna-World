# Moonfall Road + Side Zones — дизайн второго world-block

Статус: **черновик для review владельцем проекта**.

## 1. Цель

Создать второй world-block Luna World, продолжающий маршрут после `Luna Meadows` и впервые дающий игроку ощущение, что Moonfall Valley — не линейный коридор, а продольная долина с осмысленными боковыми зонами.

Основной маршрут блока:

`выход из Luna Meadows → Moonfall Road → центральная развилка → Goblin Camp / Spider Hollow → продолжение main road → вход в Dark Woodland`

Этот документ описывает **greybox / level-design pass**. Финальный art, полноценный Mob AI, quests и loot в scope не входят.

## 2. Связь с первым world-block

Блок начинается от стабильного marker:

- `exit_moonfall_road`

из спецификации:

- `docs/superpowers/specs/2026-09-14-luna-village-meadows-design.md`

Направление глубже в Moonfall Valley остаётся `+Z`.

Ожидаемая точка входа из первого блока находится примерно возле:

```text
(0, 4, 900)
```

Точная стыковка должна использовать канонический `WorldLayout`, а не дублированные числа в builder-модулях.

Второй блок не должен создавать отдельный Place, отдельный lobby или teleport. Он является продолжением того же бесшовного open-world Place.

## 3. Композиционный принцип

Moonfall Road остаётся визуальным позвоночником зоны.

Игрок должен:

1. естественно выйти из открытых Meadows на более собранную дорогу;
2. увидеть признаки того, что территория становится опаснее;
3. дойти до хорошо читаемой центральной развилки;
4. понять, что слева и справа существуют самостоятельные боковые зоны;
5. при этом не потерять главное направление — дальше, к Dark Woodland и будущим Ruins of Selene.

Goblin Camp и Spider Hollow — **боковые карманы**, а не две обязательные параллельные кампании и не альтернативные длинные маршруты через всю карту.

Main road не должен визуально исчезать из-за боковых ответвлений.

## 4. Масштаб greybox

Размеры являются целевыми для blockout и могут корректироваться после Studio playtest, но не должны произвольно меняться агентом.

### 4.1. Main route

От `exit_moonfall_road` до входа в Dark Woodland:

- ориентировочно **800–1000 studs по main route**;
- целевая конечная область примерно возле `Z = 1750–1900`;
- дорога должна иметь плавные изгибы и небольшие перепады высоты, а не идти прямой полосой.

### 4.2. Боковые зоны

Каждый side pocket:

- уходит от main road примерно на **200–350 studs**;
- должен ощущаться отдельным encounter-space;
- должен возвращать игрока к той же центральной оси мира;
- не должен быть настолько большим, чтобы визуально конкурировать с будущим Dark Woodland.

### 4.3. Высотный контраст

Для читаемости рекомендуется:

- Moonfall Road постепенно поднимается от Meadows;
- Goblin Camp расположен немного выше дороги на террасе / склоне;
- Spider Hollow расположен ниже дороги в естественном углублении / ложбине;
- вход в Dark Woodland снова немного поднимается.

Это создаёт три разных силуэта без необходимости перегружать мир props-ами.

## 5. Moonfall Road

### 5.1. Характер

Moonfall Road — переход от светлой стартовой зоны к более опасной средней части долины.

Визуальный характер:

- дорога становится уже и каменистее;
- открытые поля постепенно уступают кустарнику, скалам и группам деревьев;
- появляются остатки старых каменных конструкций;
- освещение и палитра могут становиться немного холоднее;
- Luna Village позади всё ещё может быть видна с отдельных возвышений, но уже не доминирует в композиции.

### 5.2. Не коридор

По сторонам дороги должно оставаться пространство для боя и исследования.

Запрещённый результат:

`две непрерывные стены / скалы + узкая дорога между ними`.

Предпочтительный результат:

`широкая долина → естественные ограничения рельефом → читаемые боковые карманы → снова раскрывающийся main route`.

### 5.3. Environmental storytelling

Greybox должен оставить места минимум под два простых environmental beats:

- брошенная / сломанная повозка возле дороги;
- старый дорожный камень / указатель возле развилки.

Они нужны для композиции и будущих quest/lore hooks, но интерактивность сейчас не реализуется.

## 6. Центральная развилка

Развилка — главный landmark блока.

Рабочее назначение:

- main road продолжает вести вперёд к Dark Woodland;
- западное ответвление ведёт к Goblin Camp;
- восточное ответвление ведёт к Spider Hollow.

Развилка должна читаться геометрией мира, а не только UI-marker'ами.

### 6.1. Landmark развилки

Основной landmark:

- старый повреждённый дорожный монолит / waystone;
- рядом остатки низкой каменной кладки;
- достаточно свободного пространства, чтобы несколько игроков могли одновременно сражаться / выбирать направление.

Stable ID:

- `poi_moonfall_crossroads`

### 6.2. Ориентация

С развилки желательно одновременно считывать:

- частокол / дым Goblin Camp на возвышении слева;
- тёмную ложбину / скальные формы Spider Hollow справа;
- более плотную линию леса прямо впереди — будущее Dark Woodland.

## 7. Goblin Camp

### 7.1. Роль

Goblin Camp — первая более организованная humanoid enemy-zone.

Ориентировочная сложность:

- **уровни 4–7**.

Она должна контрастировать с природными Wolves/Spiders тем, что противник **занял и укрепил территорию**.

### 7.2. Композиция

Camp располагается западнее main road на приподнятой террасе.

Greybox-состав:

- вход / узкий контролируемый проход;
- короткие участки грубого частокола;
- 2–3 простых навеса / hut volumes;
- костровая / центральная площадка;
- небольшая lookout-позиция;
- груды ящиков / бочек как blockout будущего лагерного clutter;
- один более глубокий encounter-space внутри camp.

Camp не должен выглядеть крепостью или городом.

### 7.3. Gameplay-spatial intent

Внешняя часть:

- более редкие противники;
- пространство для знакомства с Goblin Scout.

Внутренняя часть:

- плотнее;
- поддерживает Goblin Warrior;
- место под будущего stronger variant / miniboss hook без обязательной реализации elite в этом блоке.

### 7.4. Spawn areas

Минимум stable markers:

- `spawn_goblin_scout_outer`
- `spawn_goblin_scout_road`
- `spawn_goblin_warrior_camp`
- `spawn_goblin_camp_elite_future`

Рекомендуемые Mob IDs для будущих definitions:

- `mob_goblin_scout`
- `mob_goblin_warrior`

`spawn_goblin_camp_elite_future` является reservation marker и не требует spawn работающего elite до соответствующего gameplay/content milestone.

## 8. Spider Hollow

### 8.1. Роль

Spider Hollow — природный опасный side pocket, противопоставленный организованному Goblin Camp.

Ориентировочная сложность:

- **уровни 4–6**.

Зона должна выглядеть как место, в которое игрок **спускается**, а не как ещё одна поляна рядом с дорогой.

### 8.2. Композиция

Spider Hollow располагается восточнее main road в естественной ложбине / небольшой каменистой впадине.

Greybox-состав:

- спуск с дороги;
- скальные стенки неполного периметра;
- несколько массивных деревьев / корней как blockout silhouettes;
- rock arch или неглубокий cave-mouth как дальний landmark;
- небольшое внутреннее пространство brood-area;
- отдельный путь возврата к main road без настоящего dungeon-перехода.

Cave-mouth в этом блоке не является dungeon и не ведёт в отдельный Place.

### 8.3. Spawn areas

Минимум stable markers:

- `spawn_spider_hollow_outer`
- `spawn_spider_hollow_mid`
- `spawn_spider_hollow_brood`

Рекомендуемые Mob IDs:

- `mob_meadow_spider` для внешней части, если этот ID уже закреплён предыдущим world-block;
- `mob_brood_spider` для более глубокой части после соответствующего content pass.

## 9. Main route после развилки

После crossroads main road продолжает идти между двумя side pockets.

Игрок не обязан проходить сквозь центр Goblin Camp или Spider Hollow, чтобы двигаться дальше.

На main route допустимы отдельные encounters / patrol markers, но дорога не должна превращаться в непрерывную цепочку агро-мобов.

Минимум один участок после развилки должен давать небольшой визуальный отдых перед входом в Dark Woodland.

Это сохраняет ритм:

`бой / исследование → короткая передышка → визуальный порог следующего региона`.

## 10. Вход в Dark Woodland

Dark Woodland целиком **не входит** в этот world-block.

Задача блока — создать сильный визуальный threshold и stable handoff в следующий регион.

### 10.1. Визуальный threshold

У входа должны читаться:

- более высокая и плотная линия деревьев;
- сужение открытого пространства без превращения в тесный тоннель;
- остатки древних каменных столбов / boundary stones;
- заметно более тёмная глубина леса;
- main road, продолжающийся внутрь.

### 10.2. Stable IDs

- `poi_dark_woodland_gate`
- `entry_dark_woodland`

`entry_dark_woodland` является marker перехода в будущую logical zone `zone_dark_woodland`, но не teleport.

## 11. Zone / POI IDs

Для второго блока фиксируются стабильные IDs.

### Zones

- `zone_moonfall_road`
- `zone_goblin_camp`
- `zone_spider_hollow`

`zone_dark_woodland` резервируется как следующая зона, но в этом блоке реализуется только её entrance marker.

### Points of Interest

- `poi_moonfall_crossroads`
- `poi_broken_wagon`
- `poi_old_waystone`
- `poi_goblin_camp`
- `poi_goblin_lookout`
- `poi_spider_hollow`
- `poi_spider_cave_mouth`
- `poi_dark_woodland_gate`
- `entry_dark_woodland`

Display names могут меняться. Stable IDs не переименовываются без отдельного изменения contract/references.

## 12. Рекомендуемый layout contract

Координаты являются ориентиром для следующего implementation plan и должны быть окончательно состыкованы с фактическим `WorldLayout` после принятия PR #4.

Предлагаемый blockout:

```text
exit_moonfall_road       ~ (0,   4,  900)
poi_broken_wagon         ~ (-70, 9, 1050)
poi_moonfall_crossroads  ~ (20, 16, 1220)

poi_goblin_camp          ~ (-300, 30, 1400)
poi_goblin_lookout       ~ (-360, 42, 1510)

poi_spider_hollow        ~ (300, 2, 1420)
poi_spider_cave_mouth    ~ (360, 0, 1530)

poi_dark_woodland_gate   ~ (20, 24, 1740)
entry_dark_woodland      ~ (0,  26, 1840)
```

Главный принцип важнее точной цифры:

- west pocket визуально выше;
- east pocket визуально ниже;
- main route остаётся центральной осью;
- Dark Woodland entrance находится глубже по `+Z` и выше стартовой части блока.

## 13. Quest / narrative intent как level-design ориентир

QuestService в этой задаче не реализуется, но layout должен поддерживать естественную цепочку:

1. игрок выходит из Meadows и идёт по Moonfall Road;
2. находит следы нападений / сломанную повозку;
3. приходит к crossroads;
4. получает основания исследовать Goblin Camp и/или Spider Hollow;
5. понимает, что проблемы долины не ограничиваются Wolves возле фермы;
6. после боковых encounters main route ведёт глубже к Dark Woodland.

Точный lore о причине общего беспокойства существ Moonfall Valley не фиксируется этой спецификацией окончательно. Важно лишь сохранить мотив: **опасность усиливается по мере движения вглубь долины**.

## 14. Технический подход к greybox

Второй блок должен расширять уже существующий world contract, а не создавать параллельную систему.

### В Git

Ожидается расширение:

- `WorldLayout`;
- world validation;
- существующего managed greybox builder;
- world tests.

Допустимы отдельные focused builder-модули по зонам, например:

- Moonfall Road;
- Goblin Camp;
- Spider Hollow.

Точная файловая структура определяется implementation plan после принятия этого spec.

### Workspace

Используется тот же managed root:

`Workspace/LunaWorldGreybox`

Не создавать второй конкурирующий world root.

Builder по-прежнему:

- не удаляет посторонние объекты Workspace;
- остаётся идемпотентным;
- не использует per-frame loops;
- не содержит gameplay-authority logic.

## 15. Зависимость от PR #4

Implementation этого блока **не начинается до visual/runtime review PR #4**, если владелец явно не решит иначе.

Причина: масштаб дороги, ширина мира, реальная скорость перемещения и читаемость первого блока должны быть проверены в Roblox Studio до фиксации следующего набора координат.

После review PR #4 возможны два сценария:

1. PR #4 принимается без существенной коррекции — второй block строится от его фактического `WorldLayout`;
2. масштаб / elevation первого блока корректируются — координаты раздела 12 обновляются перед implementation plan.

## 16. Что НЕ входит в этот блок

Не реализовывать в рамках этой задачи:

- финальный Terrain/art pass;
- полноценный Dark Woodland;
- Old Cemetery;
- Fallen Shrine;
- Ancient Approach;
- Ruins of Selene;
- QuestService / диалоги;
- полноценный Mob AI, если он ещё не реализован соответствующим combat milestone;
- loot / inventory;
- persistence;
- party mechanics;
- dungeon mechanics;
- полноценного open-world miniboss.

## 17. Acceptance criteria greybox

Блок готов к visual/runtime review, если:

1. он бесшовно продолжается от фактического `exit_moonfall_road` первого world-block;
2. main road остаётся визуально читаемой осью;
3. central crossroads легко распознаётся без UI;
4. Goblin Camp и Spider Hollow ощущаются двумя разными side pockets;
5. Goblin Camp расположен визуально выше main road и содержит лагерь / lookout;
6. Spider Hollow расположен визуально ниже main road и содержит выраженный hollow / cave-mouth landmark;
7. игрок может двигаться дальше к Dark Woodland, не проходя через центр обеих боковых зон;
8. присутствуют stable spawn markers для Goblin и Spider areas;
9. есть broken wagon и waystone / crossroads landmark;
10. entrance Dark Woodland читается как следующий более опасный регион;
11. stable IDs не дублируются с первым world-block;
12. builder остаётся idempotent и destructive-safe;
13. world definitions / validation tests проходят;
14. Rojo build/sourcemap checks проходят;
15. финальная визуальная читаемость, масштаб, collisions и walkability проверяются вручную в Roblox Studio.
