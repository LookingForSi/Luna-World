# Luna World — Crafting World Pass v0.2

## Зачем

Текущий крафт технически работает, но не образует игровой цикл:

- у кузнеца один общий список, визуально похожий на набор рыцарских рецептов;
- у Следопыта и Мистика нет собственных наборов брони;
- часть No-Grade рецептов требует материалов из слишком поздних зон (например, базовый посох требует Fallen Relic), поэтому персонаж LV6 доходит до кузнеца с полным инвентарём и почти ничего не может изготовить;
- сырьё почти не проходит через промежуточную обработку, поэтому материалы ощущаются как несвязанный loot;
- торговец продаёт готовую No-Grade экипировку и переработанные материалы, обесценивая кузнеца;
- список рецептов не объясняет игроку, что именно он уже может сделать и чего ему не хватает.

Цель pass: сделать кузнеца основным No-Grade progression loop и связать добычу волков, пауков и гоблинов в понятные цепочки «сырьё → обработанный материал → вещь».

## Scope

В этой задаче Codex должен целиком реализовать именно мир крафта:

1. четыре раздела кузнеца;
2. метаданные рецептов и level gating;
3. промежуточные материалы;
4. отдельные No-Grade наборы Рыцаря / Следопыта / Мистика;
5. переработанные рецепты оружия;
6. согласование merchant stock / loot / экономики;
7. UI кузнеца;
8. unit/static/balance tests и документацию.

Вне scope этой задачи:

- двухпанельная массовая продажа торговцу;
- исправление стартового оружия при Studio-переключении класса;
- новые профессии, рецепты-дропы, enchant, affixes, durability, crafting skill;
- Grade выше NoGrade.

Эти пункты ведутся отдельно.

---

## 1. Игровая модель

### 1.1. Четыре темы в диалоге кузнеца

Вместо одного пункта **«Ковать»** диалог кузнеца должен предлагать:

- **Ковать — Рыцарь**
- **Ковать — Следопыт**
- **Ковать — Мистик**
- **Обработать материалы**

Класс персонажа НЕ скрывает остальные вкладки: игрок может посмотреть все рецепты. Ограничение применения оружия остаётся authoritative через `allowedArchetypes`.

### 1.2. Принцип прогрессии

К моменту LV6 игрок, прошедший естественный маршрут через волков → пауков → гоблинов, должен иметь возможность изготовить минимум:

- оружие своего класса;
- минимум 1–2 предмета брони своего класса;

без материалов Old Cemetery / Fallen Shrine / Ancient Approach.

Ни один базовый No-Grade рецепт LV4–6 не должен требовать:

- `material_fallen_relic`
- `material_ancient_shard`
- `material_dire_hide`

Поздние материалы сохраняются для дальнейшего расширения, но не блокируют первый комплект.

---

## 2. Расширить модель CraftDefinition

Текущий `CraftDefinition` недостаточен. Добавить минимум:

```luau
export type CraftDiscipline = "Knight" | "Ranger" | "Mystic" | "Material"

export type CraftDefinition = {
    id: string,
    displayName: string?,
    discipline: CraftDiscipline,
    requiredLevel: number,
    outputItemId: string,
    outputQuantity: number,
    fee: number,
    sortOrder: number,
    ingredients: { Ingredient },
}
```

Требования:

- `outputQuantity` нужен для переработки сырья;
- `requiredLevel` проверяется сервером, а не только UI;
- при недостаточном уровне вернуть `LevelTooLow`;
- snapshot кузнеца должен передавать metadata или ссылку на stable recipe id, чтобы client не вычислял authority;
- сортировка стабильная: `discipline → sortOrder → craftId`.

---

## 3. Материальные цепочки

Сохранить существующие stable IDs, где они уже есть. Добавить новые stable IDs без переименования существующих persistence IDs.

### 3.1. Сырьё из мобов

| Источник | Сырьё |
|---|---|
| Wolves | Волчья шкура, Острый клык |
| Spiders | Паучий шёлк, Ядовитая железа |
| Goblins | Железный лом, Гоблинский жетон |
| Goblin Shaman | Магическая пыль |
| Later zones | Dire Hide / Bone / Fallen Relic / Ancient Shard — пока для дальнейшего progression |

### 3.2. Обработанные материалы

Добавить:

| Stable ID | Имя | Рецепт | Output | LV | Fee |
|---|---|---:|---:|---:|---:|
| existing `material_cured_leather` | Выделанная кожа | Волчья шкура ×3 | ×3 | 2 | 4 |
| `material_sturdy_thread` | Прочная нить | Паучий шёлк ×3 | ×3 | 4 | 4 |
| `material_iron_billet` | Железная заготовка | Железный лом ×2 + Гоблинский жетон ×1 | ×2 | 4 | 8 |
| `material_arcane_thread` | Зачарованная нить | Прочная нить ×2 + Магическая пыль ×2 | ×1 | 6 | 10 |

