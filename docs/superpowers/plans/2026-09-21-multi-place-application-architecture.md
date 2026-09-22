# План реализации Multi-Place Application Architecture v0.1

Дата: 2026-09-21

Ветка реализации: `architecture/multi-place-implementation-v01`

Design baseline: `docs/superpowers/specs/2026-09-21-multi-place-application-architecture-design.md`

## 1. Цель и границы

Эволюционно перевести Luna World с одного совмещённого Place на архитектуру Experience:

```text
Lobby (Start Place) -> Moonfall World -> Ruins of Selene (reserved Dungeon)
```

При этом сохранить `DevCombined` для полного локального цикла Lobby → Gameplay без настоящего teleport, не менять gameplay/balance и не переносить authoritative state на клиент или в `TeleportData`.

Этот документ является implementation plan. По owner decision 2026-09-21 multi-place foundation выполняется первой от стабильного `main` dev0.3 RC1; незавершённый mobile PR #36 закрыт без merge, а Mobile UX v2 (#37) переносится после архитектурных foundation gates, чтобы не переделывать bootstrap/UI ownership дважды. Mobile redesign не должен блокировать Gates A–E, но его product requirements сохраняются как отдельный backlog/spec.

### Вне scope

- новый gameplay content, классы, экономика или balance;
- реализация party, кроме узкого будущего transport interface;
- контент и encounters Ruins of Selene;
- новый UI framework, ECS, DI framework, generic event bus или generic RemoteRouter;
- полный rewrite persistence либо внешний backend;
- переименование stable character/item/mob/quest/NPC/POI/settlement IDs;
- feature-grouped reparent всех remotes до появления compatibility lookup contract;
- дробление Moonfall на отдельный Place для каждой зоны.

## 2. Неизменяемые контракты

После каждого gate ветка должна запускаться, а следующие invariants должны быть подтверждены тестами:

1. Сервер остаётся источником истины для character selection, inventory, equipment, Luna, XP, quests, rewards и transfer eligibility.
2. Клиент передаёт только intent; `TeleportData` не содержит authoritative profile state.
3. Существующий `AccountProfile`/`DataVersion` сохраняет backward compatibility. Повышать `DataVersion` только если фактически меняется persisted schema, с migration и representative-old-save test.
4. Production неизвестный/unset `PlaceRole` приводит к явной bootstrap error; он не запускает все features.
5. Lobby не запускает combat/mobs/world runtime, World не запускает Character Lobby, Dungeon не получает village-only services.
6. Gameplay input не включается до authoritative arrival/`CharacterReady` gate.
7. `DevCombined` использует те же domain rules и `characterId` contract, что production; заменяется только transport.
8. Production Moonfall не строит terrain через `PlayableWorldBlockout.rebuild()` при старте.
9. Studio/debug/worldgen code отсутствует или неактивен в production manifests.
10. Каждый добавленный component/connection/task имеет симметричный `stop()`/cleanup; bootstrap останавливает уже запущенные components в обратном порядке.

## 3. Общая стратегия выполнения

### 3.1. Последовательность и размер изменений

Gates выполняются строго `A → B → C → D → E → F → G`. Не начинать Gate C до стабилизации A/B; не начинать physical Place rollout до отдельного review transfer design/implementation.

Каждый gate разбить на небольшие commits в порядке:

1. characterization/contract tests, падающие на отсутствующем новом contract или фиксирующие старое поведение;
2. минимальная реализация;
3. migration wiring и cleanup только после зелёных tests;
4. документация фактически достигнутого состояния.

Не смешивать в одном implementation commit structural move и изменение behavior. Mechanical moves выполнять отдельно с consumer search до/после и без одновременного переименования public API.

### 3.2. Review gates

- после Gate A — независимый review bootstrap/module boundaries;
- после Gate C — отдельный high-risk review persistence, ownership handoff, failure recovery и malicious/duplicate intents;
- после Gate D — опубликованный integration review/acceptance Lobby → Moonfall;
- после Gate F — review каждого самостоятельного feature split, а не одного massive diff;
- после Gate G — финальный multi-place integration review.

Для high-risk Gates B/C/D использовать свежий independent implementation/review pass. Mechanical mapping/move batches в E/F выполнять последовательно после characterization tests.

### 3.3. Общие automated checks

После каждого code gate:

