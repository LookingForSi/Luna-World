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
