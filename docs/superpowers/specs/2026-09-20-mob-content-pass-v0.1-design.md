# Mob Content Pass v0.1 — население Moonfall Valley

Дата: 2026-09-20
Статус: утверждено для реализации

## Цель

Превратить принятую карту v0.1 из traversal/blockout-сцены в полноценную PvE-прогрессию уровней 1–10 поверх Milestone 2: бой, XP, loot, inventory, equipment и persistence должны проверяться на реальном населении мира.

Маршрут прогрессии:

`Luna Village → Farm / Meadows → Wolf Pack → Moonfall Road → Goblin Camp / Spider Hollow → Dark Woodland → Old Cemetery / Fallen Shrine → Ancient Approach → Ruins of Selene`.

Ruins of Selene остаётся отдельным будущим dungeon-pass.

## Правила экологии

- Young Wolves у фермы — одиночные и в основном пассивные.
- Взрослые Wolves социальны только внутри малых стай.
- Goblins организованы в небольшие linked groups; один удар не должен агрить весь лагерь.
- Goblin patrols реально двигаются вокруг лагеря.
- Spider Hollow намеренно несоциальный: соседние пауки не помогают друг другу.
- Dark Woodland смешивает уже знакомые угрозы.
- Old Cemetery строится на связках melee + ranged undead.
- Fallen Shrine — более магическая encounter-зона.
- Ancient Approach редкий по населению, но содержит тяжёлых врагов и open-world elite.

## Население

### Farm / Luna Meadows, lvl 1–2
- 6 Young Wolf.
- Без social assist.
- Небольшой roaming вокруг фермы.

### Wolf Pack / Stone Circle, lvl 2–3
- три малые пары Grey Wolf;
- один Pack Leader.
- Social assist только внутри конкретной пары/малой стаи.

### Moonfall Road
- один патруль из двух Goblin Scout как ранний сигнал следующей зоны.

### Goblin Camp, lvl 4–7
Внешний периметр:
- четыре patrol groups по два Goblin Scout.

Внутри:
- 2 Goblin Scout;
- 2 Goblin Warrior;
- 1 Goblin Shaman;
- 1 Goblin Chieftain.

Warrior сочетает melee и Sling Stone.
Shaman использует Spirit Bolt и War Chant.
Chieftain — локальный elite с Heavy Strike, Cleave и Battle Cry.

### Spider Hollow, lvl 4–6
- 8 Venom Spider;
- 2 Brood Spider.
- Social assist отсутствует.
- Venom Spit: DoT.
- Crippling Venom: временно снижает movement speed и attack speed.
- Brood Spider имеет больше HP/damage и усиленные варианты яда.

### Dark Woodland, lvl 6–8
- Dire Wolf в малых стаях;
- Forest Spider одиночками;
- 1 Dire Wolf Alpha.

### Old Cemetery, lvl 7–9
- Skeleton;
- Skeleton Archer;
- Grave Guardian elite.
- Небольшие encounter-groups, а не глобальная social aggro.

### Fallen Shrine, lvl 8–9
- Fallen Acolyte — magic ranged;
- Shrine Guardian — тяжёлый melee.

### Ancient Approach, lvl 9–10
- Ancient Sentinel;
- Ancient Watcher;
- Moonbound Warden — open-world elite перед Ruins of Selene.

## Combat contract

- Mob abilities полностью server-authoritative.
- Клиент не выбирает mob ability, cooldown, урон или debuff.
- Special ability использует тот же interrupt/action-generation boundary, что существующие mob attacks.
- Poison и cripple проверяют, что исходный персонаж игрока всё ещё жив/актуален.
- Social aggro задаётся stable `socialGroupId` на spawn marker, а не всей faction.
- Patrol задаётся spawn marker и не меняет home/leash authority.
- Spider magic defense должна реально снижать magic damage, а не быть только текстовой характеристикой.

## Respawn baseline

- обычные стартовые мобы: 18–24 сек;
- обычные средние/поздние: 24–35 сек;
- сильные варианты: 35–50 сек;
- локальные elite: 60–90 сек.

## Art scope

Текущий pass использует различимые primitive silhouettes/colors как gameplay placeholders. Они не являются финальным art. Позднее они заменяются Blender/Blender Studio kit без изменения stable mob IDs, spawn IDs и gameplay topology.


## Матрица характеристик и наград

Все числа являются первой серверной настройкой и уточняются только после runtime-приёмки.