```bash
for f in tests/check_*.py; do python3 "$f" || exit 1; done
rojo build default.project.json -o /tmp/LunaWorld-default.rbxlx
rojo build test.project.json -o /tmp/LunaWorld-tests.rbxlx
git diff --check
```

После появления role-specific projects вместо/вдобавок к legacy aliases собирать каждый production/dev/test mapping. Luau specs запускать через существующий `test.project.json`/`tests/run.server.luau` Roblox test flow; результат Studio TestService не заменять одним успешным Rojo build.

Manual Roblox checks всегда маркировать `PASS`, `FAIL` или `DEFERRED — pending owner runtime acceptance`. Teleport acceptance нельзя выполнять обычным Studio Play.

## 4. Gate A — Runtime foundation

### Результат gate

Существующий single-place runtime работает как явный `DevCombined`, а entry scripts делегируют lifecycle generic bootstrap и role manifest. Внешнее gameplay behavior не меняется.

### Characterization до structural change

Добавить:

- `tests/RuntimeManifestSpec.luau` — порядок `start`, обратный порядок `stop`, rollback уже запущенных components при ошибке старта, idempotent shutdown;
- `tests/PlaceRuntimeSpec.luau` — разрешение четырёх roles, Studio override и fail-fast неизвестного production PlaceId;
- `tests/check_runtime_manifest_contract.py` — статический contract: thin entrypoints, отсутствие произвольных `game.PlaceId` checks вне runtime config, Lobby/World/Dungeon allowlists;
- расширить `tests/check_server_bootstrap_topology.py` и `tests/check_server_service_lifecycle_contract.py`, сначала зафиксировав текущий набор и порядок сервисов `main.server.luau` и обратный cleanup;
- добавить `tests/check_client_bootstrap_topology.py`, фиксирующий нынешний lobby-first/`CharacterReady`-then-gameplay порядок до Gate B.

### Новые shared interfaces

Создать:

- `src/shared/core/runtime/PlaceRole.luau` — frozen values/types `Lobby | World | Dungeon | DevCombined` и validation;
- `src/shared/core/runtime/PlaceRuntime.luau` — pure role resolution `resolve(placeId, gameId, isStudio, override?)` и predicates `isLobby(role)`, `isWorld(role)`, `isDungeon(role)`, `isDevCombined(role)`; только этот модуль знает role resolution. Не хранить mutable module-global `currentRole`: resolved role передаётся bootstrap/application context явно, чтобы tests и несколько runtime contexts не зависели от скрытого singleton-state;
- `src/shared/config/PlaceConfig.luau` — deployment mapping без выдуманных production IDs; до Gate D разрешён только явный Studio `DevCombined` override, production unset fail-fast;
- `src/shared/core/runtime/RuntimeComponent.luau` — тип `{ name: string, start: () -> (), stop: () -> () }`;
- `src/shared/core/runtime/RuntimeManifest.luau` — ordered список components и проверка уникальных имён.

### Server bootstrap

Создать:

- `src/server/bootstrap/ServerBootstrap.luau` — принимает готовый manifest, запускает components по порядку, при partial failure останавливает запущенные в reverse order, на `BindToClose` выполняет idempotent stop;
- `src/server/bootstrap/adapters/ExistingServerComponents.luau` — узкие adapters над текущими service `start/stop`; здесь разрешена текущая dependency wiring `MobAIService.start(MobAbilityService.requestAttack)`;
- `src/server/bootstrap/manifests/LobbyServerManifest.luau`;
- `src/server/bootstrap/manifests/WorldServerManifest.luau`;
- `src/server/bootstrap/manifests/DungeonServerManifest.luau`;
- `src/server/bootstrap/manifests/DevCombinedServerManifest.luau`.

На Gate A production manifests могут быть неполными и не использоваться в default mapping, но их allowlists уже тестируются. `DevCombinedServerManifest` обязан воспроизвести текущий порядок запуска. Логику поиска `LunaWorldPlayableBlockout`, tagging spawn и ожидание world bootstrap временно оформить отдельным named component/adaptor, а не спрятать в generic bootstrap. Текущий auto-running `WorldBootstrap.server.luau` должен быть явно учтён как legacy dev-only prerequisite: либо временно остаётся отдельным DevCombined bootstrap с characterization contract, либо превращается в управляемый adapter/module. Нельзя считать lifecycle полностью manifest-owned, оставив скрытый auto-run script вне allowlist.