Это создаёт цепочки длиной 1–2 переработки:

- Wolf Pelt → Cured Leather → armor
- Spider Silk → Sturdy Thread → Ranger/Mystic gear
- Spider Silk → Sturdy Thread → Arcane Thread → Mystic gear
- Iron Scrap + Goblin Token → Iron Billet → Knight weapons/armor and weapon fittings

Processed materials не должны быть обязательным прямым drop обычных мобов. Если оставить bonus-drop у elite/late mob, он должен быть редким и восприниматься как экономия одного шага.

---


### 3.3. Контрольный маршрут до LV6

Balance acceptance должен моделировать реальный квестовый путь, а не поздний фарм: 4 Young Wolves, 4 Grey Wolves + Pack Leader, 4 Goblin Scouts + 1 Warrior, 4 Spiders + 1 Brood Spider и 1 Goblin Shaman как естественный добор последних XP до LV6. Вместе с наградами Q2–Q5 этого достаточно для достижения LV6. Именно на этом маршруте ожидаемых ресурсов должно хватать на оружие и минимум одну часть брони каждого класса.

Goblin Shaman является единственным ранним тематическим источником Magic Dust, поэтому его signature-drop не должен требовать многократного фарма одного spawn только ради первого Mystic-рецепта.

## 4. Классовая экипировка

### 4.1. Рыцарь

Сохранить существующие stable IDs:

- `weapon_iron_blade`
- `armor_guard_head`
- `armor_guard_chest`
- `armor_guard_gloves`
- `armor_guard_boots`

Рецепты:

| Предмет | LV | Материалы | Fee |
|---|---:|---|---:|
| Железный клинок | 4 | Iron Billet ×1 + Sharp Fang ×1 | 30 |
| Шлем стража | 4 | Iron Billet ×1 + Cured Leather ×1 | 18 |
| Доспех стража | 5 | Iron Billet ×2 + Cured Leather ×3 | 35 |
| Перчатки стража | 4 | Iron Billet ×1 + Cured Leather ×1 + Sturdy Thread ×1 | 16 |
| Сапоги стража | 4 | Iron Billet ×1 + Cured Leather ×2 | 16 |

Текущие stats можно сохранить в первом проходе.

### 4.2. Следопыт

Сохранить `weapon_hunter_bow`. Добавить:

- `armor_hunter_head` — Капюшон охотника
- `armor_hunter_chest` — Куртка охотника
- `armor_hunter_gloves` — Перчатки охотника
- `armor_hunter_boots` — Сапоги охотника

Базовый stat profile:

- Head: `physicalDefense +2`, `maxResource +8`
- Chest: `physicalDefense +5`, `maxHealth +12`
- Gloves: `physicalDefense +1`, `criticalChance +0.01`
- Boots: `physicalDefense +1`, `attackSpeedMultiplier +0.03`

Рецепты:

| Предмет | LV | Материалы | Fee |
|---|---:|---|---:|
| Охотничий лук | 4 | Iron Billet ×1 + Sturdy Thread ×2 + Cured Leather ×1 + Sharp Fang ×1 | 30 |
| Капюшон охотника | 4 | Cured Leather ×2 + Sturdy Thread ×1 | 18 |
| Куртка охотника | 5 | Cured Leather ×3 + Sturdy Thread ×2 | 32 |
| Перчатки охотника | 4 | Cured Leather ×2 + Sturdy Thread ×2 + Sharp Fang ×1 | 18 |
| Сапоги охотника | 4 | Cured Leather ×2 + Sturdy Thread ×1 | 16 |

### 4.3. Мистик

Сохранить `weapon_rune_staff`. Добавить:

- `armor_adept_head` — Капюшон адепта
- `armor_adept_chest` — Роба адепта
- `armor_adept_gloves` — Перчатки адепта
- `armor_adept_boots` — Сапоги адепта

Базовый stat profile:

- Head: `physicalDefense +1`, `maxResource +12`
- Chest: `physicalDefense +3`, `maxHealth +8`, `maxResource +10`
- Gloves: `physicalDefense +1`, `magicAttack +1`, `criticalChance +0.005`
- Boots: `physicalDefense +1`, `maxResource +8`

Рецепты:

| Предмет | LV | Материалы | Fee |
|---|---:|---|---:|
| Рунный посох | 6 | Iron Billet ×1 + Magic Dust ×1 + Sturdy Thread ×2 | 30 |
| Капюшон адепта | 5 | Cured Leather ×1 + Sturdy Thread ×1 | 18 |
| Роба адепта | 6 | Cured Leather ×2 + Sturdy Thread ×3 + Magic Dust ×2 | 32 |
| Перчатки адепта | 6 | Cured Leather ×1 + Arcane Thread ×1 + Magic Dust ×1 | 18 |
| Сапоги адепта | 5 | Cured Leather ×1 + Sturdy Thread ×2 + Magic Dust ×1 | 16 |

