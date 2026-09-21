# Luna World — Multi-Place Application Architecture v0.1

Статус: **approved design baseline — 2026-09-21**.

Основание: владелец проекта утвердил модель
**Lobby Place → Moonfall World Place → отдельные Dungeon/Region Places**,
при этом для разработки сохраняется **dev-combined Place**, где Lobby и World можно запускать в одном Studio-сеансе без реального teleport.

---

## 1. Цель

Перестроить Luna World из одного gameplay playground с наложенным Character Lobby в масштабируемую Roblox-архитектуру Experience с несколькими Places.

Архитектура должна:

- сохранить текущий server-authoritative gameplay;
- разделить account/lobby flow, open-world gameplay и dungeon/region runtime;
- позволить добавлять новые регионы без разрастания одного глобального bootstrap;
- не заставлять разработчика телепортироваться между опубликованными Places при каждом локальном тесте;
- убрать production-зависимость от runtime-генерации всего мира;
- создать понятные module boundaries для client/server/features;
- сохранить единый persistence contract между Places;
- подготовить безопасный transfer lifecycle между серверами;
- уменьшить размер и связанность крупных controller/service файлов;
- не переписать работающую игру «с нуля».

Рефакторинг должен быть **эволюционным**: на каждом этапе проект остаётся запускаемым и тестируемым.

---

## 2. Текущее состояние и причина рефакторинга

Сейчас production-like запуск фактически устроен как один Place:

```text
Place
├─ WorldBootstrap.server
│  └─ PlayableWorldBlockout.rebuild()
├─ main.server
│  └─ запускает почти все gameplay services
└─ main.client
   ├─ CharacterLobbyController.start()
   └─ после CharacterReady запускает весь gameplay client
```

Character Lobby является экраном перед уже поднятым gameplay runtime, а не отдельным application state / Place.

Одновременно `src/server/world` содержит runtime-генерацию значительной части terrain/blockout, хотя принятый world-production contract уже требует хранить production landscape в самом Place, а Luau использовать для gameplay contracts, validation и tooling.

Наблюдаемые structural hotspots:

- `src/server/services/CombatService.luau` — слишком много combat/runtime обязанностей;
- `src/client/controllers/QuestController.luau` — карта, журнал, dialogue, offer, travel, markers и navigation в одном модуле;
- `src/client/controllers/CharacterLobbyController.luau` — transport/state/UI/styling/modal flows вместе;
- `src/client/ui/InventoryUi.luau` и `EconomyUi.luau` — несколько самостоятельных экранов/режимов в одном module;
- world blockout modules одновременно являются генераторами геометрии и частью production server tree;
- `main.server.luau` и `main.client.luau` знают слишком много конкретных подсистем.

Это не считается поводом на большой rewrite. Цель — ввести явные границы и постепенно перенести существующий код за них.

---

## 3. Roblox platform constraints

Архитектура опирается на штатную модель Roblox Experience → Places.

Официальная документация Roblox:

- Multi-place experience: https://create.roblox.com/docs/production/publishing/publish-games-and-places
- TeleportService: https://create.roblox.com/docs/projects/teleport
- DataStore: https://create.roblox.com/docs/cloud-services/data-stores

Ключевые ограничения:

1. Один Experience может содержать несколько Places.
2. Каждый Place имеет собственный DataModel: terrain, objects, scripts, lighting и т. д.
3. `TeleportService:TeleportAsync()` вызывается с server-side code.
4. Teleport между Places нельзя полноценно протестировать обычным Studio playtest — acceptance выполняется в опубликованном Roblox client.
5. DataStore одного Experience доступен из разных Places/servers.
6. `TeleportData` не считается безопасным источником authoritative player state.
7. Для dungeon-flow допустимы reserved servers через `TeleportOptions.ShouldReserveServer` / reserved access code.

---

## 4. Целевая топология Experience

### 4.1. Production topology