Изменить `src/server/main.server.luau`: оставить ранний `Players.CharacterAutoLoads = false`, resolve role и один вызов `ServerBootstrap.start(manifest)`. Entry point больше не требует каждый gameplay service напрямую.

### Client bootstrap foundation

Создать зеркально:

- `src/client/bootstrap/ClientBootstrap.luau`;
- `src/client/bootstrap/manifests/LobbyClientManifest.luau`;
- `src/client/bootstrap/manifests/WorldClientManifest.luau`;
- `src/client/bootstrap/manifests/DungeonClientManifest.luau`;
- `src/client/bootstrap/manifests/DevCombinedClientManifest.luau`;
- `src/client/bootstrap/adapters/ExistingClientComponents.luau`.

На Gate A adapter сохраняет текущее содержимое `startGameplay()` и cleanup из `src/client/main.client.luau`; перенос не должен менять момент старта controllers. `main.client.luau` становится thin role-aware entrypoint. Полная application state model относится к Gate B.

### Gate A acceptance

- `DevCombined` воспроизводит текущий create/select → spawn → gameplay flow;
- повторный stop не вызывает ошибок или double-disconnect;
- injected component start failure останавливает только ранее запущенные components в reverse order;
- role manifests не содержат запрещённых services;
- existing Python contracts, Luau specs и default/test builds зелёные;
- Studio smoke: 1 server + 2 clients, без gameplay regression;
- отдельный bootstrap/module-boundary review закрыт до Gate B.

## 5. Gate B — Client application shell

### Результат gate

Client имеет явные состояния `Boot`, `Lobby`, `Transitioning`, `Gameplay`, `Disconnected/Error`; Lobby и gameplay controllers имеют раздельное ownership. `DevCombined` переходит локально по тому же character selection contract.

### Tests first

Создать:

- `tests/ClientApplicationStateSpec.luau` — допустимые/недопустимые transitions, idempotency, cleanup и error transition;
- `tests/LocalPlaceTransitionAdapterSpec.luau` — принимает только validated `characterId` intent и не переносит profile fields;
- `tests/check_client_application_shell_contract.py` — Lobby manifest не содержит combat/inventory/quest-world controllers; World manifest не содержит Character Lobby; input создаётся только после ready gate;
- расширить `tests/check_character_lobby_contract.py` на сохранение roster/create/delete/select semantics и прекращение lobby UI после transition;
- сохранить зелёными responsive/mobile contracts без UI redesign.

### Files и interfaces

Создать:

- `src/client/bootstrap/ClientApplication.luau` с API `start(initialContext)`, `transition(nextState, context?)`, `stop()` и read-only `getState()` для tests;
- `src/client/bootstrap/ClientApplicationState.luau` — pure transition rules;
- `src/client/bootstrap/LobbyClientRuntime.luau` — владеет `CharacterLobbyController` и transfer/loading presentation;
- `src/client/bootstrap/GameplayClientRuntime.luau` — владеет текущими Movement/Combat/HUD/Inventory/Economy/Quest/Responsive components;
- `src/client/bootstrap/ArrivalReadyGate.luau` — включает gameplay только после server-confirmed `CharacterReady`/arrival context;
- `src/client/bootstrap/transport/LocalPlaceTransitionAdapter.luau` — `enterWorld(characterId)` переводит `DevCombined` через `Transitioning` в локальный authoritative select/ready flow;
- `src/client/bootstrap/transport/TeleportTransitionAdapter.luau` — пока только интерфейс/presentation boundary; не вызывает TeleportService с клиента.

Уточнить `CharacterLobbyController` public callback: `start({ onEnterWorld = (characterId) -> () })` либо минимальный эквивалент. Controller продолжает владеть существующим экраном и network coordination до Gate F, но больше не стартует gameplay напрямую.

`ClientApplication` обязан уничтожать Lobby runtime перед gameplay start и отключать input при `Transitioning`/`Error`. Не выполнять UI decomposition в этом gate.

### Gate B acceptance

- DevCombined показывает переход `Lobby → Transitioning → Gameplay` без teleport;
- production Lobby остаётся в Lobby до server response/teleport;
- direct/duplicate/invalid state transition отклоняется без двойных connections;
- combat/action bar/inventory input отсутствует до ready;
- disconnect/error оставляет UI в безопасном состоянии;
- 1 server + 2 clients Studio smoke проходит;
- независимый review lifecycle/module boundaries завершён.

