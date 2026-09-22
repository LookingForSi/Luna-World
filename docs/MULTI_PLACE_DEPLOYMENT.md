# Развёртывание нескольких Places

## Контур окружений

Числовые идентификаторы не хранятся в исходниках до создания владельцем отдельных test и production Experience. `PlaceConfig` работает fail-closed: неизвестный `GameId` или `PlaceId` не превращается в `DevCombined`. Роль `DevCombined` разрешена только явным Studio-контуром.

## Порядок публикации

1. Создать отдельный тестовый Experience и Places Lobby, Moonfall World и зарезервированный Ruins of Selene.
2. Назначить Lobby стартовым Place.
3. Записать полученные `GameId`/`PlaceId` в отдельные deployment-записи `PlaceConfig`, не смешивая test и production.
4. На backup/copy Moonfall Place выполнить one-shot authored-world bake через `projects/moonfall-authoring.project.json` по инструкции `tools/worldgen/README.md`.
5. Проверить, что authored root имеет `ManagedBy=MoonfallAuthoredWorld`, ожидаемый terrain revision и `LunaVillageSpawn`; отдельно убедиться, что отключённый Goblin/Cemetery lake не вернулся.
6. Переключить Moonfall Studio на production `projects/moonfall.project.json` и убедиться, что Place стартует без `PlayableWorldBlockout.rebuild()`.
7. Собрать и опубликовать `projects/lobby.project.json`, затем `projects/moonfall.project.json`; dungeon mapping до контентного gate остаётся резервным.
8. Проверить опубликованным клиентом переход Lobby → Moonfall, восстановление после ошибки и повторный вход двумя клиентами.
9. Повторить для production только после принятия тестового контура.

## Authoring / production boundary

`tools/worldgen` разрешён только в:

- `default.project.json` / `projects/dev-combined.project.json` для Studio development;
- `world.project.json` для generator preview;
- `projects/moonfall-authoring.project.json` для one-shot bake.

Lobby, Moonfall и Dungeon production projects не должны маппить `tools/worldgen`. Сохранённый Terrain/static environment живёт в самом Roblox Place; Git остаётся source of truth для layout contracts, generator tooling и gameplay code.

## Откат

При ошибке прекратить публикацию, вернуть предыдущие опубликованные версии обоих Places и очистить новые destination IDs из deployment config. Не переводить неизвестные Places в `DevCombined` и не переносить состояние профиля через `TeleportData`.

Если authored Moonfall bake не принят визуально/runtime, вернуть backup Place и не публиковать production Moonfall mapping поверх непроверенного Terrain.

## BLOCKED_OWNER_ACTION

- Создать Lobby Place и назначить его Start Place.
- Создать Moonfall World Place и при необходимости reserved Dungeon placeholder.
- Предоставить test/prod `GameId` и `PlaceId` для fail-closed deployment config.
- Выполнить physical Moonfall bake + visual comparison в Roblox Studio.
- Выполнить published-client acceptance: 1 server + 2 clients.
