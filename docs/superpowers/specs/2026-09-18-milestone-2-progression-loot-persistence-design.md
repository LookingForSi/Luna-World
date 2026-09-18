# Luna World — Milestone 2: Progression, Loot & Persistence

Дата: 2026-09-18  
Статус: **Draft для обсуждения владельцем**  
Основание: `docs/ROADMAP.md`, `docs/GAME_DESIGN_V0.1.md`, принятый Milestone 1.

## 1. Цель Milestone 2

После Milestone 2 Luna World должен перестать быть набором боевых механик и получить первый законченный RPG-цикл:

`убил моба → получил XP/добычу → поднял уровень → стал сильнее → надел предмет → вышел → вернулся с тем же прогрессом`.

Milestone 2 должен реализовать:

- уровни 1–10;
- реальную XP-кривую;
- классовый рост характеристик;
- server-authoritative loot;
- ограниченный инвентарь;
- экипировку;
- перерасчёт характеристик;
- одну базовую валюту;
- persistent profile;
- DataVersion и migration framework;
- безопасный save/load;
- UI для уровня, опыта, инвентаря и экипировки.

Не входят в Milestone 2:

- PvP и расходование CP;
- party/shared loot rules;
- торговля между игроками;
- auction;
- crafting/enchanting;
- случайные affixes;
- durability;
- полноценный merchant/blacksmith UX;
- world-art loot bags как обязательный контракт;
- quests;
- полноценный production class-selection flow.

## 2. Основные продуктовые решения

### 2.1. Level cap

Максимальный уровень v0.1 остаётся **10**.

Игрок начинает на уровне 1.

После достижения 10 уровня XP больше не увеличивает level. UI показывает уровень 10 как cap.

### 2.2. XP хранится как progress внутри текущего уровня

Persistent profile хранит:

- `Level`;
- `XP` — XP внутри текущего уровня.

Это намеренно, а не cumulative lifetime XP.

Причины:

- легче сохранять уже достигнутый уровень при последующем tuning XP-кривой;
- UI естественно показывает `XP current / XP required`;
- не требуется перерасчёт всей истории XP при изменении балансных чисел.

### 2.3. Рабочая XP-кривая

Первая числовая кривая является tuning value, а не финальным балансом.

| Уровень | XP до следующего |
|---:|---:|
| 1 → 2 | 100 |
| 2 → 3 | 160 |
| 3 → 4 | 240 |
| 4 → 5 | 340 |
| 5 → 6 | 460 |
| 6 → 7 | 600 |
| 7 → 8 | 760 |
| 8 → 9 | 940 |
| 9 → 10 | 1 140 |

Итого до level 10: **4 740 XP**.

Текущие `Young Wolf = 15 XP` и `Grey Wolf = 25 XP` остаются рабочими значениями ранней зоны. Более сильные существа Milestone 4 будут давать больше XP.

Цель: первые уровни ощущаются быстро, а вся кривая допускает достижение cap примерно за 45–90 минут первого vertical-slice прохождения после появления полного набора существ/квестов.

### 2.4. Skill unlocks

Milestone 1 дал все умения сразу ради тестирования. В production progression Milestone 2:

- базовая атака доступна с level 1;
- skill 1 архетипа открывается на level 2;
- skill 2 — на level 4;
- skill 3 — на level 6.

Точная привязка:

**Рыцарь**
- level 2 — Мощный удар;
- level 4 — Удар щитом;
- level 6 — Защитная стойка.

**Следопыт**
- level 2 — Мощный выстрел;
- level 4 — Быстрый выстрел;
- level 6 — Западня.

**Мистик**
- level 2 — Магическая стрела;
- level 4 — Огненная вспышка;
- level 6 — Лечение.

В Studio допускается отдельный debug-seam для тестирования unlocks, но production client не может разблокировать умение сам.

### 2.5. Level-up и здоровье

Level-up:

- меняет level и derived stats;
- не является бесплатным full-heal;
- сохраняет процент текущего HP и классового ресурса при изменении maximum;
- не сбрасывает cooldowns;
- не сбрасывает активные боевые эффекты только ради level-up.

Это исключает exploit вида «экипировать/апнуть stat и бесплатно лечиться».

На respawn HP и классовый ресурс по-прежнему восстанавливаются полностью.

