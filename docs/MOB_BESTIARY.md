# Luna World — Mob Bestiary / Balance Reference

Статус: рабочий canonical reference для текущего server tuning dev0.2.  
Authoritative source остаётся в `src/shared/definitions/MobDefinitions.luau` и `MobAbilityDefinitions.luau`; этот документ нужен для быстрого чтения и balance review.

## Progression grid

| Зона / роль | Моб | LV | Rank | HP | P.Def | M.Def | Base attack | Crit | Abilities |
|---|---|---:|---|---:|---:|---:|---|---|---|
| Farm / Meadows | Молодой волк | 1 | Ordinary | 70 | 1 | 1 | 12 Physical | — | — |
| Stone Circle | Волк | 2 | Ordinary | 105 | 2 | 2 | 20 Physical | — | — |
| Stone Circle | Вожак стаи | 3 | Elite | 180 | 4 | 3 | 27 Physical | — | Вой стаи |
| Goblin / Road | Гоблин-разведчик | 4 | Ordinary | 145 | 4 | 2 | 24 Physical | — | — |
| Spider Hollow | Ядовитый паук | 4 | Ordinary | 175 | 4 | 11 | 20 Physical | — | Ядовитый плевок; Парализующий яд |
| Goblin Camp | Гоблин-воин | 5 | Ordinary | 225 | 7 | 3 | 28 Physical | — | Камень из пращи |
| Goblin Camp | Гоблин-шаман | 6 | Ordinary | 240 | 4 | 12 | 22 Magic, ranged | 12% ×1.60 | Боевой напев; Духовный снаряд; Проклятие шамана |
| Spider Hollow | Паук-матка | 7 | Ordinary | 380 | 7 | 16 | 32 Physical | — | Густой яд; Сковывающий яд |
| Goblin Camp | Гоблин-вожак | 7 | Elite | 600 | 14 | 9 | 44 Physical | **20% ×1.80** | Боевой клич; Камень из пращи; Тяжёлый удар; Рассекающий удар |
| Dark Woodland | Лютый волк | 8 | Ordinary | 285 | 8 | 5 | 36 Physical | — | Рывок |
| Dark Woodland | Лесной паук | 9 | Ordinary | 260 | 7 | 13 | 32 Physical | — | Ядовитый плевок |
| Dark Woodland | Альфа лютых волков | 10 | Elite | 540 | 13 | 9 | 48 Physical | — | Вой стаи; Рывок |
| Old Cemetery | Скелет | 10 | Ordinary | 310 | 13 | 4 | 40 Physical | — | — |
| Old Cemetery | Скелет-лучник | 11 | Ordinary | 245 | 8 | 4 | 24 Physical, ranged | — | Костяная стрела |
| Fallen Shrine | Павший служитель | 11 | Ordinary | 280 | 7 | 14 | 22 Magic, ranged | — | Печать немощи; Осквернённый снаряд |
| Old Cemetery | Могильный страж | 12 | Elite | 680 | 18 | 11 | 54 Physical | — | Могильный удар |
| Fallen Shrine | Страж святилища | 12 | Ordinary | 500 | 17 | 10 | 50 Physical | — | Удар хранителя |
| Ancient Approach | Древний страж | 13 | Ordinary | 620 | 20 | 12 | 56 Physical | — | Удар древнего стража |
| Ancient Approach | Древний наблюдатель | 14 | Ordinary | 410 | 10 | 18 | 30 Magic, ranged | — | Лунный импульс |
| Ancient Approach | Лунный страж | 14 | Elite | 1200 | 25 | 20 | 62 Physical | — | Пробуждение стража; Лунный разряд; Сотрясение |
| Ruins of Selene | **Selene's Fallen Guardian** | **15** | Boss | TBD | TBD | TBD | TBD | TBD | basic + telegraphed AoE + enrage; отдельный dungeon pass |

## Ability catalog

| Ability | Кто использует | Эффект |
|---|---|---|
| Вой стаи | Wolf Pack Leader, Dire Wolf Alpha | Локально усиливает урон волков на 15% на 8 с и зовёт союзников в радиусе 50 studs |
| Камень из пращи | Goblin Warrior, Goblin Chieftain | Physical ranged, 24 base damage, range 42, cooldown 5.5 с |
| Духовный снаряд | Goblin Shaman | Magic ranged, 36 base damage, range 50, cooldown 4.2 с |
| Боевой напев | Goblin Shaman | Усиливает урон ближайших goblin allies на 30% на 10 с, radius 60 |
| Проклятие шамана | Goblin Shaman | 12 Magic damage + 6 с: movement ×0.82, attack speed ×0.75 |
| Боевой клич | Goblin Chieftain | При HP ≤65% усиливает собственный урон ×1.40 на 12 с |
| Тяжёлый удар | Goblin Chieftain | 52 Physical damage, melee |
| Рассекающий удар | Goblin Chieftain | 40 Physical AoE, radius 13 |
| Ядовитый плевок | Venom / Forest Spider | Magic initial hit + конечный poison DoT |
| Парализующий яд | Venom Spider | Magic hit + временное снижение скорости движения и атаки |
| Густой яд | Brood Spider | Усиленный poison DoT |
| Сковывающий яд | Brood Spider | Усиленный slow / attack-speed debuff |
| Рывок | Dire Wolf / Alpha | Physical burst с увеличенной дистанции |
| Костяная стрела | Skeleton Archer | Physical ranged, 34 damage |
| Печать немощи | Fallen Acolyte | Magic hit + cripple |
| Осквернённый снаряд | Fallen Acolyte | Magic ranged, 40 damage |
| Могильный удар | Grave Guardian | Heavy Physical hit, 54 damage |
| Удар хранителя | Shrine Guardian | Heavy Physical hit, 50 damage |
| Удар древнего стража | Ancient Sentinel | Physical AoE, 62 damage |
| Лунный импульс | Ancient Watcher | Magic ranged, 50 damage |
| Сотрясение | Moonbound Warden | Physical AoE, 74 damage |
| Лунный разряд | Moonbound Warden | Magic ranged, 58 damage |
| Пробуждение стража | Moonbound Warden | При HP ≤55% self-buff урона ×1.45 на 12 с |

## Ролевые правила

- Молодые волки — стартовые, пассивные, без social assist.
- Все wolf-family mobs получают дополнительный ×1.25 movement multiplier поверх общего world multiplier ×1.2.
- Physical defense игрока использует пропорциональное снижение урона, чтобы ранние атаки не схлопывались до 1 damage.
- Обычные волки и goblins используют локальные social groups, а не глобальную faction aggro.
- Goblin Shaman — ranged support/caster: не должен сваливаться в бессмысленный melee после cooldown.
- Goblin Chieftain — локальный elite: должен быть опасен и на подходе за счёт пращи, а в melee — за счёт crit / Heavy Strike / Cleave.
- Spider Hollow намеренно несоциальный: паук не зовёт соседей.
- Late-game зоны растянуты так, чтобы открытый мир заканчивался на LV14.
- LV15 зарезервирован под Ruins of Selene и Selene's Fallen Guardian.

## Balance workflow

После каждого runtime pass фиксируем не только субъективное «жирный / больно», но и:
- сколько секунд занимает убийство моба каждым архетипом;
- сколько HP / resource теряет игрок;
- сколько мобов безопасно тянется одновременно;
- насколько читаемо срабатывают special abilities;
- какой уровень игрока ожидается в зоне;
- не становится ли regen причиной бесконечного sustain.