```text
Luna World Experience
│
├─ Place: Lobby
│  ├─ Account load
│  ├─ Character roster
│  ├─ Character create/delete
│  ├─ Character selection
│  ├─ Account-level settings
│  └─ Enter World
│
├─ Place: Moonfall World
│  ├─ Luna Village
│  ├─ Luna Meadows
│  ├─ Moonfall Road
│  ├─ Goblin Camp
│  ├─ Spider Hollow
│  ├─ Dark Woodland
│  ├─ Old Cemetery
│  ├─ Fallen Shrine
│  └─ Ancient Approach
│
├─ Place: Ruins of Selene
│  └─ instanced dungeon / boss
│
└─ Future Places
   ├─ next large region
   └─ future dungeons / special instances
```

### 4.2. Что НЕ является отдельным Place

Обычные application/UI surfaces не выносятся в Place:

- inventory;
- blacksmith;
- merchant;
- quest journal;
- map;
- account shop, если он является обычным UI;
- settings.

Отдельный Place нужен только когда существует самостоятельный 3D runtime / matchmaking / lifecycle.

### 4.3. Region granularity

Не вводить правило «каждая зона = Place».

Один большой связный open-world region остаётся одним Place, пока:

- игрок должен перемещаться внутри него без loading transition;
- content scale остаётся управляемым;
- memory/performance не требуют разделения;
- нет отдельного session lifecycle.

---

## 5. Dev topology

### 5.1. Обязательный dev-combined Place

Разработка должна сохранить быстрый Studio loop:

```text
dev-combined
├─ Lobby UI
├─ Moonfall world
├─ gameplay services
└─ local transition adapter вместо TeleportService
```

Разработчик должен иметь возможность:

1. открыть один Place;
2. нажать Play;
3. создать/выбрать героя;
4. войти в world runtime;
5. тестировать combat/quests/economy;
6. не публиковать Experience ради каждой итерации.

### 5.2. Одинаковые application contracts

Dev-combined не должен иметь отдельную бизнес-логику.

Различается только transport:

```text
Production:
EnterWorld -> TeleportGateway -> TeleportService

Studio combined:
EnterWorld -> LocalPlaceTransitionAdapter
```

Character selection, validation, persistence rules и destination contract остаются одинаковыми.

---

## 6. Place Roles

В shared-коде вводится явное понятие `PlaceRole`.

Минимальный контракт:

```text
Lobby
World
Dungeon
DevCombined
```

Role разрешается через конфигурацию PlaceId / Studio override.

Ни один feature module не должен самостоятельно проверять произвольные `game.PlaceId`.

Разрешена одна shared abstraction:

```text
PlaceRuntime
├─ getRole()
├─ isLobby()
├─ isWorld()
├─ isDungeon()
└─ isDevCombined()
```

PlaceId — deployment configuration, а не gameplay logic.

Числовые PlaceId не являются частью design spec. После создания Places они заносятся в отдельный config module. В production unset/unknown role должен приводить к явной bootstrap error, а не к запуску «всего на всякий случай».

---

## 7. Bootstrap architecture

### 7.1. Принцип

`main.server.luau` и `main.client.luau` не должны вручную знать весь список services/controllers.

Вместо этого каждый Place получает manifest/bootstrap composition.

Целевой уровень:

```text
server/
├─ bootstrap/
│  ├─ ServerBootstrap.luau
│  └─ manifests/
│     ├─ LobbyServerManifest.luau
│     ├─ WorldServerManifest.luau
│     ├─ DungeonServerManifest.luau
│     └─ DevCombinedServerManifest.luau
│
client/
├─ bootstrap/
│  ├─ ClientBootstrap.luau
│  └─ manifests/
│     ├─ LobbyClientManifest.luau
│     ├─ WorldClientManifest.luau
│     ├─ DungeonClientManifest.luau
│     └─ DevCombinedClientManifest.luau
```

Manifest содержит ordered lifecycle components, но не бизнес-логику.

### 7.2. Lifecycle contract

Новый runtime component должен иметь понятный интерфейс:

```lua
export type RuntimeComponent = {
    start: () -> (),
    stop: () -> (),
}
```

Если component требует dependencies/options, manifest создаёт adapter/factory заранее; не вводить service locator с произвольным глобальным lookup.

### 7.3. Server manifests