## 3. Характеристики и stat pipeline

### 3.1. Канонические характеристики Milestone 2

Derived player stats:

- Max HP;
- Max class resource;
- Resource regeneration;
- Physical Attack;
- Magic Attack;
- Physical Defense;
- Crit Chance;
- Attack Speed;
- Movement Speed.

CP остаётся отдельным PvP-ready слоем и не участвует в PvE расчётах Milestone 2.

### 3.2. Источники характеристик

Итоговое значение считается из трёх источников:

`Archetype base + Level growth + Equipment modifiers`.

Никакой клиент не присылает итоговые stats.

### 3.3. Рост по уровням

Числа ниже — стартовый tuning.

**Рыцарь, за каждый уровень после 1**
- Max HP: +10;
- Max STM: +3;
- Physical Attack: +2;
- Physical Defense: +1.5;
- Crit: +0.2 percentage points.

**Следопыт**
- Max HP: +7;
- Max FCS: +4;
- Physical Attack: +2;
- Physical Defense: +1;
- Crit: +0.35 percentage points.

**Мистик**
- Max HP: +6;
- Max MP: +6;
- Magic Attack: +2.5;
- Physical Defense: +0.75;
- Crit: +0.2 percentage points.

Movement Speed по level не растёт.

Attack Speed по level не растёт.

Эти параметры дополнительно меняются экипировкой.

### 3.4. Отдельный StatsService

Milestone 2 вводит небольшой `StatsService`, потому что derived combat stats зависят одновременно от progression и equipment.

Границы:

- `ProgressionService` владеет Level/XP;
- `InventoryService` владеет inventory/equipment;
- `StatsService` строит derived snapshot;
- `CombatService` потребляет готовый server-authoritative snapshot и не вычисляет progression/equipment самостоятельно.

Это убирает текущий временный источник stats из `CombatConfig.ArchetypeStats` как конечную истину. Базовые значения могут остаться в definitions/config, но их композиция выполняется централизованно.

## 4. Предметная модель

### 4.1. Stable definition ID и instance ID

Каждый тип предмета имеет стабильный `itemId`, например:

- `weapon_iron_blade`;
- `armor_worn_chest`;
- `material_wolf_pelt`.

Каждый реально принадлежащий игроку экземпляр имеет отдельный `instanceId`.

Это позволяет:

- иметь два одинаковых меча;
- однозначно экипировать конкретный экземпляр;
- не переделывать всю save schema, если позже появятся enchant/affixes.

### 4.2. Persistent ownership structure

Профиль хранит:

- `Items` — map `instanceId -> item record`;
- `Inventory` — ordered list instanceId;
- `Equipment` — map equipment slot -> instanceId или nil.

Один экземпляр находится либо в Inventory, либо в Equipment, но не одновременно.

Stackable item record может иметь `Quantity > 1`.

Equipment всегда `Quantity = 1`.

### 4.3. Категории

Минимум:

- Weapon;
- Armor;
- Accessory;
- Consumable;
- Material.

### 4.4. Редкость

v0.1:

- Common;
- Uncommon;
- Rare;
- Epic.

Rarity влияет на presentation и ожидаемую силу/частоту, но сама по себе не является формулой stats.

### 4.5. Equipment slots

- Weapon;
- Head;
- Chest;
- Gloves;
- Boots;
- Accessory.

### 4.6. Ограничения экипировки

Item definition может содержать:

- `requiredLevel`;
- допустимые архетипы;
- equipment slot;
- stat modifiers.

Weapon привязан к соответствующему архетипу.

Базовая броня Milestone 2 может быть общей для всех трёх архетипов, чтобы не умножать контент без игровой пользы.

### 4.7. Inventory capacity

Рабочий лимит: **40 inventory slots**.

Stackable materials/consumables занимают один slot на stack.

Рабочий stack limit: **99**.

Equipment не stackable.

Если inventory полон:

- сервер не создаёт предмет поверх capacity;
- игрок получает понятное сообщение в combat/system log;
- XP и Luna за убийство не теряются;
- предмет не конвертируется молча в валюту.

World-drop/overflow mailbox не входят в Milestone 2. Capacity 40 выбран так, чтобы ситуация была редкой в vertical slice, но поведение всё равно тестируется.

