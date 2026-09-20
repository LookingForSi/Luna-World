# Luna World v0.1 — Спецификация дизайна

Дата: 2026-09-13  
Статус: утверждено владельцем проекта  
Целевая версия: `0.1.0`  
Текущая версия разработки: `0.1.0-dev.0`

## 1. Ключевые решения

Luna World v0.1 — это **Vertical Slice**, а не техническое демо и не mini-MMO.

Игра создаётся как самостоятельная multiplayer RPG внутри Roblox, вдохновлённая ощущением Lineage II эпохи C4 / Interlude: серьёзное стилизованное fantasy, просторные локации, target-based PvE, ощутимая прогрессия и значимый редкий лут. Проект не копирует IP Lineage II, чужие ассеты, названия, карты, интерфейс, музыку, лор или иные защищённые элементы.

Перемещение персонажа — современное (`WASD / gamepad / touch`), а бой строится по классическим принципам target-based MMORPG.

Маршрут v0.1:

`Luna Village → Moonfall Valley → Ruins of Selene`

Целевая длительность первого прохождения: примерно 45–90 минут.

Максимальный уровень v0.1: 15.

## 2. Критерий продуктового успеха

Vertical Slice должен дать положительный ответ на три вопроса:

1. Хочет ли игрок убить ещё одного моба?
2. Хочет ли игрок узнать, какой значимый предмет выпадет следующим?
3. После первого dungeon boss хочет ли игрок увидеть продолжение мира?

Коммерческая проверка и монетизация не являются обязательной целью v0.1.

## 3. Обязательные игровые системы

В v0.1 должны работать:

- выбор персонажа / архетипа;
- современное управление персонажем;
- выбор цели и target frame;
- server-authoritative autoattack;
- активные skills и cooldowns;
- AI мобов с состояниями aggro / chase / leash / attack / return;
- XP и уровни 1–15;
- loot tables;
- inventory;
- визуальная смена экипировки там, где это практически оправдано;
- короткая цепочка quests;
- party до 4 игроков;
- open-world elite / miniboss;
- instanced dungeon;
- финальный dungeon boss;
- сохранение прогресса между сессиями.

Явно не входят в v0.1: PvP, clans, castle sieges, player trading, auction house, crafting, enchantment, mounts, pets, housing, большие raids, battle pass и monetization shop.

## 4. Архетипы персонажей

Для v0.1 достаточно трёх архетипов:

- Knight — живучий melee;
- Ranger — ranged physical DPS;
- Mystic — magic damage с ограниченной поддержкой / heal.

У каждого есть базовая атака и примерно три активных skill. Названия abilities являются рабочими до отдельного content/lore pass.

## 5. Устройство мира

### Luna Village

Безопасное стартовое поселение с onboarding, NPC, базовыми merchant / blacksmith взаимодействиями и дорогой в основной мир. Деревня должна ощущаться местом, а не lobby с кнопками.

### Moonfall Valley

Общая multiplayer PvE-зона с постепенным ростом опасности, несколькими визуально различимыми участками, несколькими типами мобов, elite / miniboss и видимой связью с будущим dungeon.

### Ruins of Selene

Короткий instanced dungeon для 1–4 игроков длительностью примерно 8–15 минут. Финальный boss имеет как минимум обычную атаку, читаемую telegraphed AoE-механику и усиление / enrage при низком HP.

## 6. Визуальное направление

Основной референс по атмосфере — ранняя Lineage II C4 / Interlude.

Обязательные качества:

- серьёзное стилизованное fantasy;
- близкие к человеческим пропорции персонажей;
- визуальный язык камня, дерева, леса и древних руин;
- сдержанная насыщенность;
- мотивы луны, серебра и холодного света как часть собственной идентичности Luna World;
- хорошо читаемые силуэты и combat telegraphs;
- ограниченный визуальный шум;
- UI с эргономикой классических PC MMORPG, адаптированный под mobile.

Проект сознательно избегает прямого воспроизведения защищённых ассетов и дизайнов других игр.

