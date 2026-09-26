# Развёртывание нескольких Places

## Контур окружений

Production multi-place контур Luna World зафиксирован в `PlaceConfig`:

- Experience / GameId: `10767283011`
- Lobby: `81197415020315`
- Moonfall World: `133570003635782`
- Ruins of Selene: `72524197323645`

`PlaceConfig` работает fail-closed: неизвестный `GameId` или `PlaceId` не превращается в `DevCombined`. Роль `DevCombined` разрешена только явным Studio-контуром.

## Порядок публикации

1. Убедиться, что Lobby остаётся Start Place Experience.
2. На backup/copy Moonfall Place выполнить one-shot authored-world bake через `projects/moonfall-authoring.project.json` по инструкции `tools/worldgen/README.md`.
3. Проверить, что authored root имеет `ManagedBy=MoonfallAuthoredWorld`, ожидаемый terrain revision и `LunaVillageSpawn`; отдельно убедиться, что отключённый Goblin/Cemetery lake не вернулся.
4. Переключить Moonfall Studio на production `projects/moonfall.project.json` и убедиться, что Place стартует без `PlayableWorldBlockout.rebuild()`.
5. Собрать и опубликовать `projects/lobby.project.json` в Lobby Place, `projects/moonfall.project.json` в Moonfall World и `projects/dungeon-selene.project.json` в Ruins of Selene.
6. Проверить опубликованным клиентом переход Lobby → Moonfall → Ruins of Selene → Moonfall.
7. Повторить переход минимум двумя клиентами в party и проверить reserved-server handoff, retreat/return и восстановление после ошибки.

## Authoring / production boundary

`tools/worldgen` разрешён только в:

- `default.project.json` / `projects/dev-combined.project.json` для Studio development;
- `world.project.json` для generator preview;
- `projects/moonfall-authoring.project.json` для one-shot bake.

Lobby, Moonfall и Dungeon production projects не должны маппить `tools/worldgen`. Сохранённый Terrain/static environment живёт в самом Roblox Place; Git остаётся source of truth для layout contracts, generator tooling и gameplay code.

## Откат

При ошибке прекратить публикацию, вернуть предыдущие опубликованные версии обоих Places и очистить новые destination IDs из deployment config. Не переводить неизвестные Places в `DevCombined` и не переносить состояние профиля через `TeleportData`.

Если authored Moonfall bake не принят визуально/runtime, вернуть backup Place и не публиковать production Moonfall mapping поверх непроверенного Terrain.

## OWNER ACCEPTANCE

До завершения multi-place release gate остаются owner-side действия:

- Опубликовать актуальный `projects/dungeon-selene.project.json` в Place `72524197323645`.
- Убедиться, что Moonfall World опубликован из актуального `projects/moonfall.project.json`.
- Выполнить published-client acceptance: Lobby → Moonfall → Ruins of Selene → Moonfall.
- Выполнить multiplayer acceptance: 1 server + минимум 2 clients.