#### Lobby

```text
PlayerDataService
CharacterService
PlaceTransferService
StudioDebugService (Studio only)
```

Lobby не запускает:

- MobService;
- CombatService;
- LootService;
- Quest world runtime;
- EconomyWorldService;
- RespawnService;
- world NPC spawns.

#### Moonfall World

```text
PlayerDataService
CharacterActivation / arrival
Progression
Combat
Inventory
Economy
Mobs
Loot
World drops
NPC
Quests
Travel
Respawn
Regeneration
Presentation networking
```

#### Dungeon

Только services, реально нужные instance runtime:

```text
PlayerDataService
CharacterActivation / arrival
Combat
Inventory
Progression
DungeonSession
Mobs
Loot
Respawn
Presentation networking
```

Village economy/world NPC modules не запускаются автоматически в dungeon.

#### DevCombined

Композиция Lobby + World, но переход выполняется локальным adapter.

---

## 8. Client application states

Client должен иметь явный application lifecycle, а не просто последовательность UI start calls.

Минимальные состояния:

```text
Boot
Lobby
Transitioning
Gameplay
Disconnected/Error
```

Для dungeon Place Gameplay может дополнительно знать mode/region, но не требуется общий сложный state machine.

### 8.1. Lobby state

Разрешены:

- Character Lobby UI;
- account network;
- character network;
- transfer UI/loading state.

Не стартуют:

- CombatHud;
- ActionBar;
- TargetController;
- Inventory gameplay UI;
- Quest world markers;
- Economy world UI.

### 8.2. Gameplay state

После authoritative character activation:

- lobby UI уничтожен/остановлен;
- стартуют gameplay controllers;
- HUD получает текущий place/region context;
- gameplay input включается только после ready gate.

### 8.3. DevCombined

В DevCombined transition:

```text
Lobby -> Transitioning -> Gameplay
```

происходит внутри того же DataModel без TeleportService.

Этот путь обязан использовать тот же `characterId` selection contract, что production teleport.

---

## 9. Persistence и transfer lifecycle

Это high-risk часть архитектуры.

### 9.1. Текущая проблема

Текущий profile store использует lease:

```text
claim(userId, sessionToken)
save(...)
release(...)
```

При teleport source server и destination server могут короткое время существовать одновременно.

Если destination выполняет `claim()` раньше, чем source успел `release()`, текущая модель может вернуть `Busy`.

Нельзя решать это:

- уменьшением lease timeout;
- blind retry на пять минут;
- доверием к TeleportData;
- отключением lease.

### 9.2. Целевые account states

PlayerData/session lifecycle расширяется логически до:

```text
Loading
AccountReady
CharacterReady
Transferring
Saving
Released
Error
```

### 9.3. Transfer flow

Концептуально:

```text
1. server validates destination
2. server validates active character / party
3. gameplay mutations freeze for this player
4. authoritative profile is saved
5. transfer intent is created
6. source releases or hands off session ownership
7. TeleportAsync begins
8. destination claims account
9. destination validates join intent against authoritative state
10. character is activated
11. destination spawn/entry point is resolved
12. gameplay unfreezes
```

Точная ownership-transfer primitive определяется implementation plan после characterization текущего persistence behavior.

Design requirement: игрок не должен получать `Busy` из-за штатного перехода Lobby → World.

### 9.4. TeleportData

Разрешено передавать только non-authoritative intent:

```lua
{
    transferVersion = 1,
    transferId = "...",
    characterId = "...",
    destinationRole = "World",
    entryPointId = "luna_village",
}
```

Нельзя передавать и считать authoritative:

- Luna;
- inventory;
- equipment;
- XP;
- quest completion;
- damage/health state;
- dungeon rewards.

Destination всегда сверяет intent с server-side profile/session state.

### 9.5. Failure handling

Нужно поддержать:

- `TeleportAsync` pcall failure;
- `TeleportInitFailed`;
- destination load failure;
- invalid/expired transfer intent;
- player disconnect во время handoff.

Если teleport не состоялся и player остался на source server, source должен безопасно разморозить session либо восстановить ownership.

