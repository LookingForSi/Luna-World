# Luna World — Architecture

## 1. Текущий architectural baseline

Архитектура `0.1.0` построена вокруг server-authoritative gameplay и multi-place Experience.

Production topology:

```text
Luna Experience
├─ Lobby [Start Place] — 81197415020315
│    └─ server-authoritative transfer
├─ Moonfall World — 133570003635782
│    └─ server-authoritative dungeon admission / return
└─ Ruins of Selene — 72524197323645
     └─ isolated Dungeon runtime
```

Development topology:

```text
DevCombined
= Lobby + Moonfall gameplay + local transition adapter + dev-only worldgen
```

`DevCombined` существует только для Studio/development. Неизвестный production `GameId/PlaceId` fail-closed и не получает DevCombined fallback.

## 2. Source of truth

### Git

Authoritative для:

- Luau source;
- shared definitions/config;
- tests;
- persistence schema/migrations;
- runtime manifests;
- Rojo mappings;
- world layout contracts;
- worldgen/authoring tooling;
- документации.

### Roblox Place

Authoritative только для сохранённого authored environment, который по природе является Studio asset state:

- Terrain;
- static world geometry;
- Lighting;
- asset/animation references и composition.

Rojo-managed scripts не редактируются как независимая копия внутри Studio.

## 3. Фактическая структура

```text
src/
├─ client/
│  ├─ bootstrap/          # application/runtime lifecycle
│  ├─ controllers/        # cross-feature input/presentation controllers
│  ├─ features/
│  │  ├─ lobby/
│  │  ├─ quests/
│  │  ├─ economy/
│  │  └─ inventory/
│  └─ ui/                 # shared/gameplay HUD primitives
├─ server/
│  ├─ bootstrap/          # role-specific manifests
│  ├─ core/transfer/      # cross-Place handoff
│  ├─ features/
│  │  ├─ combat/
│  │  └─ world/
│  └─ services/           # bounded gameplay/domain services
└─ shared/
   ├─ config/
   ├─ core/
   ├─ definitions/
   ├─ persistence/
   ├─ combat/
   ├─ economy/
   ├─ inventory/
   ├─ loot/
   ├─ progression/
   ├─ quests/
   ├─ travel/
   ├─ types/
   └─ world/

projects/
├─ dev-combined.project.json
├─ lobby.project.json
├─ moonfall.project.json
├─ moonfall-authoring.project.json
└─ dungeon-selene.project.json

tools/worldgen/              # dev/authoring only
```

Compatibility facades от pre-Gate-F путей удалены после alpha stabilization. Bootstrap должен импортировать feature-owned modules напрямую.

## 4. Runtime roles и bootstrap

`PlaceRuntime` определяет одну из ролей:

- `Lobby`;
- `World`;
- `Dungeon`;
- `DevCombined` — только explicit Studio path.

Server/client entrypoints выбирают role-specific `RuntimeManifest`. Manifest отвечает за ordered startup, rollback при частичном failure и reverse cleanup.

Production role определяется только deployment mapping из `PlaceConfig`. Неизвестный universe/place является ошибкой.

## 5. Client application lifecycle

Клиент использует состояния:

`Boot → Lobby → Transitioning → Gameplay`

и terminal/error состояния:

- `Error`;
- `Disconnected`.

`LobbyClientRuntime` и `GameplayClientRuntime` разделены. Gameplay не запускается до authoritative readiness.

Для DevCombined используется `LocalPlaceTransitionAdapter`; production использует teleport boundary, но domain contract CharacterId/readiness остаётся тем же.

## 6. Account, Character и persistence

Persistent schema: `DataVersion = 3`.

Модель:

`Account → up to 5 Characters → Active Character`.

Рубежы:

- `AccountReady` — roster/lobby API;
- `CharacterReady` — выбран и активирован принадлежащий аккаунту Character;
- legacy `ProfileReady` означает `CharacterReady`.

Каждый Character владеет своими progression, Luna, inventory, equipment и quest state.

Migration `v2 → v3` сохраняет прежний профиль в legacy Character и не должна терять progression.

Game release version и persistent `DataVersion` независимы.

## 7. Place transfer

Lobby → World — server-authoritative lifecycle:

1. SessionGuard допускает только одну logical Experience session на Roblox `UserId`;
2. validate selection/concurrency;
3. freeze gameplay mutations;
4. save/release source profile lease;
5. create one-shot transfer intent в `MemoryStoreService`;
6. server добавляет correlation/session routing metadata и переводит SessionGuard lease в handoff;
7. вызвать teleport;
8. destination принимает тот же logical session и атомарно переносит SessionGuard ownership на новый `JobId`;
9. destination валидирует routing metadata и claim authoritative profile;
10. atomарно consume transfer intent;
11. проверить ownership/destination/entry point;
12. активировать Character и readiness.

