# Luna World — Architecture

## 1. Цель архитектуры

Архитектура v0.1 должна поддерживать vertical slice без преждевременного усложнения, но не создавать тупиков для multiplayer, persistence и дальнейшего роста.

Главный принцип: **server authoritative gameplay**.

## 2. Toolchain

Рабочий контур:

- Roblox Studio — world authoring, runtime, multiplayer testing;
- Luau — игровой код;
- Git / GitHub — source of truth для кода и документации;
- VS Code — основной редактор исходников;
- Rokit — версии dev-tools;
- Rojo — синхронизация файловой структуры с Roblox Studio;
- Luau Language Server — типы, diagnostics, navigation.

## 3. Планируемая файловая структура

```text
Luna-World/
├─ src/
│  ├─ client/
│  │  ├─ controllers/
│  │  └─ ui/
│  ├─ server/
│  │  ├─ services/
│  │  └─ systems/
│  └─ shared/
│     ├─ config/
│     ├─ definitions/
│     ├─ types/
│     └─ util/
├─ tests/
├─ docs/
├─ default.project.json
├─ rokit.toml
├─ README.md
└─ AGENTS.md
```

Фактическая детализация каталогов создаётся по мере появления кода. Пустые абстрактные слои заранее не добавляются.

## 4. Rojo mapping

Предполагаемая логика:

```text
src/shared  -> ReplicatedStorage/Shared
src/server  -> ServerScriptService/Server
src/client  -> StarterPlayer/StarterPlayerScripts/Client
```

UI может быть организован через Rojo отдельно после выбора конкретного подхода.

## 5. Что является source of truth

### В Git

- Luau-код;
- конфигурация;
- definitions;
- тесты;
- документация;
- toolchain config;
- Rojo mapping.

### В Roblox Studio

На ранней стадии v0.1 допускается authoring:

- Terrain;
- world geometry;
- Lighting;
- placement environment assets;
- animation / asset references;
- scene composition.

Не следует поддерживать две независимые версии одного script одновременно в Studio и Git. Rojo-managed source в Git является authoritative.

## 6. Основные подсистемы v0.1

### Shared definitions

Данные, которые допустимо видеть клиенту:

- item definitions;
- mob presentation definitions;
- skill presentation/config subset;
- quest display definitions;
- class display definitions;
- shared types.

Секретная или exploitable серверная логика не должна попадать сюда без необходимости.

### PlayerDataService

Ответственность:

- загрузка профиля;
- default schema;
- DataVersion;
- migrations;
- безопасное сохранение;
- session lifecycle.

Не должен содержать combat/business logic других систем.

### CombatService

Ответственность:

- target/action validation;
- skill eligibility;
- range checks;
- cooldowns;
- damage/healing calculation;
- death notification.

CombatService не выдаёт loot напрямую — он сообщает о валидном результате соответствующим системам.

### MobService / AI system

Ответственность:

- spawn/respawn;
- state machine;
- aggro;
- chase/leash;
- attacks;
- death lifecycle.

### ProgressionService

Ответственность:

- XP;
- level-up;
- stat progression;
- skill unlock conditions.

### InventoryService

Ответственность:

- add/remove items;
- stack rules;
- capacity;
- equip/unequip validation;
- item ownership.

### LootService

Ответственность:

- loot tables;
- server-side rolls;
- reward creation;
- eligibility.

### QuestService

Ответственность:

- quest state;
- objective credit;
- completion validation;
- rewards through authoritative services.

### PartyService

Ответственность:

- invite/accept/leave;
- party membership;
- eligibility helpers for shared XP/credit.

### DungeonService

Ответственность:

- dungeon session lifecycle;
- party entry;
- encounter state;
- completion/reward eligibility.

Не проектировать общий MMO orchestration layer до реальной необходимости.

## 7. Client responsibilities

Клиент отвечает за:

- input;
- camera;
- target selection intent;
- HUD;
- inventory/character presentation;
- local animation/FX feedback;
- отправку action requests;
- отображение подтверждённого сервером состояния.

Клиент не определяет authoritative damage, XP, loot, currency или quest completion.

## 8. Remote contract