## 6. Gate C — Persistence transfer (отдельный high-risk batch)

### Результат gate

Server-authoritative `PlaceTransferService` выполняет freeze → save → одноразовый handoff intent → release/ownership transfer → teleport, а destination claims account и сверяет intent с authoritative store. Failure восстанавливает source session без permanent `Transferring` lock.

### Сначала characterization текущего store

Расширить до изменения contract:

- `tests/ProfileStoreContractSpec.luau`;
- `tests/RobloxProfileStoreSpec.luau`;
- `tests/SessionProfileStoreSpec.luau`;
- `tests/LeaseRulesSpec.luau`;
- `tests/ProfileRoundTripSpec.luau`;
- `tests/check_player_data_lifecycle_contract.py`.

Зафиксировать normal claim/save/release, чужой token → `Busy`/`Conflict`, старый token не перезаписывает нового owner, validation/migration failure не создаёт новый профиль.

### Transfer data contracts

Создать:

- `src/shared/core/transfer/TransferTypes.luau` — `TransferIntent` только с `transferVersion`, `transferId`, `userId` (если хранится server-side), `characterId`, `sourceRole`, `destinationRole`, `entryPointId`, `issuedAt`, `expiresAt`, status/nonce; клиентский `TeleportData` DTO не включает secure state;
- `src/shared/core/transfer/TransferRules.luau` — pure validation, allowed role transitions, expiry, destination/character match, single-use rules;
- `src/shared/config/TransferConfig.luau` — version, bounded TTL, retry/backoff/failure timing без magic numbers;
- `src/server/core/transfer/TransferIntentStoreContract.luau`;
- `src/server/core/transfer/MemoryTransferIntentStore.luau` для deterministic tests/Studio;
- `src/server/core/transfer/RobloxTransferIntentStore.luau` на `MemoryStoreService` либо иной штатной cross-server primitive после отдельного spike. Intent store хранит только handoff metadata, не копию profile.

Перед выбором MemoryStore primitive выполнить узкий spike и зафиксировать в code review: atomic create/consume semantics, TTL, duplicate consume и recovery behavior. Не использовать `TeleportData` как fallback database.

### Profile/session changes

Изменить:

- `src/server/services/PlayerDataService.luau`: добавить `Transferring` в `AccountState`; методы `beginTransfer(player)`, `commitTransferRelease(player)`, `cancelTransfer(player)`, `isTransferring(player)` и destination activation seam. `mutateAccount`/`mutateProfile` обязаны отклонять gameplay mutations в `Transferring`;
- `src/server/persistence/ProfileStoreContract.luau` и обе реализации только если выбранная handoff primitive требует нового atomic method. Предпочесть explicit release-before-teleport с recoverable re-claim source, если tests докажут отсутствие race/data-loss; не добавлять opaque lease bypass;
- `src/server/persistence/LeaseRules.luau` — только pure ownership rules, необходимые выбранному contract;
- autosave/leave paths `PlayerDataService` — не должны параллельно писать после начала transfer или повторно release уже переданную lease.

Если persisted `AccountProfile` не меняется, `DataVersion` не повышать. Transfer records имеют собственную `transferVersion`.

### PlaceTransferService и arrival

Создать:

- `src/server/core/transfer/TeleportGateway.luau` — injectable wrapper над server-only `TeleportService:TeleportAsync()` и `TeleportInitFailed`;
- `src/server/core/transfer/PlaceTransferService.luau` — validation destination/active owned character, freeze, save/release, intent creation, teleport, failure compensation, per-player idempotency/rate limit;
- `src/server/core/transfer/CharacterArrivalService.luau` — читает join data, выполняет дешёвую shape/version/destination проверку без consume, claims profile, затем atomically consumes intent с match по `transferId`/user/destination, сверяет owned `characterId` и entry point и только после этого вызывает существующий activation seam. Любая ошибка после успешного claim обязана симметрично release/cleanup destination lease; invalid intent не должен оставлять профиль занятым;
- `src/server/core/transfer/GameplayMutationGate.luau` либо узкий PlayerDataService query, который existing authoritative services используют для отказа во время transfer;
- минимальные `EnterWorldRequest`/`TransferResult` remotes в role mappings или compatibility remote lookup. Handler принимает только request id + `characterId`/destination intent и повторно проверяет ownership на server.

