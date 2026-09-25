# Luna World — Mob Bestiary / Balance Reference

Статус: рабочий canonical reference для текущего server tuning dev0.2.  
Authoritative source остаётся в `src/shared/definitions/MobDefinitions.luau`, `MobAbilityDefinitions.luau` и `LootTableDefinitions.luau`; этот документ нужен для быстрого чтения, balance review и проверки текущего loot routing.

## Progression grid

| Зона / роль | Моб | LV | Rank | HP | P.Def | M.Def | Base attack | Crit | Abilities |
|---|---|---:|---|---:|---:|---:|---|---|---|
| Farm / Meadows | Молодой волк | 1 | Ordinary | 70 | 1 | 1 | 12 Physical | — | — |
| Stone Circle | Волк | 2 | Ordinary | 105 | 2 | 2 | 20 Physical | — | — |
| Stone Circle | Вожак стаи | 3 | Elite | 180 | 4 | 3 | 27 Physical | — | Вой стаи |
| Goblin / Road | Гоблин-разведчик | 4 | Ordinary | 145 | 4 | 2 | 24 Physical | — | — |
| Spider Hollow | Ядовитый паук | 6 | Ordinary | 245 | 5 | 14 | 28 Physical | — | Ядовитый плевок; Парализующий яд |
| Goblin Camp | Гоблин-воин | 5 | Ordinary | 225 | 7 | 3 | 28 Physical | — | Камень из пращи |
| Goblin Camp | Гоблин-шаман | 6 | Ordinary | 240 | 4 | 12 | 22 Magic, ranged | 12% ×1.60 | Боевой напев; Духовный снаряд; Проклятие шамана |
| Spider Hollow | Паук-матка | 8 | Ordinary | 430 | 8 | 18 | 36 Physical | — | Густой яд; Сковывающий яд |
| Goblin Camp | Гоблин-вожак | 7 | Elite | 600 | 14 | 9 | 44 Physical | **20% ×1.80** | Боевой клич; Камень из пращи; Тяжёлый удар; Рассекающий удар |
| Dark Woodland | Лютый волк | 9 | Ordinary | 320 | 9 | 6 | 40 Physical | — | Рывок |
| Dark Woodland | Лесной паук | 10 | Ordinary | 330 | 8 | 15 | 36 Physical | — | Ядовитый плевок |
| Dark Woodland | Альфа лютых волков | 11 | Elite | 620 | 15 | 10 | 52 Physical | — | Вой стаи; Рывок |
| Old Cemetery | Скелет | 11 | Ordinary | 350 | 14 | 5 | 44 Physical | — | — |
| Old Cemetery | Скелет-лучник | 12 | Ordinary | 285 | 9 | 5 | 28 Physical, ranged | — | Костяная стрела |
| Fallen Shrine | Павший служитель | 12 | Ordinary | 320 | 8 | 16 | 26 Magic, ranged | — | Печать немощи; Осквернённый снаряд |
| Old Cemetery | Могильный страж | 13 | Elite | 760 | 20 | 12 | 58 Physical | — | Могильный удар |
| Fallen Shrine | Страж святилища | 13 | Ordinary | 560 | 18 | 11 | 54 Physical | — | Удар хранителя |
| Ancient Approach | Древний страж | 13 | Ordinary | 620 | 20 | 12 | 56 Physical | — | Удар древнего стража |
| Ancient Approach | Древний наблюдатель | 14 | Ordinary | 410 | 10 | 18 | 30 Magic, ranged | — | Лунный импульс |
| Ancient Approach | Лунный страж | 14 | Elite | 1200 | 25 | 20 | 62 Physical | — | Пробуждение стража; Лунный разряд; Сотрясение |
| Ruins of Selene | **Selene's Fallen Guardian** | **15** | Boss | TBD | TBD | TBD | TBD | TBD | basic + telegraphed AoE + enrage; отдельный dungeon pass |

## Loot / drop tables

Ниже указаны **фактические текущие шансы**, а не исходные коэффициенты из объявления таблицы. Для обычных crafting resources helper `resourceEntry(...)` применяет глобальный множитель ×0.5; здесь этот множитель уже учтён. Количество указано как `×1` или диапазон `×1–2`. Luna выдаётся при каждом убийстве в указанном диапазоне.