Каждый remote request должен иметь:

- минимальный набор аргументов;
- server-side type/shape validation;
- ownership / eligibility validation;
- range/state validation, если применимо;
- rate limiting или anti-spam protection там, где это необходимо.

Предпочтительно отправлять intent, а не готовый результат.

Плохо:

```text
DealDamage(targetId, 5000)
```

Лучше:

```text
UseSkill(skillId, targetId)
```

Сервер сам вычисляет результат.

## 9. IDs и definitions

Persistent entities используют стабильные IDs, например:

```text
weapon_rusty_sword
mob_grey_wolf
skill_knight_power_strike
quest_valley_wolves_01
```

DisplayName не является persistent identifier.

## 10. Persistence schema

Пример концептуальной структуры:

```text
PlayerData
├─ DataVersion
├─ Archetype
├─ Level
├─ XP
├─ Currency
├─ Inventory
├─ Equipment
├─ Skills
└─ Quests
```

Реальная Luau schema определяется при реализации persistence milestone.

## 11. Ошибки и восстановление

Gameplay request с некорректными данными:

- не должен падать весь server script;
- отклоняется сервером;
- логируется при необходимости;
- не изменяет authoritative state.

Persistence failure:

- нельзя молча заменять существующий профиль пустым;
- ошибка должна быть различима от «новый игрок»;
- destructive fallback без явной стратегии запрещён.

## 12. Производительность

v0.1 проектируется для небольшого server population и ограниченного контента, но базовые правила действуют сразу:

- избегать per-frame server loops без необходимости;
- не сканировать весь Workspace для каждого combat action;
- не создавать бесконтрольные connections/tasks;
- cleanup должен быть частью lifecycle объектов;
- AI tick frequency должна соответствовать задаче, а не обязательно Heartbeat.

Конкретные performance budgets вводятся после появления репрезентативного vertical slice.

## 13. YAGNI

Не добавлять заранее:

- microservices;
- внешний backend;
- PostgreSQL;
- Redis;
- custom auth;
- cross-game economy;
- generic ECS/framework только ради архитектурной красоты.

Roblox platform services используются до тех пор, пока реальное ограничение не требует внешней системы.

## 14. Деревенская экономика v0.1

`CraftingDefinitions`, `MerchantDefinitions` и `ItemDefinitions` являются единственным shared источником рецептов, stock, grade и reference retail. `EconomyRules` выполняет чистые clone-based buy/sell/craft переходы, а `EconomyService` применяет готовый результат одной validated mutation профиля. Клиент никогда не передаёт цену, fee, состав рецепта или output.

Рецепт дополнительно задаёт stable `id`, дисциплину (`Knight`, `Ranger`, `Mystic`, `Material`), требуемый уровень, количество результата и стабильный порядок. `EconomyRules` проверяет уровень, Luna и материалы на сервере и атомарно выдаёт `outputQuantity`; snapshot передаёт эти metadata клиенту. Обработанные материалы и готовые No-Grade классовые наборы исключены из обычного stock торговца: их основной источник — кузнец.

`EconomyNetworkService` владеет schema/rate/profile/distance validation для `EconomyRequest`; `EconomyWorldService` владеет только lifecycle village prompts. `InventoryService` обрабатывает data-driven return effect через тот же tagged settlement anchor, что и respawn.

## 15. Quest vertical slice dev0.2

`QuestDefinitions` и `QuestRules` задают Q1–Q7 и чистые переходы состояния. `QuestService` потребляет только authoritative `MobService.MobDied`, проверяет talk/proximity и ReachLocation на сервере и применяет reward вместе с `Completed` одной profile mutation. Клиент получает display snapshot для dialogue, tracker, карты, waypoint и NPC markers, но не может отправить objective progress или reward. Persistent schema использует `DataVersion = 2`; migration v1→v2 добавляет изолированную таблицу `Quests` без изменения данных dev0.1.

## Account → Characters → Active Character (dev0.3)

