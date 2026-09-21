# Развёртывание нескольких Places

## Контур окружений

Числовые идентификаторы не хранятся в исходниках до создания владельцем отдельных test и production Experience. `PlaceConfig` работает fail-closed: неизвестный `GameId` или `PlaceId` не превращается в `DevCombined`. Роль `DevCombined` разрешена только явным Studio-контуром.

## Порядок публикации

1. Создать отдельный тестовый Experience и Places Lobby, Moonfall World и зарезервированный Ruins of Selene.
2. Назначить Lobby стартовым Place.
3. Записать полученные `GameId`/`PlaceId` в отдельные deployment-записи `PlaceConfig`, не смешивая test и production.
4. Собрать и опубликовать `projects/lobby.project.json`, затем `projects/moonfall.project.json`; dungeon mapping до контентного gate остаётся резервным.
5. Проверить опубликованным клиентом переход Lobby → Moonfall, восстановление после ошибки и повторный вход двумя клиентами.
6. Повторить для production только после принятия тестового контура.

## Откат

При ошибке прекратить публикацию, вернуть предыдущие опубликованные версии обоих Places и очистить новые destination IDs из deployment config. Не переводить неизвестные Places в `DevCombined` и не переносить состояние профиля через `TeleportData`.

## BLOCKED_OWNER_ACTION

- Создать Lobby Place и назначить его Start Place.
- Создать Moonfall World Place и при необходимости reserved Dungeon placeholder.
- Предоставить test/prod `GameId` и `PlaceId` для fail-closed deployment config.
- Выполнить published-client acceptance: 1 server + 2 clients.