## 5. Стартовый item set

Цель v0.1 — 20–30 осмысленных предметов. Milestone 2 создаёт первый набор примерно из **25 definitions**.

### 5.1. Weapons — 9

Три tier на архетип:

**Knight**
- Training Sword — Common, level 1;
- Iron Blade — Uncommon, level 4;
- Moonsteel Sword — Rare, level 7.

**Ranger**
- Ash Bow — Common, level 1;
- Hunter Bow — Uncommon, level 4;
- Moonstring Bow — Rare, level 7.

**Mystic**
- Ash Staff — Common, level 1;
- Rune Staff — Uncommon, level 4;
- Moonveil Staff — Rare, level 7.

### 5.2. Shared armor/accessory — 10

Два tier для:

- Head;
- Chest;
- Gloves;
- Boots;
- Accessory.

Первый tier — Common/level 1.  
Второй tier — Uncommon/level 4.

### 5.3. Materials / consumables — 5

- Wolf Pelt;
- Sharp Fang;
- Spider Silk;
- Minor Healing Draught;
- Minor Resource Draught.

### 5.4. Epic reserve — 1

Один Epic definition может существовать в данных как reserved content для будущего boss/dungeon drop, но не должен выпадать из текущих волков.

Он не является обязательным playable reward Milestone 2.

Названия являются рабочими и могут быть заменены lore/content pass без изменения stable IDs после появления persistence. После первого публичного сохранения менять stable `itemId` без migration нельзя.

## 6. Item stat philosophy

В Milestone 2 предмет должен менять понятные цифры.

Разрешённые modifiers:

- Max HP;
- Max Resource;
- Physical Attack;
- Magic Attack;
- Physical Defense;
- Crit Chance;
- Attack Speed.

Movement Speed на equipment пока не используется: это слишком сильно влияет на kite/balance Следопыта и требует отдельного прохода.

Не вводятся:

- STR/DEX/CON/INT;
- elemental resistances;
- accuracy/evasion;
- random rolls;
- set bonuses;
- sockets;
- enchantment.

## 7. Loot

### 7.1. Server-authoritative roll

Loot roll выполняется только сервером после подтверждённой смерти mob.

Клиент:

- не сообщает, что выпало;
- не сообщает rarity;
- не сообщает количество;
- не может повторить старый kill request для повторной награды.

### 7.2. Kill eligibility до Party milestone

До Milestone 5 сохраняется текущая временная модель:

**last valid attacker получает XP и loot**.

Это явно временная модель и не считается финальным shared-credit design.

### 7.3. Loot table

Mob definition ссылается на стабильный `lootTableId`.

Loot table поддерживает:

- фиксированную/диапазонную Luna reward;
- независимые chance entries;
- item quantity range;
- rarity не вычисляется по chance — rarity принадлежит item definition.

Random source инъецируется в чистые rules для детерминированных тестов.

### 7.4. Доставка loot

В Milestone 2 item reward после server roll **сразу помещается в inventory**.

Combat log показывает:

- полученный XP;
- level-up;
- Luna;
- предмет и количество;
- отказ выдачи item из-за заполненного inventory.

Физический drop на земле можно добавить позже как presentation/interaction layer, не меняя server-authoritative reward contract.

## 8. Валюта Luna

Persistent profile содержит `Luna`.

Milestone 2:

- Luna может выпадать из PvE;
- значение сохраняется;
- UI inventory показывает баланс.

Траты у merchant/blacksmith относятся к Milestone 3.

Клиент не может прибавлять/списывать Luna напрямую.

## 9. Consumables

Чтобы доказать inventory operation `consume`, Milestone 2 содержит два простых consumable:

### Minor Healing Draught

- используется только живым игроком;
- восстанавливает фиксированное HP;
- не может поднять HP выше Max HP;
- не работает на мёртвом персонаже;
- stack уменьшается только после серверного принятия действия.

### Minor Resource Draught

То же для текущего классового ресурса.

Рабочий общий cooldown consumable: 5 секунд.

Consumable не может crit.

Consumable не действует на другого игрока.

## 10. Inventory / equipment UI

### 10.1. Открытие

Desktop: `I`.

Mobile/gamepad получают отдельное доступное действие через общий input abstraction; окончательная декоративная кнопка не должна раздувать HUD.

