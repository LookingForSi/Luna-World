# Mob Content Pass v0.1 — население Moonfall Valley

Дата: 2026-09-19  
Статус: implementation baseline

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
Chieftain — локальный elite с Heavy Strike и Battle Cry.

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
