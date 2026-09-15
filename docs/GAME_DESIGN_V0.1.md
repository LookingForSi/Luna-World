# Luna World — Game Design v0.1

## 1. Формат релиза

`v0.1` — **Vertical Slice**, а не tech demo и не mini-MMO.

Цель: дать новому игроку законченный игровой опыт продолжительностью примерно 45–90 минут и проверить, работает ли ядро Luna World как RPG.

## 2. Маршрут игрока

Основной маршрут:

`Luna Village → Moonfall Valley → Ruins of Selene`

Игрок должен пройти цикл:

1. создать / выбрать архетип персонажа;
2. появиться в Luna Village;
3. получить первый квест;
4. выйти в Moonfall Valley;
5. выбрать цель и победить первого моба;
6. получить XP и первый level-up;
7. открыть / использовать skill;
8. получить loot;
9. надеть предмет и почувствовать прирост силы;
10. углубиться в регион;
11. победить elite/miniboss;
12. при желании объединиться с другими игроками;
13. получить доступ к Ruins of Selene;
14. пройти короткий dungeon;
15. победить финального boss;
16. выйти из игры и при следующем входе продолжить с сохранённым прогрессом.

## 3. Мир v0.1

### 3.1. Luna Village

Безопасная стартовая деревня.

Назначение:

- spawn / respawn;
- стартовые NPC;
- основные quests;
- merchant;
- blacksmith / equipment interaction;
- training target;
- визуальное знакомство с миром;
- дорога в Moonfall Valley.

PvP отсутствует.

Деревня должна выглядеть как реальное место мира, а не lobby с набором кнопок.

### 3.2. Moonfall Valley

Общая multiplayer PvE-зона уровней 1–10.

Регион должен иметь несколько визуально различимых участков, но оставаться одной компактной зоной:

- безопасная окраина возле деревни;
- открытая дорога / поляна;
- лесной участок;
- более опасная дальняя часть;
- руины / вход к dungeon;
- место open-world elite/miniboss.

Рабочие типы противников:

- Wolf;
- Spider;
- Goblin Scout;
- Goblin Warrior;
- Skeleton;
- Skeleton Archer;
- один или два более сильных варианта для дальней части зоны.

Точные названия и визуальные варианты могут уточняться в content pass, но количество контента следует удерживать в границах vertical slice.

### 3.3. Ruins of Selene

Короткий instanced dungeon для 1–4 игроков.

Ориентировочная длительность: 8–15 минут.

Структура:

`Entrance → mobs → encounter / miniboss → mobs → final boss`