`CharacterService` больше не считает production `Select` достаточным для локального world spawn: в Lobby selection/enter вызывает `PlaceTransferService`; DevCombined adapter сохраняет локальный select flow. Совместимость существующего remote protocol держать адаптером до Gate F.

### Обязательные tests

Создать:

- `tests/TransferRulesSpec.luau`;
- `tests/TransferIntentStoreSpec.luau`;
- `tests/PlaceTransferServiceSpec.luau` с fake gateway/store/clock;
- `tests/CharacterArrivalServiceSpec.luau`;
- `tests/PlayerDataTransferLifecycleSpec.luau`;
- `tests/check_place_transfer_security_contract.py`.

Сценарии:

1. normal claim/save/release;
2. Lobby → World handoff без штатного `Busy`;
3. destination приходит после source release;
4. synchronous `TeleportAsync` failure до ухода player;
5. `TeleportInitFailed` после начала transfer;
6. duplicate, consumed, malformed и expired intent;
7. join без intent либо с чужим `characterId`/destination;
8. TeleportData с поддельными Luna/inventory/XP игнорируется;
9. old session token не может overwrite нового owner;
10. autosave/PlayerRemoving/BindToClose не конфликтуют с `Transferring`;
11. source recovery re-claims/unfreezes безопасно либо переводит в actionable Error без silent data loss;
12. concurrent double Enter World создаёт не более одного transfer;
13. mutation requests во время freeze отклоняются server-side;
14. destination успешно claim-ит profile, но intent уже consumed/expired/mismatched — destination гарантированно release-ит lease и не оставляет `Busy`;
15. intent успешно consumed, но character activation/arrival component падает — destination выполняет deterministic cleanup/release и выдаёт явный recovery/error path без потерянной ownership.

### Gate C acceptance

- все failure paths завершаются `CharacterReady` на восстановленном source либо явным `Error`, никогда вечным `Transferring`;
- transfer intent не содержит authoritative profile state;
- destination активирует только принадлежащий account character после profile validation;
- persistence/data-loss, race, replay и hostile-request review выполнен отдельным reviewer;
- Gate D не начинается до закрытия findings.

## 7. Gate D — Physical Places и deployment

### Результат gate

Experience содержит Lobby как Start Place и Moonfall World; role-specific Rojo projects собирают только разрешённые runtime trees; опубликованный Roblox client проходит настоящий teleport.

### Project mappings

Создать:

- `projects/lobby.project.json`;
- `projects/moonfall.project.json`;
- `projects/dev-combined.project.json`;
- `projects/tests.project.json` (либо оставить `test.project.json` как documented alias);
- `projects/dungeon-selene.project.json` может появиться skeleton здесь, но активируется в Gate G.

Сохранить `default.project.json` как backward-compatible alias на `DevCombined` на время migration, если текущий workflow от него зависит. Не дублировать вручную remote lists: либо вынести генерируемый/проверяемый common mapping, либо добавить contract test, гарантирующий одинаковые имена и классы remotes между нужными Places.

Изменить `src/shared/config/PlaceConfig.luau`: внести реальные numeric `LobbyPlaceId`, `MoonfallPlaceId` только после создания owner-side Places и хранить их в явных deployment mappings по `game.GameId`/environment (как минимум `test` и `production`). Нельзя иметь один неразличимый набор IDs для test и production universes. IDs не размазывать по code/project manifests; unknown universe/place fail-fast.

Добавить `docs/MULTI_PLACE_DEPLOYMENT.md` на русском с publish order, назначением Start Place, безопасными test/prod ID slots, rollback и published acceptance. Не хранить secrets.

### Automated contracts

Создать/расширить:

- `tests/check_place_project_mappings.py` — production Lobby не мапит gameplay/worldgen; Moonfall не мапит Lobby UI; Studio debug отсутствует в production;
- `tests/check_remote_mapping_compatibility.py`;
- `tests/check_place_config_contract.py` — deployment mappings разделены по universe/environment (`game.GameId`), Place IDs положительные/уникальные внутри environment, test Experience не может случайно использовать production destinations, unknown universe/place fail-fast;
- build каждого mapping через Rojo;
- full existing Python/Luau suite.