### 4.4. Общий аксессуар

`accessory_silver_moon_charm` остаётся общим No-Grade аксессуаром. Его можно показывать в каждой классовой вкладке как common recipe либо добавить внизу всех трёх списков.

Он НЕ должен требовать Ancient Shard / Fallen Relic на раннем уровне. Для текущего pass:

- Required LV6
- Magic Dust ×3
- Arcane Thread ×1
- Venom Sac ×1
- Fee 25

---

## 5. Merchant / loot integration

Кузнец должен быть главным источником готовой No-Grade экипировки.

Из `MerchantDefinitions.Stock` убрать:

- `weapon_iron_blade`
- `weapon_hunter_bow`
- `weapon_rune_staff`
- все No-Grade armor pieces;
- processed materials: Cured Leather, Sturdy Thread, Iron Billet, Arcane Thread.

Торговец в этом pass продаёт прежде всего consumables / return scroll. Если оставить продажу raw materials как catch-up, она должна быть дорогой и не выгоднее фарма + кузнеца.

Ready-made gear может продолжать редко выпадать как jackpot drop, но не должно заменять основной crafting loop.

Сохранить anti-arbitrage invariant:

`buyback(output) < cost(raw inputs at reference value) + fee`.

---

## 6. UI кузнеца

### DialogueBlacksmith

Четыре кнопки вместо одной.

### Craft screen

Для каждого recipe показывать:

- имя результата;
- grade;
- required LV;
- ключевые stats;
- fee;
- каждое сырьё в формате `имя have/need`;
- output quantity для material recipes;
- визуальное состояние:
  - доступно;
  - недостаточный LV;
  - не хватает Luna;
  - не хватает материалов.

Недоступный рецепт не должен выглядеть кликабельным.

Вкладка Materials должна визуально объяснять конверсию, например:

`Волчья шкура ×3 → Выделанная кожа ×2 · 4 Luna`.

После успешного craft snapshot обновляется и все have/need пересчитываются.

---

## 7. Economy / progression acceptance

Нужны автоматические checks, а не только ручная настройка.

### Обязательные invariants

1. Все recipe IDs уникальны.
2. Все ingredient/output item IDs существуют.
3. Все recipe outputs текущего pass имеют grade NoGrade либо category Material.
4. Material recipe может output >1.
5. Server проверяет requiredLevel.
6. Ни один LV≤6 gear recipe не зависит от material, который естественно начинается позже LV6.
7. Для каждого класса есть:
   - 1 No-Grade weapon;
   - Head;
   - Chest;
   - Gloves;
   - Boots.
8. Полный ранний набор одного класса не должен быть >15% дороже другого по expected route value.
9. На естественном маршруте к LV6 ожидаемых ресурсов достаточно минимум для weapon + one armor piece выбранного класса.
10. Merchant не продаёт готовый class No-Grade set.
11. Нельзя получить прибыль циклом merchant buy → craft → merchant sell.
12. Старые persistence stable IDs не переименовывать.

### Tests

Обновить / добавить:

- `EconomyRulesSpec.luau`
- `ItemDefinitionsSpec.luau`
- `DefinitionValidationSpec.luau`
- `check_loot_craft_economy_contract.py`
- новый focused contract для class crafting tabs / material conversion / level gating;
- `EconomyBalance` route simulations для Knight / Ranger / Mystic.

---

## 8. Definition of Done

Задача считается готовой, если в Studio можно пройти следующий сценарий:

1. Следопыт LV6 приходит к кузнецу.
2. Видит четыре темы кузнеца.
3. Открывает «Обработать материалы».
4. Из накопленных Wolf Pelt / Spider Silk / Goblin loot делает Cured Leather / Sturdy Thread / Iron Billet.
5. Переходит в «Ковать — Следопыт».
6. Может изготовить минимум Охотничий лук и одну часть Hunter set без Fallen/Ancient материалов.
7. Мистик LV6 аналогично может изготовить Rune Staff и хотя бы одну часть Adept set.
8. Рыцарь имеет эквивалентный путь.
9. Готовая экипировка не покупается напрямую у торговца.
10. Все authoritative tests и static contracts проходят.

## Не делать

- не вводить второй inventory;
- не добавлять профессии;
- не делать случайные affixes;
- не создавать Grade D/C/B/A/S;
- не менять stable IDs существующих предметов;
- не прятать рецепты других классов;
- не решать баланс увеличением drop rate в несколько раз: сначала использовать переработку как sink для накопленного сырья.