| Тип | Уровень | Ранг | P.Def / M.Def | XP | Respawn | Loot |
|---|---:|---|---:|---:|---:|---|
| Young Wolf | 1 | ordinary | 1 / 1 | 15 | 18 с | `loot_young_wolf` |
| Grey Wolf | 2 | ordinary | 2 / 2 | 25 | 22 с | `loot_grey_wolf` |
| Wolf Pack Leader | 3 | elite | 4 / 3 | 55 | 40 с | `loot_wolf_pack_leader` |
| Goblin Scout / Warrior / Shaman | 4 / 5 / 6 | ordinary | специализация по роли | 55 / 78 / 105 | 25–40 с | отдельные goblin tables |
| Goblin Chieftain | 7 | elite | 11 / 7 | 210 | 75 с | `loot_goblin_chieftain` |
| Venom / Brood Spider | 4 / 6 | ordinary | 4/11 и 6/15 | 50 / 110 | 25 / 45 с | spider tables |
| Dire Wolf / Alpha | 6 / 8 | ordinary / elite | 6/4 и 10/7 | 95 / 190 | 30 / 60 с | wolf tables |
| Forest Spider | 7 | ordinary | 5 / 10 | 120 | 32 с | `loot_forest_spider` |
| Skeleton / Archer | 7 / 8 | ordinary | 10/3 и 6/3 | 125 / 145 | 30–34 с | undead tables |
| Grave Guardian | 9 | elite | 14 / 8 | 240 | 70 с | `loot_grave_guardian` |
| Fallen Acolyte / Shrine Guardian | 8 / 9 | ordinary | 5/11 и 13/8 | 150 / 200 | 34 / 45 с | shrine tables |
| Ancient Sentinel / Watcher | 9 / 10 | ordinary | 15/9 и 8/13 | 220 / 230 | 42–45 с | ancient tables |
| Moonbound Warden | 10 | elite | 18 / 14 | 420 | 90 с | `loot_moonbound_warden` |

## Способности и эффекты

- Physical ranged: Sling Stone и Skeleton Arrow; magic ranged: Spirit Bolt, acolyte/ancient bolts.
- Poison заменяет прежний poison того же игрока новой generation: длительность обновляется, два DoT не тикают параллельно.
- Crippling Venom временно применяет минимальные movement/attack-speed multipliers; повторное применение обновляет generation и срок, но не перемножает штрафы.
- War Chant усиливает живых союзников той же faction в локальном радиусе; повторное применение сохраняет наибольший multiplier и обновляет срок без бесконечного stacking.
- Cleave и тяжёлые slam-атаки используют ограниченный server-side area query; клиент не передаёт список целей.
- Cooldown, health gate, range, windup, повторная проверка живой цели и action generation рассчитываются сервером.

## Social и patrol contract

`socialGroupId` принадлежит spawn marker, поэтому совпадение faction само по себе не вызывает помощь. Assist допустим только при совпадающем непустом group ID, в `socialAssistRadius`, для живого моба не в Return. Источник в Return/Dead не создаёт новый assist. Это исключает цепную агрессию через карту и делает пауков несоциальными без проверки stable mob ID.

Patrol задаётся `patrolRadius` и `patrolCycleSeconds` в `WorldLayout.SpawnMarkers`. Члены связанной пары используют общую фазу и formation offset. Combat переводит AI через Aggro/Chase/Attack, leash — через Return, а прибытие домой восстанавливает Idle, здоровье и patrol lifecycle. Один decision может быть in-flight; generation отбрасывает результат устаревшего path computation после death/unregister.

## Размещение и плотность

- Meadows: 6 Young Wolves; Stone Circle: 6 Grey Wolves и leader.
- Moonfall Road: обходная пара scouts.
- Goblin Camp: четыре пары patrol scouts и 6 внутренних гоблинов.
- Spider Hollow: 8 Venom и 2 Brood Spiders без social group.
- Dark Woodland: 6 Dire Wolves, Alpha и 4 Forest Spiders с просветом вдоль маршрута.
- Cemetery: 6 Skeletons, 3 Archers и Grave Guardian.
- Shrine: 5 Acolytes и 3 Guardians, разбитые на малые группы.
- Ancient Approach: 4 Sentinels, 2 Watchers и Moonbound Warden.

## Loot и progression

Каждый stable mob ID ссылается на существующую loot table. Таблицы повторно используют экипировку и consumables M2 и небольшой набор тематических материалов. Luna, шанс полезного предмета и качество таблицы растут с tier; elite loot интереснее, но rare gear не гарантируется на каждом respawn. XP монотонно соответствует уровню/опасности и поддерживает маршрут 1–10 без отдельного клиентского reward path.

## Presentation и ограничения

Различимость обеспечивается server-created primitive profiles: размером, цветом, силуэтом и русским readable name. Это не production art. Ruins of Selene, raid framework, PvP и новые persistent schemas не входят в pass. Roblox Studio 1 server + 2 clients и визуальная/performance приёмка остаются owner checkpoint.