| Зона | Моб | Luna | Предметы и фактическая вероятность |
|---|---|---:|---|
| Farm / Meadows | Молодой волк | 1–3 | Волчья шкура ×1 — 22.5%; Острый клык ×1 — 7.5%; Малое лечебное зелье ×1 — 5%; Потрёпанные перчатки ×1 — 1% |
| Stone Circle | Волк | 2–5 | Волчья шкура ×1–2 — 32.5%; Острый клык ×1 — 17.5%; Малое лечебное зелье ×1 — 8%; Потрёпанный доспех ×1 — 1.5% |
| Stone Circle | Вожак стаи | 5–9 | Волчья шкура ×1–2 — 42.5%; Острый клык ×1–2 — 27.5%; Перчатки стража ×1 — 4%; Охотничий лук ×1 — 3% |
| Goblin / Road | Гоблин-разведчик | 4–8 | Гоблинский жетон ×1 — 27.5%; Железный лом ×1 — 37.5%; Малое лечебное зелье ×1 — 7%; Сапоги стража ×1 — 1.5% |
| Goblin Camp | Гоблин-воин | 6–11 | Гоблинский жетон ×1–2 — 37.5%; Железный лом ×1–2 — 42.5%; Малое лечебное зелье ×1 — 10%; Шлем стража ×1 — 1.5%; Железный клинок ×1 — 1.5% |
| Goblin Camp | Гоблин-шаман | 8–14 | Гоблинский жетон ×1–2 — 40%; **Магическая пыль ×1 — 100%**; Малое зелье ресурса ×1 — 14%; Серебряный лунный талисман ×1 — 5%; Рунный посох ×1 — 3% |
| Goblin Camp | Гоблин-вожак | 18–28 | Гоблинский жетон ×2–4 — 50%; Доспех стража ×1 — 3%; Железный клинок ×1 — 1.5%; Охотничий лук ×1 — 1.5%; Рунный посох ×1 — 1.5% |
| Spider Hollow | Ядовитый паук | 4–7 | Паучий шёлк ×1–2 — 37.5%; Ядовитая железа ×1 — 10%; Малое зелье ресурса ×1 — 8%; Лунный талисман ×1 — 1.5% |
| Spider Hollow | Паук-матка | 9–15 | Паучий шёлк ×1–3 — 45%; Ядовитая железа ×1 — 27.5%; Малое зелье ресурса ×1 — 14%; Серебряный лунный талисман ×1 — 3% |
| Dark Woodland | Лютый волк | 8–13 | Шкура лютого волка ×1 — 27.5%; Выделанная кожа ×1 — 32.5%; Острый клык ×1–2 — 22.5%; Перчатки стража ×1 — 1.5% |
| Dark Woodland | Лесной паук | 9–14 | Паучий шёлк ×1–2 — 32.5%; Ядовитая железа ×1 — 15%; Малое зелье ресурса ×1 — 9% |
| Dark Woodland | Альфа лютых волков | 16–25 | Шкура лютого волка ×1–2 — 45%; Острый клык ×1–2 — 37.5%; Выделанная кожа ×1 — 32.5%; Перчатки стража ×1 — 4% |
| Old Cemetery | Скелет | 10–16 | Фрагмент древней кости ×1–2 — 35%; Железный лом ×1 — 27.5%; Сапоги стража ×1 — 1.5% |
| Old Cemetery | Скелет-лучник | 11–18 | Фрагмент древней кости ×1–2 — 37.5%; Охотничий лук ×1 — 1.2% |
| Old Cemetery | Могильный страж | 24–34 | Фрагмент древней кости ×2–4 — 50%; Доспех стража ×1 — 3%; Железный клинок ×1 — 4% |
| Fallen Shrine | Павший служитель | 12–19 | Осквернённая реликвия ×1 — 27.5%; Магическая пыль ×1 — 27.5%; Малое зелье ресурса ×1 — 10%; Рунный посох ×1 — 1.2% |
| Fallen Shrine | Страж святилища | 15–22 | Осквернённая реликвия ×1 — 32.5%; Шлем стража ×1 — 1.5%; Доспех стража ×1 — 1.5% |
| Ancient Approach | Древний страж | 16–24 | Осколок древнего камня ×1 — 32.5%; Магическая пыль ×1 — 30%; Доспех стража ×1 — 1.5% |
| Ancient Approach | Древний наблюдатель | 18–26 | Осколок древнего камня ×1 — 35%; Серебряный лунный талисман ×1 — 5% |
| Ancient Approach | Лунный страж | 45–65 | Осколок древнего камня ×2–4 — 50%; Магическая пыль ×3–5 — 50%; Железный клинок ×1 — 2%; Охотничий лук ×1 — 2%; Рунный посох ×1 — 2% |
| Ruins of Selene | Selene's Fallen Guardian | completion reward | На текущем M6 completion выдаёт каждому допустимому участнику: 900 XP, 450 Luna и Осквернённая реликвия ×1. Это deterministic completion reward, а не random loot roll. |

> Dungeon encounter mobs M6 пока не имеют самостоятельной обычной loot table: награда завязана на authoritative completion Ruins of Selene.

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
- Spider Hollow намеренно несоциальный и пассивный: пауки не агрятся первыми и не зовут соседей; опасность строится на высоком HP/M.Def, ядах и затяжном одиночном бою.
- Late-game зоны растянуты так, чтобы открытый мир заканчивался на LV14.
- LV15 зарезервирован под Ruins of Selene и Selene's Fallen Guardian.
- **Owner playtest 25.09.2026 — Selene's Fallen Guardian:** текущий вариант оставляем без срочного nerf/buff. Босс ощущается очень «жирным», но создаёт недостаточное давление на дистанционного Мистика: его можно стабильно kite-ить даже без полноценного шмота и зелий. На следующем mob-balance pass проверить прежде всего anti-kite pressure: скорость сближения, рывок/дальний punish, частоту и радиус AoE, а также окна безопасного sustain. До отдельного balance pass текущие цифры не менять.

## Balance workflow

После каждого runtime pass фиксируем не только субъективное «жирный / больно», но и:
- сколько секунд занимает убийство моба каждым архетипом;
- сколько HP / resource теряет игрок;
- сколько мобов безопасно тянется одновременно;
- насколько читаемо срабатывают special abilities;
- какой уровень игрока ожидается в зоне;
- не становится ли regen причиной бесконечного sustain.

