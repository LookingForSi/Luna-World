# Luna World — Testing Strategy

## 1. Цель

Тестирование должно защищать gameplay contracts, multiplayer consistency и persistence. Roblox runtime остаётся обязательной частью проверки: unit tests не заменяют реальный server/client playtest.

## 2. Уровни тестирования

### 2.1. Unit tests

Подходят для чистой логики:

- damage formulas;
- XP curves;
- loot-table selection;
- item rules;
- inventory capacity/stacking;
- quest objective transitions;
- cooldown calculations;
- persistence migrations;
- validation helpers.

Чистую бизнес-логику по возможности отделять от Roblox Instances, чтобы её было легче тестировать.

### 2.2. Integration tests

Проверяют взаимодействие систем:

- combat death → XP award;
- combat death → loot eligibility;
- inventory → equipment → recalculated stats;
- quest objective → completion → reward;
- party membership → shared credit;
- save/load → restored progression;
- migration → current schema.

### 2.3. Roblox runtime playtests

Обязательны для систем, зависящих от replication, physics, character lifecycle, UI или DataStore behavior.

Перед закрытием gameplay milestone минимальный multiplayer test:

- 1 server;
- не менее 2 clients.

## 3. Базовая test matrix v0.1

### Character / spawn

- новый игрок появляется корректно;
- respawn после смерти не дублирует state/connections;
- два игрока видят друг друга согласованно.

### Targeting / combat

- valid target выбирается;
- invalid/dead target отклоняется;
- skill вне range не наносит damage;
- skill на cooldown не срабатывает повторно;
- недостаток resource отклоняет skill;
- два клиента видят согласованный HP target;
- death происходит один раз;
- reward не выдаётся дважды из-за повторного remote/request.

### Mob AI

- aggro срабатывает в нужном радиусе;
- chase работает;
- leash возвращает mob;
- mob корректно сбрасывает target;
- death/respawn не создают дубликатов;
- удаление player не ломает AI state.

### Progression

- XP добавляется один раз;
- level-up корректно пересчитывает progression;
- cap level 10 соблюдается;
- skill unlock происходит в ожидаемый момент.

### Loot / inventory

- loot roll выполняется сервером;
- item нельзя получить повторным client replay;
- stacking/capacity работают;
- equip требует ownership;
- неверный item ID отклоняется;
- equipment изменяет stats один раз.

### Quests

- objectives засчитываются только валидному игроку;
- completion не дублируется;
- reward не может быть повторно запрошен клиентом;
- progress сохраняется и восстанавливается.

### Party

- invite/accept/leave работают;
- невозможно принять просроченный/несуществующий invite;
- party cap соблюдается;
- shared credit выдаётся только eligible members.

### Dungeon

- party попадает в правильную session;
- посторонний игрок не получает reward чужого completion;
- boss completion регистрируется один раз;
- повторный remote не дублирует reward.

### Persistence

- новый profile создаётся с current DataVersion;
- существующий profile загружается без потери данных;
- старая representative schema мигрируется;
- save/load round-trip сохраняет ключевые поля;
- load failure не трактуется как пустой новый profile;
- shutdown / player leave path не создаёт очевидных duplicate writes.

## 4. Exploit-oriented tests

Для каждого gameplay Remote проверяем как минимум:

- неизвестный ID;
- неверный type;
- чужой entity/item;
- слишком большая дистанция;
- request во время cooldown;
- слишком частые requests;
- повтор одного и того же request;
- request в недопустимом player state.

Клиентский UI не является security boundary.

## 5. Regression tests

Каждый подтверждённый bug, который можно выразить детерминированным тестом, должен получить regression test до или вместе с fix.

Regression test должен падать на старом ошибочном поведении и проходить после исправления.

## 6. Refactoring verification

Перед крупным refactor:

1. relevant tests должны быть зелёными;
2. отсутствующее критическое поведение по возможности покрывается тестом;
3. после refactor результаты тестов должны остаться теми же;
4. manual multiplayer smoke test повторяется, если затронуты network/runtime boundaries.

## 7. Milestone acceptance

Milestone не принимается только по визуальному впечатлению.

Минимум:

- automated tests relevant to milestone — pass;
- Studio Output не содержит необъяснённых recurring errors;
- solo smoke test — pass;
- multiplayer test `1 server + 2 clients` — pass;
- негативные remote cases для новых network endpoints — проверены;
- persistence migration tests — pass, если schema затронута;
- known issues задокументированы;
- для изменений production Place topology/transfer — опубликованный клиент проверяет реальный teleport между соответствующими Places; обычный Studio Play не засчитывается как доказательство TeleportService flow.

## 8. Performance checks

До появления реального контента не вводим фиктивные жёсткие budgets, но на каждом крупном multiplayer milestone проверяем:

- server frame/runtime degradation;
- runaway loops/tasks;
- connection leaks после respawn/leave;
- чрезмерный remote traffic;
- количество одновременно активных AI;
- mobile client behavior на репрезентативном устройстве/эмуляции.

Перед public alpha performance budgets должны быть измерены и зафиксированы отдельно.

## 9. Test framework

Текущий контур состоит из:

- Luau specs в `tests/*.luau` и `tests/client|world` с repository-local `TestRunner`;
- Python contract/regression checks `tests/check_*.py`;
- canonical Rojo builds для default/test/world и role-specific project mappings;
- GitHub Architecture CI как обязательный автоматический gate для PR;
- Roblox Studio/runtime acceptance для поведения, которое нельзя доказать статически.

Tests хранятся в Git и должны быть воспроизводимы другим разработчиком/агентом без ручного редактирования исходного кода.