### Published acceptance — обязательный owner checkpoint

В отдельном unpublished/test Experience, Roblox client, минимум 1 server + 2 clients:

1. Lobby является Start Place;
2. оба клиента видят roster, могут create/select/delete согласно прежним rules;
3. Enter World инициируется только сервером;
4. оба клиента попадают в Moonfall с выбранными owned characters;
5. inventory, equipment, Luna, level/XP и quests сохранены;
6. rejoin/return не даёт `Busy` и восстанавливает state;
7. намеренно вызванный teleport failure возвращает UI/session в retryable state;
8. поддельный/expired/replayed intent не активирует gameplay;
9. Moonfall не запускает Lobby controller, Lobby не создаёт mobs/combat/world runtime;
10. Output обоих Places не содержит recurring lifecycle/DataStore errors.

Без этого результата Gate D помечается `DEFERRED — pending owner runtime acceptance`; Gate E может готовить независимую tooling separation, но foundation нельзя объявлять готовой и нельзя принимать решения, зависящие от реального handoff result.

## 8. Gate E — Разделение authored world и worldgen tooling

### Обязательный authored-world bake checkpoint

Перед исключением runtime worldgen выполнить отдельный owner-visible bake/migration:

1. зафиксировать backup/snapshot текущего owner-accepted Moonfall baseline;
2. в dev/worldgen authoring режиме один раз сгенерировать текущий terrain/static blockout в Studio;
3. сохранить получившийся Terrain/static environment непосредственно в Moonfall Place как authored content;
4. убедиться, что в bake не возвращаются отклонённые экспериментальные world changes (в частности отключённая генерация проблемного lake не должна «случайно» стать частью production authored terrain);
5. перезапустить Moonfall без runtime generator и сравнить spawn anchors, дороги, высоты, water/traversal и ключевые POI;
6. только после owner smoke и contract checks исключать generator из production mapping.

Нельзя просто переместить `PlayableWorldBlockout` в `tools/` и объявить authored-world migration завершённой: физический Moonfall Place должен реально содержать сохранённый production Terrain/static environment.

### Результат gate

Production Moonfall загружает authored Terrain/static environment из Place и gameplay RegionManifest; blockout generator остаётся dev/editor tooling и не входит в production server mapping.

### Characterization и migration

До move расширить:

- `tests/check_playable_world_blockout_contract.py`;
- `tests/check_world_gameplay_integration_contract.py`;
- `tests/CraftingWorldPassSpec.luau`;
- world layout validation на zones, POIs, spawn markers, travel entries, settlement/recovery anchors и stable IDs.

Создать:

- `src/shared/world/RegionManifestTypes.luau`;
- `src/shared/world/MoonfallRegionManifest.luau`, сначала как wrapper над `WorldLayout`, с `id`, `zones`, `pointsOfInterest`, `spawnMarkers`, `travelEntries`;
- `src/server/features/world/MoonfallWorldRuntime.luau` — валидирует authored anchors/tags и запускает gameplay-only traversal/recovery integration, но не строит terrain;
- `tools/worldgen/primitives/BlockoutPrimitives.luau`;
- `tools/worldgen/moonfall/{VillageAndMeadowsBlockout,NorthernZonesBlockout,WorldCompositionBlockout,WorldDressingBlockout,PlayableWorldBlockout,TerrainGrounding}.luau`;
- `tools/worldgen/preview/WorldBootstrap.server.luau` и при необходимости перенос `src/client/world-preview/ZonePresentation.client.luau` в dev-only mapping.

Mechanical move выполнять с сохранением behavior и обновлением require paths отдельным commit. `TraversalRecovery` оставить gameplay module (переместить в `src/server/features/world/TraversalRecovery.luau`), потому что water hazards используют единый recovery contract.

Удалять старые `src/server/world/*` пути только после `rg` consumer search, зелёных characterization tests и подтверждения, что authored Moonfall Place содержит terrain/static content. Не удалять stable `WorldLayout.SpawnMarkers`: это seam authoritative `MobService`.

### Tests и acceptance