Нельзя оставлять character permanently locked в `Transferring`.

---

## 10. Region / world contracts

### 10.1. Production terrain

Production Place хранит:

- Terrain;
- static environment;
- buildings;
- props;
- Lighting;
- architectural collision;
- authored spawn/anchor objects при необходимости.

Production server НЕ должен при каждом старте заново формировать весь terrain.

### 10.2. Worldgen code

Текущие:

- `BlockoutPrimitives`;
- `VillageAndMeadowsBlockout`;
- `NorthernZonesBlockout`;
- `WorldCompositionBlockout`;
- `WorldDressingBlockout`;
- `PlayableWorldBlockout`;

после migration становятся development/editor tooling.

Целевая группа:

```text
tools/
└─ worldgen/
   ├─ primitives/
   ├─ moonfall/
   └─ preview/
```

Они не должны автоматически входить в production ServerScriptService Moonfall Place.

### 10.3. World Manifest

`WorldLayout` не удаляется как концепция. Он превращается из «геометрии всего мира» в gameplay manifest.

Целевой contract:

```text
RegionManifest
├─ id
├─ zones
├─ pointsOfInterest
├─ spawnMarkers
├─ travelEntries
└─ optional route/debug metadata
```

Terrain geometry не является частью manifest.

Для первого этапа допускается сохранить существующий `WorldLayout` и обернуть его в Moonfall manifest без массового переписывания definitions.

### 10.4. Stable IDs

Все существующие stable IDs сохраняются, если нет отдельной migration task:

- mob IDs;
- item IDs;
- quest IDs;
- NPC IDs;
- POI IDs;
- character IDs;
- settlement IDs.

Architecture refactor не должен менять player progression только ради новых каталогов.

---

## 11. Feature-oriented code organization

Не выполнять одномоментное перемещение каждого файла.

Целевая структура:

```text
src/
├─ shared/
│  ├─ core/
│  │  ├─ runtime/
│  │  ├─ networking/
│  │  └─ persistence/
│  ├─ characters/
│  ├─ combat/
│  ├─ inventory/
│  ├─ economy/
│  ├─ quests/
│  ├─ travel/
│  └─ world/
│
├─ client/
│  ├─ bootstrap/
│  ├─ core/
│  │  └─ ui/
│  └─ features/
│     ├─ lobby/
│     ├─ combat/
│     ├─ inventory/
│     ├─ economy/
│     └─ quests/
│
└─ server/
   ├─ bootstrap/
   ├─ core/
   │  ├─ persistence/
   │  └─ transfer/
   └─ features/
      ├─ characters/
      ├─ combat/
      ├─ inventory/
      ├─ economy/
      ├─ mobs/
      ├─ quests/
      └─ travel/
```

Правило migration:

> Файл перемещается только тогда, когда затрагивается соответствующая граница ответственности либо есть самостоятельная mechanical move task с зелёными characterization tests.

Не создавать сотни файлов только ради симметрии каталогов.

---

## 12. Client UI architecture

### 12.1. Foundation

Сохранить и развивать общий responsive foundation:

```text
client/core/ui/
├─ Theme
├─ ResponsiveLayout
├─ Panel
├─ Button
├─ Modal
└─ Scroll primitives
```

Не вводить сторонний React/UI framework только ради рефакторинга.

### 12.2. Ownership rule

Долгосрочно `ResponsiveUiController` не должен искать внутренние элементы чужих экранов по строковым именам и переставлять их.

Предпочтительный contract:

```text
ResponsiveLayout.observe(metrics)
             ↓
feature screen/controller
             ↓
screen.applyLayout(metrics)
```

Экран владеет своей внутренней геометрией.

Shared responsive module владеет только:

- safe viewport;
- layout classification;
- min/max;
- touch target;
- shared scaling helpers.

### 12.3. Character Lobby split

Текущий `CharacterLobbyController` разделить концептуально на:

```text
CharacterLobbyController
├─ network/state coordination
├─ CharacterLobbyScreen
├─ CharacterCreationModal
├─ CharacterDeleteModal
└─ LegacyIdentityModal
```