Финальный boss (рабочее название: **Selene's Fallen Guardian**) должен иметь минимум три читаемых состояния / механики:

- обычная базовая атака;
- telegraphed AoE;
- усиление / enrage на низком HP.

Dungeon не должен превращаться в raid design. Его задача — завершить vertical slice и проверить party PvE и boss mechanics.

## 4. Архетипы персонажей

В v0.1 — три архетипа. Полноценные class advancement trees не входят в scope.

### Knight

Роль: устойчивый melee.

Базовый набор:

- базовая melee-атака;
- Power Strike;
- Shield Bash;
- Defensive Stance.

### Ranger

Роль: ranged physical DPS.

Базовый набор:

- базовая ranged-атака;
- Power Shot;
- Rapid Shot;
- Snare.

### Mystic

Роль: magic damage + ограниченная поддержка.

Базовый набор:

- magic basic attack / cast;
- Arcane Bolt;
- Flame Burst;
- Heal.

Названия skills рабочие. До lore/content pass они не считаются финальными.

## 5. Управление и боевая модель

### 5.1. Перемещение

Современное управление:

- PC: WASD + mouse camera;
- gamepad: стандартное character movement;
- mobile: virtual stick + touch controls.

Click-to-move не является основной моделью управления v0.1.

### 5.2. Target-based combat

Бой сохраняет old-school MMORPG-подход:

1. игрок выбирает target;
2. UI показывает target frame;
3. каждое нажатие Attack запрашивает одну базовую атаку в ритме `удар → cooldown → удар`;
4. skills применяются к выбранной цели;
5. учитываются range, cooldown и ресурс;
6. персонаж доворачивается к цели;
7. сервер подтверждает действие и рассчитывает результат.

Игрок свободно управляет перемещением во время боя.

Cooldown базовой атаки является server-authoritative. Короткий input buffer перед его окончанием помогает следующему ручному нажатию сработать отзывчиво, но не позволяет клиенту ускорять cadence.

В PvE допускается отдельный optional autoattack как convenience-режим поверх того же server combat pipeline. Ручные атаки остаются основным режимом. PvP не входит в v0.1; будущий PvP-контракт не допускает autoattack и требует отдельного ручного input на каждую базовую атаку.

Обычный свободный jump не нужен: мир проектируется для наземного перемещения по дорогам, склонам и лестницам. Возможные contextual traversal actions относятся к отдельной будущей системе. На mobile стандартная Jump button должна быть убрана, а основной правой action становится крупная собственная Attack button.

### 5.3. Серверная модель

Сервер рассчитывает и подтверждает:

- допустимость цели;
- дистанцию;
- cooldown;
- стоимость skill;
- damage / healing;
- crit;
- death;
- XP;
- drop;
- quest credit.

Клиент отвечает за input, camera, локальные UI/FX и отправку намерения выполнить действие.

## 6. Progression

Максимальный уровень v0.1: **10**.

Целевой темп:

- первые уровни получаются быстро;
- level 1–5 знакомит с базовыми системами;
- level 5–8 ведёт глубже в Moonfall Valley;
- level 8–10 подводит к elite и Ruins of Selene.

Ориентир для достижения level cap: примерно 45–90 минут обычного первого прохождения, без требования идеальной эффективности.

Основные параметры персонажа:

- Level;
- XP;
- HP;
- MP / resource;
- Physical Attack;
- Magic Attack;
- Physical Defense;
- Movement Speed.

Допустимые вторичные параметры v0.1:

- Crit;
- Attack Speed.

Сложные stat systems и ручное распределение STR/DEX/CON/INT и аналогов в v0.1 не требуются.

## 7. Loot и equipment

Loot — одна из ключевых систем эмоционального вознаграждения.

Редкости v0.1:

- Common;
- Uncommon;
- Rare;
- Epic.

Equipment slots:

- Weapon;
- Head;
- Chest;
- Gloves;
- Boots;
- Accessory.

Цель — примерно 20–30 осмысленных предметов, а не сотни почти одинаковых.

Предмет более высокой ценности должен по возможности:

- заметно менять характеристики;
- визуально отражаться на персонаже;
- быть понятен игроку без сложной математики.

Редкий drop должен оставаться редким событием и не заменяться постоянным потоком всплывающих наград.

## 8. Inventory и currency

Inventory v0.1: простой ограниченный инвентарь.

Базовые операции:

- inspect;
- equip;
- unequip;
- consume;
- discard (с подтверждением для ценных предметов, если будет реализовано).

Одна базовая игровая валюта: **Luna** (рабочее название, может быть изменено lore pass).

Валюта получается из PvE/quests и тратится на базовые consumables / starter equipment.

## 9. Quests

Квестов должно быть немного, они направляют игрока по core loop.

Ориентир v0.1: 5–10 коротких quests.

Пример цепочки:

- знакомство с Luna Village;
- первые Wolves;
- угроза Goblins;
- elite encounter;
- путь к Ruins of Selene;
- завершение dungeon.

Длинные текстовые диалоги и сложная branching narrative не входят в v0.1.

## 10. Mob AI

Базовая state machine:

`Idle → Aggro → Chase → Attack → Return → Idle`

Обязательные параметры:

- spawn point;
- aggro radius;
- attack range;
- leash distance;
- move speed;
- attack interval;
- respawn timer.

Mob не должен бесконечно преследовать игрока через весь регион.

## 11. Death

Для v0.1 смерть мягкая:

- respawn в Luna Village / определённой safe point;
- без потери level;
- без потери equipment;
- без потери currency.

Жёсткие death penalties могут рассматриваться позднее.

## 12. Multiplayer и party

Целевой размер обычного сервера v0.1: ориентировочно 10–20 игроков, точное значение подтверждается performance tests.

Игроки в общей зоне должны видеть согласованное состояние mobs и боёв.

Party:

- до 4 игроков;
- invite / leave;
- общий kill credit для допустимых участников;
- правила XP/drop должны быть простыми и предсказуемыми.

Сложный matchmaking не требуется.

## 13. Persistence

После перезахода должны сохраняться минимум:

- class/archetype;
- level;
- XP;
- currency;
- inventory;
- equipped items;
- unlocked skills;
- quest progress / completion.

Persistent schema имеет отдельный `DataVersion` и migration strategy.

## 14. UI

Основные элементы:

- player HP/MP/XP;
- target frame;
- skill/action bar;
- quest tracker;
- inventory;
- character/equipment panel;
- минимальное party UI.

Интерфейс должен работать как на desktop, так и на mobile без механического уменьшения desktop layout.

## 15. Что сознательно исключено из v0.1

- PvP;
- clans;
- castle sieges;
- auction house;
- player trading;
- crafting;
- enchantment;
- mounts;
- pets;
- housing;
- large raids;
- battle pass;
- monetization shop;
- сложная экономика;
- десятки регионов и классов.

## 16. Definition of Done v0.1

v0.1 считается продуктово законченной, если новый игрок без помощи разработчика способен:

1. войти в игру;
2. понять базовое управление;
3. выбрать / получить архетип;
4. взять первый quest;
5. выбрать mob target;
6. победить mob;
7. получить XP и level;
8. использовать skill;
9. получить и надеть loot;
10. пройти progression Moonfall Valley;
11. взаимодействовать с другим игроком / party;
12. попасть в Ruins of Selene;
13. победить dungeon boss;
14. выйти;
15. зайти повторно;
16. увидеть корректно восстановленный прогресс.

Техническая готовность дополнительно требует прохождения тестов из `TESTING_STRATEGY.md`.
