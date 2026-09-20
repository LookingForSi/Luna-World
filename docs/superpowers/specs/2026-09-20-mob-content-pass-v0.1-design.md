# Mob Content Pass v0.1 — население Moonfall Valley

Дата: 2026-09-20
Статус: утверждено для реализации

## Цель

Превратить принятую карту v0.1 из traversal/blockout-сцены в полноценную PvE-прогрессию уровней 1–14 с резервом уровня 15 под Ruins of Selene поверх Milestone 2: бой, XP, loot, inventory, equipment и persistence должны проверяться на реальном населении мира.

Маршрут прогрессии:

`Luna Village → Farm / Meadows → Wolf Pack → Moonfall Road → Goblin Camp / Spider Hollow → Dark Woodland → Old Cemetery / Fallen Shrine → Ancient Approach → Ruins of Selene`.

Ruins of Selene остаётся отдельным будущим dungeon-pass.

## Правила экологии

- Young Wolves у фермы — одиночные и в основном пассивные.
- Взрослые Wolves социальны только внутри малых стай.
- Goblins организованы в небольшие linked groups; один удар не должен агрить весь лагерь.
- Goblin patrols реально двигаются вокруг лагеря.
- Spider Hollow намеренно несоциальный и пассивный: соседние пауки не помогают друг другу и не начинают бой первыми.
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
Shaman использует Spirit Bolt, War Chant и Проклятие шамана; его базовая атака является магической дальней.
Chieftain — локальный elite с Sling Stone, Heavy Strike, Cleave и Battle Cry, повышенным шансом и множителем критического удара.

### Spider Hollow, lvl 6–8
- 8 Venom Spider;
- 2 Brood Spider.
- Social assist отсутствует.
- Venom Spit: DoT.
- Crippling Venom: временно снижает movement speed и attack speed.
- Brood Spider имеет больше HP/damage и усиленные варианты яда.

### Dark Woodland, lvl 9–11
- Dire Wolf в малых стаях;
- Forest Spider одиночками;
- 1 Dire Wolf Alpha.

### Old Cemetery, lvl 11–13
- Skeleton;
- Skeleton Archer;
- Grave Guardian elite.
- Небольшие encounter-groups, а не глобальная social aggro.

### Fallen Shrine, lvl 12–13
- Fallen Acolyte — magic ranged;
- Shrine Guardian — тяжёлый melee.

### Ancient Approach, lvl 13–14
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

Числа ниже соответствуют текущему server tuning после dev0.2 difficulty pass.

| Тип | Уровень | Ранг | HP | P.Def / M.Def | XP |
|---|---:|---|---:|---:|---:|
| Young Wolf | 1 | ordinary | 70 | 1 / 1 | 15 |
| Grey Wolf | 2 | ordinary | 105 | 2 / 2 | 25 |
| Wolf Pack Leader | 3 | elite | 180 | 4 / 3 | 55 |
| Venom Spider | 4 | ordinary | 175 | 4 / 11 | 50 |
| Goblin Scout | 4 | ordinary | 145 | 4 / 2 | 55 |
| Goblin Warrior | 5 | ordinary | 225 | 7 / 3 | 78 |
| Goblin Shaman | 6 | ordinary | 240 | 4 / 12 | 120 |
| Brood Spider | 7 | ordinary | 380 | 7 / 16 | 130 |
| Goblin Chieftain | 7 | elite | 600 | 14 / 9 | 260 |
| Dire Wolf | 8 | ordinary | 285 | 8 / 5 | 125 |
| Forest Spider | 9 | ordinary | 260 | 7 / 13 | 150 |
| Dire Wolf Alpha | 10 | elite | 540 | 13 / 9 | 250 |
| Skeleton | 10 | ordinary | 310 | 13 / 4 | 165 |
| Skeleton Archer | 11 | ordinary | 245 | 8 / 4 | 190 |
| Fallen Acolyte | 11 | ordinary | 280 | 7 / 14 | 195 |
| Grave Guardian | 12 | elite | 680 | 18 / 11 | 320 |
| Shrine Guardian | 12 | ordinary | 500 | 17 / 10 | 255 |
| Ancient Sentinel | 13 | ordinary | 620 | 20 / 12 | 310 |
| Ancient Watcher | 14 | ordinary | 410 | 10 / 18 | 340 |
| Moonbound Warden | 14 | elite | 1200 | 25 / 20 | 550 |
| Selene's Fallen Guardian | 15 | boss / future dungeon | TBD | TBD | TBD |

Полная оперативная таблица base damage, crit и abilities поддерживается в `docs/MOB_BESTIARY.md`.


## Способности и эффекты

- Physical ranged: Sling Stone и Skeleton Arrow; magic ranged: Spirit Bolt, Проклятие шамана и acolyte/ancient bolts.
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

Каждый stable mob ID ссылается на существующую loot table. Таблицы повторно используют экипировку и consumables M2 и небольшой набор тематических материалов. Luna, шанс полезного предмета и качество таблицы растут с tier; elite loot интереснее, но rare gear не гарантируется на каждом respawn. XP монотонно соответствует уровню/опасности и поддерживает открытый маршрут 1–14; уровень 15 зарезервирован под финальный dungeon.

## Presentation и ограничения

Различимость обеспечивается server-created primitive profiles: размером, цветом, силуэтом и русским readable name. Это не production art. Ruins of Selene, raid framework, PvP и новые persistent schemas не входят в pass. Roblox Studio 1 server + 2 clients и визуальная/performance приёмка остаются owner checkpoint.