UI не должен самостоятельно владеть authoritative character rules.

### 12.4. Quest split

Текущий `QuestController` разделить минимум по responsibilities:

```text
QuestController
├─ QuestJournalScreen
├─ QuestOfferModal
├─ NpcDialogueModal
├─ TravelConfirmModal
├─ WorldMapScreen
└─ QuestNavigationPresenter
```

Network snapshot state остаётся централизованным настолько, насколько это необходимо, но карта не должна знать внутренности dialogue modal.

### 12.5. Economy split

```text
EconomyController
├─ MerchantScreen
├─ SellWorkspace
├─ BlacksmithScreen
└─ EconomyResultPresenter
```

### 12.6. Inventory split

Inventory сохраняет один feature controller, но screen может выделить:

- item grid;
- equipment pane;
- details pane;
- action footer.

Цель — testable view composition, а не OOP hierarchy.

---

## 13. Server service boundaries

### 13.1. CombatService

`CombatService` должен перестать быть catch-all, но split выполняется по наблюдаемым responsibilities, а не по желанию уменьшить число строк.

Целевые logical seams:

```text
CombatService / CombatCoordinator
├─ PlayerCombatState
├─ Targeting
├─ BasicAttack
├─ SkillExecution
├─ AutoAttack / Approach
└─ lifecycle integration
```

Уже существующие pure shared modules:

- ActionRules;
- AutoAttackRules;
- DamageRules;
- CooldownRules;
- SkillRules;
- EffectRules;
- ResourceRules;

сохраняются и переиспользуются.

Не переносить authoritative combat logic на client.

### 13.2. Network boundary

Remote validation должна оставаться server-side.

Во время refactor допускается создавать feature-specific network services, но запрещено вводить generic RemoteRouter, который скрывает ownership и validation всех domains в одном месте.

### 13.3. World services

Разделять:

- authored world content;
- gameplay spawn/runtime;
- NPC interaction;
- travel;
- recovery.

World generation tooling не является gameplay service.

---

## 14. Remote organization

Текущий flat `ReplicatedStorage.Remotes` допустим как migration baseline.

Целевая структура может стать feature-grouped:

```text
Remotes/
├─ Characters/
├─ Combat/
├─ Inventory/
├─ Economy/
├─ Quests/
└─ Travel/
```

Но remote rename/reparent не является первым шагом.

Сначала вводится typed/shared lookup contract или compatibility adapter, чтобы migration не ломала все clients/services одновременно.

Stable remote semantics важнее красивого дерева Explorer.

---

## 15. Что считается dead/debug/temporary code

Удаление выполняется только после доказательства отсутствия production use.

Кандидаты на review:

- `StudioTestPanel` — оставить только Studio/dev-combined;
- Studio-only mutation helpers в gameplay services — спрятать за debug adapter либо Studio-only service;
- `src/client/world-preview/ZonePresentation.client.luau` — проверить, не попадает ли preview UI в production mapping;
- runtime worldgen/bootstrap — убрать из production Place после authored-world migration;
- compatibility aliases, появившиеся во время прошлых migrations — удалить только после consumer search/tests.

Запрещено удалять код лишь потому, что его имя содержит `legacy`: сначала characterization и usage search.

---

## 16. Rojo project topology

После migration должны существовать отдельные project mappings для Place roles.

Целевая идея:

```text
projects/
├─ lobby.project.json
├─ moonfall.project.json
├─ dungeon-selene.project.json
├─ dev-combined.project.json
└─ tests.project.json
```

Допускается оставить root-level project files, если это лучше совместимо с текущим workflow. Важен contract, а не каталог.

### Lobby project

Мапит:

- shared core/features, нужные Lobby;
- lobby server bootstrap;
- lobby client bootstrap;
- lobby UI.

Не мапит production worldgen и gameplay-only startup scripts.

### Moonfall project

Мапит:

- shared gameplay;
- world server bootstrap;
- gameplay client bootstrap;
- Moonfall authored Place.

### Dev-combined project

Мапит:

- lobby + gameplay code;
- local transition adapter;
- optional worldgen tooling только если это явно dev-only.