SessionGuard — отдельный короткий MemoryStore lease с heartbeat; DataStore account/profile lease остаётся вторым независимым уровнем защиты данных. Studio/DevCombined не зависит от MemoryStore SessionGuard.

`TeleportData` содержит только routing/correlation metadata, включая opaque Experience session id. Inventory, Luna, XP, equipment, quests и иное authoritative state через него не передаются.

Failure paths обязаны cleanup/recover lease/intent безопасно и не позволять старой session перезаписать новую ownership.

## 8. Server-authoritative gameplay

Клиент отправляет intent. Сервер валидирует и рассчитывает:

- target;
- range;
- cooldown;
- skill/resource eligibility;
- damage/heal/crit;
- death/respawn;
- XP/level;
- loot;
- inventory/equipment mutation;
- Luna/economy;
- crafting;
- quests;
- travel;
- persistence.

Remote payload никогда не принимается как готовый authoritative результат.

## 9. Combat ownership

Authoritative orchestration находится в:

`src/server/features/combat/CombatCoordinator.luau`.

Внутренние seams:

- `PlayerCombatState`;
- `TargetingService`;
- `BasicAttackService`;
- `SkillExecutionService`;
- `AutoAttackService`.

Старый `src/server/services/CombatService.luau` compatibility facade после stabilization удалён.

## 10. Client feature ownership

Feature-owned UI/network state:

- Character Lobby → `src/client/features/lobby`;
- Quests → `src/client/features/quests`;
- Economy → `src/client/features/economy`;
- Inventory → `src/client/features/inventory`.

`src/client/controllers` оставлен для действительно cross-feature controllers: combat input/presentation, targeting, movement и responsive coordination.

`src/client/ui` содержит shared/gameplay HUD primitives, а не дубли feature UI.

## 11. Mob/world gameplay

`WorldLayout.SpawnMarkers` — authoritative integration seam для размещения mobs.

Gameplay entity принадлежит MobService; world blockout placeholder не должен сосуществовать с реальной authoritative entity.

AI базируется на server-side state/lifecycle. World geometry не должна содержать void traps или требовать свободного jump для основного маршрута.

## 12. Authored Moonfall

Production Moonfall — authored Place, не runtime-generated map.

`projects/moonfall.project.json` не маппит `tools/worldgen`.

Dev/authoring paths:

- `default.project.json` / `projects/dev-combined.project.json` — локальный full flow;
- `world.project.json` — generator preview;
- `projects/moonfall-authoring.project.json` — one-shot bake.

Production `MoonfallWorldRuntime` принимает authored root с ожидаемыми authoring attributes/revision и обязательным `LunaVillageSpawn`.

Goblin/Cemetery lake не входит в accepted v0.1 world: заброшенный prototype и его terrain-carving helpers удалены из generator tooling, а зона сохраняет принятый сухой baseline.

Физический bake и visual/runtime acceptance реального Moonfall Place — owner-side deployment checkpoint.

## 13. Mobile UI architecture

Touch UI использует три semantic surfaces:

- `CompactDialog`;
- `MenuSheet`;
- `FullWorkspace`.

Feature сам владеет своей внутренней геометрией.

Gameplay HUD на телефоне использует полный physical viewport и локальные edge offsets для CoreUI/notch/virtual controls, а не один глобальный shrinking safe rectangle.

`MobileOverlayCoordinator` скрывает gameplay HUD только пока реально открыт `FullWorkspace`, затем восстанавливает состояние.

## 14. Version/build metadata

Game version хранится в корневом `VERSION`.

Runtime label берётся из `src/shared/config/BuildInfo.luau`.

Contract test требует синхронности этих значений.

Persistent `DataVersion` изменяется отдельно только при изменении save schema.

## 15. Зафиксированный scope v0.1

В текущем baseline уже реализованы:

- Party до 4 игроков;
- shared kill credit и простые XP/drop eligibility rules;
- Ruins of Selene runtime/content;
- dungeon admission, handoff, wipe/checkpoint, reward и return lifecycle;
- Selene's Fallen Guardian;
- Character Lobby, persistence DataVersion 3 и multi-place transfer.

Следующий крупный этап не должен расширять v0.1 новыми системами. Visual asset pass, системная замена placeholder-моделей и дальнейшее насыщение мира относятся к v0.2.

## 16. Deployment state

Numeric deployment mapping заполнен в `PlaceConfig` для Lobby, Moonfall World и Ruins of Selene. Production projects не содержат dev worldgen и fail-closed определяют runtime role по `GameId/PlaceId`.

Актуальная процедура: `docs/MULTI_PLACE_DEPLOYMENT.md`.

Опубликованный Lobby → Moonfall transition уже проходил acceptance на реальном Roblox-клиенте. Финальный deployment checkpoint перед публичным stable rollout — опубликовать текущие Moonfall/Dungeon builds и пройти полный published-client путь Lobby → Moonfall → Ruins → Moonfall, включая multiplayer smoke.