### 10.2. Layout

Один экран/панель:

- inventory grid/list;
- equipment slots;
- выбранный предмет;
- действия Equip / Unequip / Use / Discard;
- текущая Luna;
- capacity `used / 40`.

Drag-and-drop не обязателен.

Главная задача — понятность и одинаковый authoritative result на PC/gamepad/mobile.

### 10.3. XP HUD

Текущий status HUD сохраняет четыре строки:

- CP;
- HP;
- STM/FCS/MP;
- XP.

XP row становится реальным:

`LVL 4 · XP 125 / 340`.

Полоса заполняется по XP внутри текущего level.

На level 10 показывается:

`LVL 10 · MAX`.

## 11. Persistent profile schema v1

Первый persistent `DataVersion = 1`.

Концептуально:

```lua
{
    DataVersion = 1,
    Level = 1,
    XP = 0,
    Luna = 0,
    ArchetypeId = "knight",

    Items = {
        [instanceId] = {
            ItemId = "weapon_training_sword",
            Quantity = 1,
        },
    },

    Inventory = { instanceId1, instanceId2, ... },

    Equipment = {
        Weapon = nil,
        Head = nil,
        Chest = nil,
        Gloves = nil,
        Boots = nil,
        Accessory = nil,
    },
}
```

Не сохраняются:

- Roblox Instances;
- текущая target;
- cooldowns;
- active buffs/debuffs;
- текущий HP;
- текущий CP;
- текущий STM/FCS/MP;
- mob state;
- combat log.

### 11.1. ArchetypeId

Поле сохраняется сразу, хотя production character-selection flow будет доведён позже.

До появления выбора новый production profile получает `knight` как временный default.

Studio-only class switch не должен случайно переписывать production profile.

## 12. PlayerDataService

### 12.1. Ответственность

`PlayerDataService`:

- загружает profile;
- валидирует DataVersion;
- применяет migrations;
- держит session ownership;
- предоставляет server-only access/update API;
- autosave;
- save on leave;
- save/release during BindToClose;
- не содержит XP/loot/inventory business rules.

### 12.2. Profile lifecycle

Состояния минимум:

- Loading;
- Ready;
- Saving;
- Released;
- Error.

Gameplay mutation разрешена только для Ready profile.

Load failure **не создаёт пустой новый profile молча**.

После исчерпания bounded retries игрок не допускается в gameplay с фиктивным пустым save.

### 12.3. DataStore

Production использует Roblox `DataStoreService`.

Store name не кодирует game SemVer, потому что schema должна мигрировать внутри одного логического store.

Studio/dev environment использует отдельный namespace/store suffix, чтобы не портить production saves.

### 12.4. Session lease

Минимальная защита от одновременного владения одним profile:

- server генерирует session token;
- load через `UpdateAsync` атомарно захватывает lease;
- профиль хранит session owner/token и expiry/heartbeat;
- активный неистёкший lease другого server запрещает второй session;
- autosave обновляет lease;
- graceful release снимает lease;
- после crash lease истекает по времени.

Конкретные интервалы находятся в config.

Рабочий старт:

- autosave: 60 s;
- lease timeout: 300 s;
- bounded retry с коротким backoff.

Время и retry policy тестируются через инъецируемые seams, а не через реальные ожидания unit tests.

### 12.5. Migration framework

Milestone 2 вводит registry:

`DataVersion 1 -> future migrations`.

Поскольку это первая реальная persistent schema, historical production migration ещё отсутствует.

Обязательные тесты уже сейчас:

- default new profile;
- current v1 round-trip;
- invalid profile rejected;
- future DataVersion rejected safely;
- migration runner способен выполнять последовательные migration steps на synthetic old fixtures.

## 13. Архитектурные границы

Предлагаемая цепочка:

```text
MobService death
   ├─> ProgressionService.awardXP()
   └─> LootService.rollAndGrant()
             ├─> InventoryService
             └─> PlayerDataService (Luna / persistent mutation)

PlayerDataService
   ├─> ProgressionService reads/writes Level + XP
   ├─> InventoryService reads/writes Items/Inventory/Equipment
   └─> StatsService reads canonical profile-backed state

StatsService
   └─> CombatService consumes derived authoritative stats
```