---

## 17. Testing strategy

### 17.1. До structural changes

Для каждой крупной границы добавить characterization tests существующего поведения.

Architecture refactor не должен одновременно менять balance/gameplay.

### 17.2. Automated contracts

Нужны проверки минимум на:

- каждый PlaceRole запускает только разрешённые components;
- Lobby не запускает combat/mobs/world runtime;
- World не запускает Character Lobby;
- DevCombined предоставляет оба flow через local adapter;
- unknown production PlaceRole fail-fast;
- transfer intent не содержит authoritative inventory/currency/XP;
- destination не доверяет TeleportData без profile validation;
- transfer failure снимает freeze/lock;
- DataStore contract не повреждается при handoff;
- worldgen modules отсутствуют в production Moonfall server mapping;
- Studio debug modules отсутствуют/неактивны в production manifests;
- existing stable IDs unchanged;
- client application lifecycle не позволяет gameplay input до CharacterReady/arrival ready.

### 17.3. Persistence tests

Обязательны unit/integration scenarios:

1. normal claim/save/release;
2. Lobby → World transfer;
3. destination arrives after source release;
4. transfer API fails before player leaves;
5. `TeleportInitFailed`;
6. duplicate/expired transfer intent;
7. destination joins without valid transfer intent;
8. old session token cannot overwrite new owner;
9. autosave не конфликтует с `Transferring`.

### 17.4. Manual Roblox acceptance

Поскольку настоящий teleport не тестируется обычным Studio play:

Production acceptance проводится в опубликованном test Experience:

```text
Lobby
→ create/select character
→ Enter World
→ Moonfall spawn
→ inventory/xp/quests preserved
→ return/rejoin
→ state preserved
```

Dungeon milestone позже добавляет:

```text
World
→ party/dungeon entry
→ reserved server
→ dungeon completion/exit
→ authoritative rewards preserved
```

DevCombined отдельно принимается в Studio.

---

## 18. Migration strategy

Refactor выполняется отдельными gates.

### Gate A — Runtime foundation

Создать:

- PlaceRole;
- runtime manifests;
- generic bootstrap lifecycle;
- current single-place behavior через `DevCombined`.

На этом этапе внешний gameplay не меняется.

### Gate B — Client application shell

Ввести:

- Boot/Lobby/Transitioning/Gameplay;
- separation lobby bootstrap vs gameplay bootstrap;
- local transition adapter.

Существующий Character Lobby продолжает работать.

### Gate C — Persistence transfer

Добавить безопасный handoff lifecycle и server-side `PlaceTransferService`.

Этот gate требует отдельного high-risk review.

### Gate D — Physical Places

Создать/настроить Lobby и Moonfall Places в Experience.

Добавить numeric deployment config.

Выполнить published-client teleport acceptance.

### Gate E — World authoring separation

Убрать runtime worldgen из production Moonfall Place.

Сохранить generator как dev/editor tooling.

### Gate F — Feature decomposition

После работающей multi-place foundation постепенно:

- split Character Lobby;
- split Quest client;
- split Economy UI;
- split Inventory UI where useful;
- split CombatService по proven seams.

Не выполнять Gate F одним massive commit.

### Gate G — Dungeon-ready foundation

Добавить Dungeon place manifest и transport contract без обязательной реализации всего Ruins of Selene content.

---

## 19. Не делать в этом refactor

Out of scope:

- новый gameplay content;
- новый класс;
- новая экономика;
- monetization;
- party implementation, кроме минимального interface allowance для будущего dungeon transfer;
- Ruins of Selene content;
- новый UI framework dependency;
- ECS;
- dependency injection framework;
- generic event bus;
- полный rewrite persistence;
- изменение balance;
- изменение stable item/mob/quest IDs;
- замена DataStore внешним backend;
- дробление open world на десятки Places.

---

## 20. Architecture invariants

После каждого gate должны оставаться истинными правила:

1. Server authoritative state.
2. Client отправляет intent, а не результат.
3. Persistence schema/versioning сохраняет backward compatibility.
4. Place transport не является источником secure state.
5. Один feature не должен требовать boot всех остальных features.
6. Production world geometry не строится заново при каждом server startup.
7. DevCombined использует те же domain rules, что production Places.
8. Studio-only/debug tooling не влияет на production runtime.
9. Responsive UI foundation остаётся shared, но feature screen владеет своей layout composition.
10. Refactor не меняет gameplay behavior без отдельной product requirement.

---

## 21. Definition of Done архитектурного refactor

Foundation считается готовой, когда одновременно выполнено:

- Experience содержит рабочие Lobby и Moonfall Places;
- Lobby является Start Place;
- character roster/create/delete работает в Lobby;
- Enter World выполняет server-authoritative teleport;
- destination активирует именно выбранного принадлежащего игроку character;
- normal teleport не приводит к lease `Busy`;
- inventory, Luna, XP, equipment и quests переживают переход;
- teleport failure восстанавливается без permanent lock;
- Moonfall запускает только gameplay runtime;
- Lobby не запускает mobs/combat/world services;
- production Moonfall не зависит от runtime `PlayableWorldBlockout.rebuild()`;
- DevCombined по-прежнему позволяет полный локальный Studio flow без реального teleport;
- existing automated gameplay contracts остаются зелёными;
- добавлены architecture/transfer contracts;
- опубликованный 2-client acceptance выполнен;
- docs/ARCHITECTURE.md обновлён под фактически реализованное состояние;
- старые bootstrap/worldgen production paths либо удалены, либо явно переведены в dev/tooling.

---

## 22. Требования к Codex

Перед реализацией Codex обязан:

1. прочитать `AGENTS.md`;
2. прочитать standing docs, перечисленные в AGENTS;
3. прочитать этот spec;
4. не начинать massive refactor напрямую;
5. сначала подготовить отдельный implementation plan;
6. разбить migration на gates A–G;
7. для каждого gate указать точные files/interfaces/tests;
8. использовать characterization tests до structural change;
9. выполнять high-risk persistence/transfer изменения отдельным batch;
10. не смешивать mobile UI feature work и multi-place architecture в один implementation commit;
11. не удалять runtime behavior без доказательства consumer/characterization;
12. после каждого gate оставлять branch runnable;
13. выполнять отдельный code review для:
    - bootstrap/module-boundary gate;
    - persistence/transfer gate;
    - final multi-place integration.

Рекомендуемый execution mode для implementation plan: **subagent-driven для high-risk gates B/C/D, native coherent batches для mechanical moves после стабилизации**.

---

## 23. Branch / sequencing

Этот spec создан в ветке:

```text
architecture/multi-place-foundation-v01
```

Она основана на текущем HEAD mobile responsive work PR #36.

Перед началом архитектурной реализации:

1. PR #36 должен быть стабилизирован и принят;
2. architecture branch должен быть синхронизирован с фактическим post-#36 baseline;
3. затем создаётся implementation plan;
4. только после review plan начинается кодовый refactor.

Multi-place implementation не должен блокировать завершение текущего mobile acceptance.

---

## 24. Итоговая модель

```text
                    ┌───────────────────┐
                    │   Luna Experience │
                    └─────────┬─────────┘
                              │
                       Start Place
                              │
                    ┌─────────▼─────────┐
                    │      Lobby        │
                    │ account/character │
                    └─────────┬─────────┘
                              │ server transfer
                              ▼
                    ┌───────────────────┐
                    │   Moonfall World  │
                    │ open-world region │
                    └──────┬───────┬────┘
                           │       │
                  future region   dungeon
                           │       │
                           ▼       ▼
                    ┌─────────┐ ┌──────────────┐
                    │ Region  │ │ Ruins Selene │
                    │ Place   │ │ reserved     │
                    └─────────┘ └──────────────┘


Development only:

┌────────────────────────────────────────────┐
│ dev-combined                               │
│ Lobby + Moonfall + LocalTransitionAdapter  │
│ no real TeleportService required           │
└────────────────────────────────────────────┘
```

Это целевая application architecture Luna World для дальнейшего развития v0.1 и последующих регионов.