- `tests/RegionManifestSpec.luau` — schema/unique IDs/references;
- `tests/check_production_worldgen_exclusion.py` — никакой production mapping/manifest не содержит generator или `PlayableWorldBlockout.rebuild()`;
- regression stable-ID snapshot для mob/item/quest/NPC/POI/settlement IDs;
- Rojo builds production + dev worldgen preview;
- Moonfall Studio smoke подтверждает authored spawn anchors, cleared roads, closed floors, grounded props и shared traversal recovery;
- 1 server + 2 clients подтверждают authoritative mobs по `SpawnMarkers` без placeholder duplicates.

## 9. Gate F — Feature decomposition (несколько самостоятельных batches)

### Правило gate

Не выполнять Gate F одним commit/PR. Каждый split начинается с characterization tests, сохраняет public facade на время migration и завершается отдельным review. Порядок ниже уменьшает пересечения; следующий batch начинается только после зелёного предыдущего.

### F1 — Character Lobby

Создать под `src/client/features/lobby/`:

- `CharacterLobbyController.luau` — network/state coordination;
- `CharacterLobbyScreen.luau`;
- `CharacterCreationModal.luau`;
- `CharacterDeleteModal.luau`;
- `LegacyIdentityModal.luau`.

Сначала расширить `tests/check_character_lobby_contract.py` и добавить pure presenter/state specs. Старый `src/client/controllers/CharacterLobbyController.luau` временно оставить facade, затем удалить после consumer search. Authoritative nickname/ownership/slot rules остаются в server/shared rules.

### F2 — Quest client

Создать под `src/client/features/quests/`:

- `QuestController.luau` — snapshot/network coordination;
- `QuestJournalScreen.luau`;
- `QuestOfferModal.luau`;
- `NpcDialogueModal.luau`;
- `TravelConfirmModal.luau`;
- `WorldMapScreen.luau`;
- `QuestNavigationPresenter.luau`.

До split зафиксировать `tests/check_quest_system_contract.py`, `tests/check_travel_system_contract.py`, map/marker/navigation behavior. Карта не должна знать внутренности dialogue modal; reward/progress остаются server-only.

### F3 — Economy UI

Создать под `src/client/features/economy/`:

- `EconomyController.luau`;
- `MerchantScreen.luau`;
- `SellWorkspace.luau`;
- `BlacksmithScreen.luau`;
- `EconomyResultPresenter.luau`.

Сохранить callbacks `buy/sell/sellBatch/craft`; прогнать economy usability/security/loot-craft contracts. Не менять prices/recipes/stock.

### F4 — Inventory UI

Создать под `src/client/features/inventory/`:

- `InventoryController.luau`;
- `InventoryScreen.luau`;
- `ItemGrid.luau`;
- `EquipmentPane.luau`;
- `ItemDetailsPane.luau`;
- `InventoryActionFooter.luau`.

Выделять только реально testable composition; не строить OOP hierarchy. Сохранить equip/unequip/consume/discard/quick-slot semantics и все responsive/touch contracts.

### F5 — Responsive ownership

Создать/переместить shared primitives в `src/client/core/ui/`: `Theme`, `ResponsiveLayout`, `Panel`, `Button`, `Modal`, scroll helpers. Ввести observable metrics contract `ResponsiveLayout.observe(callback) -> disconnect`; feature screen реализует `applyLayout(metrics)`.

Постепенно убрать из `ResponsiveUiController` поиск внутренних элементов чужих screens по string names. Каждый screen migration имеет собственный responsive regression test. Не менять визуальный дизайн одновременно со structural move.

### F6 — Combat server seams

До split усилить `CombatIntegrationSpec`, `CombatRemoteValidationSpec`, skill/auto-attack/action lifecycle specs и malicious request cases. Создать под `src/server/features/combat/`:

- `CombatCoordinator.luau` (совместимый facade/orchestration);
- `PlayerCombatState.luau`;
- `TargetingService.luau`;
- `BasicAttackService.luau`;
- `SkillExecutionService.luau`;
- `AutoAttackService.luau`;
- lifecycle adapter.

Существующие pure `ActionRules`, `AutoAttackRules`, `DamageRules`, `CooldownRules`, `SkillRules`, `EffectRules`, `ResourceRules` переиспользовать без дублирования. Remote type/shape/ownership/range/cooldown/resource/rate validation остаётся server-side и имеет feature-specific owner. Старый `CombatService` удалять только после перевода consumers и parity tests.

### Gate F acceptance