## 7. Техническая архитектура

Игровое состояние, влияющее на результат, является **server authoritative**.

Ответственность клиента: input, camera, выбор цели как намерение, UI, presentation / FX и отправка запросов действий.

Ответственность сервера: validation, результаты боя, cooldowns, XP, loot, inventory ownership, currency, quests, party eligibility, dungeon rewards и persistence.

Планируемая структура исходников:

```text
src/client
src/server
src/shared
tests
docs
```

Планируемый Rojo mapping:

```text
src/shared  -> ReplicatedStorage/Shared
src/server  -> ServerScriptService/Server
src/client  -> StarterPlayer/StarterPlayerScripts/Client
```

Для v0.1 не требуется внешний backend, PostgreSQL, Redis, custom auth или универсальный framework, пока не доказано конкретное ограничение Roblox Platform.

## 8. Persistence

Минимальный набор persistent state:

- archetype;
- level;
- XP;
- currency;
- inventory;
- equipment;
- unlocked skills;
- quest state.

Схема сохранений имеет отдельную целочисленную версию `DataVersion` и последовательные migrations. SemVer игры не заменяет версию схемы сохранений.

Ошибка загрузки / миграции существующего профиля не должна молча превращаться в новый пустой профиль.

## 9. Версионирование

Релизы игры используют SemVer.

Разработка начинается с `0.1.0-dev.0`; первый принятый Vertical Slice выпускается как `0.1.0`.

Значимые изменения релиза фиксируются в `CHANGELOG.md`, а релизные commits получают tag вида `vX.Y.Z`.

## 10. Тестирование

Тестирование многоуровневое:

- unit tests для детерминированной логики;
- integration tests для взаимодействия игровых систем;
- Roblox runtime / playtests для replication, character lifecycle, UI, physics и platform behavior.

Каждый gameplay milestone требует multiplayer smoke test минимум с конфигурацией `1 server + 2 clients`.

Каждый gameplay Remote дополнительно проверяется на некорректные / malicious запросы, соответствующие его контракту.

Изменения persistence schema требуют migration tests на representative older data.

## 11. Политика рефакторинга

После каждого крупного milestone выполняется отдельный stabilization / refactor gate до начала следующего большого функционального блока.

Gate включает:

- зелёные тесты;
- устранение regression;
- удаление dead code;
- сокращение дублирования;
- проверку границ модулей;
- проверку network validation;
- проверку lifecycle / cleanup;
- проверку persistence migrations;
- обновление документации.

Большие переписывания без конкретно сформулированной проблемы и стратегии проверки запрещены.

## 12. Порядок реализации

1. Playground: Wolf target / attack / damage / death / XP / respawn в multiplayer.
2. Combat & Skills.
3. Progression, Loot & Persistence.
4. Luna Village & Quests.
5. Moonfall Valley.
6. Party & Multiplayer Hardening.
7. Ruins of Selene.
8. Полный v0.1 alpha candidate и внешний playtest.

После каждого этапа выполняется stabilization gate согласно `docs/ROADMAP.md` и `docs/REFACTORING_POLICY.md`.

## 13. Канонические детальные документы

Эта спецификация является утверждённым снимком ключевых решений. Детальные и обновляемые правила находятся в:

- `docs/PRODUCT_VISION.md`;
- `docs/GAME_DESIGN_V0.1.md`;
- `docs/WORLD_AND_ART_DIRECTION.md`;
- `docs/ARCHITECTURE.md`;
- `docs/DEVELOPMENT_RULES.md`;
- `docs/REFACTORING_POLICY.md`;
- `docs/TESTING_STRATEGY.md`;
- `docs/VERSIONING.md`;
- `docs/ROADMAP.md`;
- `AGENTS.md`.

Если реализация обнаруживает необходимое противоречие с дизайном, оно поднимается явно и соответствующий документ изменяется осознанно. Молчаливый обход зафиксированной архитектуры запрещён.