Persistent запись пользователя теперь является `AccountProfile` версии 3. Она содержит порядок и словарь не более чем из `CharacterConfig.CharacterSlotLimit` персонажей, account-настройки и последний выбранный идентификатор. Каждый `CharacterProfile` владеет собственными progression, Luna, inventory, equipment и quests. Migration `v2 → v3` сохраняет прежний профиль внутри legacy-персонажа; до задания nickname и типа тела такой персонаж не может войти в мир.

Сессия имеет два явных рубежа. `AccountReady` разрешает только работу roster/lobby API. `CharacterReady` появляется после проверки принадлежности `CharacterId`, назначает активный профиль и только затем разрешает spawn и gameplay services. Совместимое событие `ProfileReady` означает именно `CharacterReady`.

Character API принимает только узкие команды roster/check/create/select/delete, применяет rate limit и возвращает DTO без inventory, quest state и иных изменяемых authoritative структур. Nickname нормализуется pure-правилами, проходит Roblox TextService filtering и резервируется в отдельном индексе через атомарный `UpdateAsync`. При неудачном создании reservation откатывается; при удалении имя освобождается только после успешной записи account.

## 16. Multi-Place runtime и authored Moonfall (Gates A–E)

Experience разделяется на роли `Lobby`, `World`, `Dungeon` и Studio-only `DevCombined`. Роль определяется через fail-closed `PlaceRuntime`; production Place без явного deployment mapping не запускает все подсистемы как fallback. Server/client entrypoints выбирают role-specific manifests, а `RuntimeManifest` владеет ordered startup, rollback и cleanup.

Переход Lobby → Moonfall выполняется server-authoritative transfer lifecycle. Source сохраняет и освобождает profile lease, создаёт одноразовый transfer intent в `MemoryStoreService` и передаёт через `TeleportData` только routing/correlation metadata. Destination сначала валидирует routing shape, claim-ит authoritative profile, атомарно consume-ит intent, проверяет ownership/destination и только затем активирует character. Inventory, Luna, XP, equipment, quests и другие authoritative данные через `TeleportData` не передаются.

Production Moonfall после Gate E считается **authored Place**, а не runtime-generated world:

- `projects/moonfall.project.json` не маппит `tools/worldgen`;
- production `src/server/world` содержит только gameplay/runtime helpers, а blockout generator вынесен в `tools/worldgen`;
- `MoonfallWorldRuntime` принимает только root с `ManagedBy=MoonfallAuthoredWorld`, совпадающим terrain revision и обязательным `LunaVillageSpawn`;
- `MoonfallWorldRuntime` отдельно владеет `TraversalRecovery`; эта gameplay-обязанность больше не зависит от generator bootstrap;
- `default.project.json`, test mappings и `projects/dev-combined.project.json` могут маппить dev-only `Worldgen` для локального полного flow;
- `world.project.json` остаётся generator preview;
- `projects/moonfall-authoring.project.json` предоставляет Studio-only one-shot bake module с явной confirmation string;
- `MoonfallRegionManifest` оборачивает canonical `WorldLayout` и реальные `TravelDefinitions`, сохраняя stable zone/POI/spawn/travel IDs.

Физическое сохранение generated Terrain/static environment в реальный Moonfall Place остаётся отдельным owner checkpoint. До выполнения bake + visual/runtime acceptance нельзя считать опубликованный production Moonfall принятым, даже если repo-side contracts и Rojo builds зелёные.

## 17. Mobile UI surfaces

Touch-интерфейс использует три явных типа поверхности: `CompactDialog` для коротких подтверждений, `MenuSheet` для небольших наборов вариантов и `FullWorkspace` для Inventory, Sell, Journal, Map и длинных каталогов. `ResponsiveLayout` предоставляет только usable dimensions, layout class, общий gap и минимальную touch-цель; выбор структуры и внутренняя геометрия остаются у владельца feature.

Интерактивные `ScreenGui` используют `CoreUISafeInsets`, а намеренно экранный gameplay HUD — `DeviceSafeInsets`. Ручной `GetGuiInset` поверх этих политик запрещён. Единый `MobileOverlayCoordinator` скрывает HUD на touch, пока открыт хотя бы один `FullWorkspace`, и восстанавливает прежнее состояние после закрытия последнего workspace.