- каждый batch имеет characterization-before-change и отдельный commit/review;
- public facade удалён только после `rg` consumer proof;
- responsive/mobile screenshots и 1 server + 2 clients smoke не показывают regression;
- gameplay values, stable IDs и remote semantics не изменены;
- module dependency graph не требует boot unrelated features.

## 10. Gate G — Dungeon-ready foundation

### Результат gate

Добавлены Dungeon role manifest, reserved-server transport contract и session arrival boundary без реализации Ruins of Selene content, party system или rewards.

### Files и interfaces

Создать/завершить:

- `projects/dungeon-selene.project.json`;
- `src/server/bootstrap/manifests/DungeonServerManifest.luau` — только PlayerData/Arrival, Combat, Inventory, Progression, DungeonSession skeleton, Mobs/Loot, Respawn и presentation networking;
- `src/client/bootstrap/manifests/DungeonClientManifest.luau` — Gameplay shell без Lobby/economy/village-only UI;
- `src/shared/core/transfer/DungeonTransferTypes.luau` — non-authoritative `dungeonId`, `transferId`, destination/entry intent и optional opaque future party/session reference; никаких rewards/profile fields;
- `src/server/features/dungeon/DungeonSessionService.luau` — lifecycle/arrival validation skeleton, без encounters/completion rewards;
- расширить `TeleportGateway` методом reserved destination (`TeleportOptions.ShouldReserveServer` или access-code adapter) без client authority;
- добавить `RuinsOfSelenePlaceId` в `PlaceConfig` только после физического создания Place.

Минимальный future-party seam принимает server-generated member/user IDs или session reference, но не реализует invite/membership и не доверяет клиентскому roster.

### Tests

- `tests/DungeonTransferRulesSpec.luau` — allowed World→Dungeon/return roles, TTL, destination/session match;
- `tests/DungeonSessionServiceSpec.luau` — valid arrival, foreign/duplicate/expired intent, cleanup;
- расширить `RuntimeManifestSpec.luau` — dungeon allowlist и отсутствие Character Lobby/village economy/world NPC;
- `tests/check_dungeon_project_mapping.py`;
- regression: transfer payload не содержит inventory/Luna/XP/quest/reward;
- fake gateway test подтверждает reserved-server options и server-only invocation;
- Rojo build dungeon project.

### Acceptance

Published smoke допускает пустой dungeon shell: server-authoritative test transfer в reserved server, validated chosen character, safe return/rejoin и сохранённый profile. Полный dungeon route, party entry, boss и rewards остаются отдельным milestone и не являются условием этого gate.

## 11. Финальная стабилизация и документация

После Gate G:

1. Запустить все Luau specs, все `tests/check_*.py` и Rojo builds всех mappings.
2. Выполнить consumer search старых bootstraps, compatibility facades, worldgen production references и произвольных `game.PlaceId` checks.
3. Проверить lifecycle cleanup, remote validation, persistence migrations/transfer replay и отсутствие debug paths в production.
4. Обновить `docs/ARCHITECTURE.md` под фактически реализованные contracts, `README.md`/developer workflow и `CHANGELOG.md` `[Unreleased]` только фактическими изменениями. Не bump version без release decision.
5. Провести финальный independent multi-place integration review.
6. Выполнить объединённый owner acceptance checklist:
   - published Lobby → Moonfall, 1 server + 2 clients;
   - inventory/Luna/XP/equipment/quests survive transfer/rejoin;
   - failure recovery и no permanent lock;
   - DevCombined полный Studio flow;
   - production Moonfall без runtime worldgen;
   - empty Dungeon reserved-server smoke.

Foundation можно объявить завершённой только при наличии сохранённых результатов automated checks и фактического published acceptance. Любой невыполненный runtime checkpoint остаётся явно `DEFERRED — pending owner runtime acceptance`, а не PASS.

## 12. Delivery ledger для каждого gate

В PR/task ledger после каждого gate фиксировать:

- exact HEAD и commits;
- выполненные задачи и изменённые public interfaces;
- полный список команд/результатов automated checks;
- manual checks с `PASS`/`FAIL`/`DEFERRED`;
- известные риски/compatibility adapters;
- следующий gate и его blockers.

Branch должна оставаться clean и runnable после каждого gate. Не merge'ить самостоятельно до закрытия требуемых reviews и owner runtime acceptance.