Запрещённые зависимости:

- CombatService не сохраняет profiles;
- LootService не меняет combat state;
- client не мутирует profile;
- UI не является источником item ownership;
- item definitions не содержат per-player mutable state.

## 14. Remote contracts

Минимально:

- `InventoryActionRequest(action, instanceId)`;
- `InventorySnapshot` / server push;
- `InventoryActionResult`.

Разрешённые actions:

- Equip;
- Unequip;
- Consume;
- Discard.

Для Unequip вместо item instance допускается slot identifier, если это будет проще контракту.

Каждый request проверяет:

- точный type/argument count;
- известный action;
- длину/формат identifier;
- ownership;
- item exists;
- item location;
- required level;
- archetype restriction;
- slot compatibility;
- inventory capacity;
- alive/dead eligibility для consumable;
- request rate limit.

Никаких generic client-driven `SetInventory`, `SetXP`, `GrantItem`, `SetEquipment`.

## 15. Anti-duplication

Нужно защитить:

- один mob death → один XP award;
- один mob death → один loot roll;
- один loot result → один grant;
- один equip request → одна смена состояния;
- replay old instance/action не создаёт копию;
- save retry не применяет gameplay mutation повторно.

Persistent write сохраняет уже сформированное canonical state, а не повторно исполняет loot transaction.

## 16. Manual acceptance Milestone 2

### Progression

- level 1 получает XP;
- XP bar отражает current/required;
- level-up 1→2;
- несколько level-up одним большим reward работают корректно;
- skill unlock появляется на level 2/4/6;
- level 10 cap;
- relog сохраняет level/XP.

### Loot / inventory

- Wolf даёт server-generated loot;
- item появляется один раз;
- stackable складывается;
- non-stackable duplicate получает новый instance;
- inventory capacity соблюдается;
- full inventory не дублирует/не теряет XP/Luna;
- discard требует подтверждённое действие клиента и server validation.

### Equipment

- equip требует ownership;
- wrong archetype/level rejected;
- unequip возвращает item в inventory;
- full inventory блокирует unequip;
- stats меняются ровно один раз;
- combat damage после equip использует новые stats;
- relog восстанавливает equipment и derived stats.

### Consumables

- HP potion лечит;
- resource potion восстанавливает STM/FCS/MP;
- cooldown работает;
- item списывается один раз;
- мёртвый игрок не может use.

### Persistence

- leave/join round-trip;
- server shutdown path;
- load failure не превращается в пустой profile;
- concurrent active lease не создаёт две writable sessions;
- Studio/dev store изолирован от production.

### Multiplayer

`1 server + 2 clients`:

- профили игроков не смешиваются;
- loot одного не появляется у второго;
- equip одного не меняет stats второго;
- simultaneous mob interaction не выдаёт duplicate reward;
- leave во время save не ломает другого player.

## 17. Stabilization gate M2

Перед Milestone 3:

- full unit/integration suite;
- 1 server + 2 clients;
- DataStore failure-path review;
- migration review;
- item ID audit;
- inventory referential integrity audit;
- duplicate reward audit;
- lifecycle cleanup;
- remote abuse tests;
- no client-authoritative progression path;
- no silent profile reset;
- docs/schema/changelog sync.

## 18. Открытые owner-decisions

Документ и implementation plan можно готовить уже сейчас с рекомендуемыми defaults ниже. Перед gameplay implementation желательно зафиксировать только действительно продуктовые решения:

1. **Loot presentation**  
   Рекомендация M2: direct-to-inventory + combat log. Ground drops оставить presentation layer на Milestone 4.  
   Альтернатива: сразу physical ground drop.

2. **Inventory capacity**  
   Рекомендация: 40 slots. Это достаточно ограниченно, но не душит vertical slice.

3. **Skill unlock levels**  
   Рекомендация: 2 / 4 / 6.

4. **Level-up heal**  
   Рекомендация: не full-heal; сохранять процент HP/resource.

5. **Equipment individuality**  
   Рекомендация: instance IDs уже сейчас, даже без random affixes. Это немного сложнее, но сильно безопаснее для persistence и будущей эволюции.

Все остальные числа считаются tuning values и не требуют отдельного owner approval перед началом реализации после утверждения общей спецификации.
