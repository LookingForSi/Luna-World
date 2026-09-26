# Luna World

**Luna World** — multiplayer RPG для Roblox, вдохновлённая атмосферой классических MMORPG начала 2000-х, прежде всего эпохой Lineage II C4 / Interlude, но создаваемая как самостоятельный мир, визуальный стиль и IP.

Проект строится не как копия Lineage II, а как «любовное письмо» тому игровому опыту: просторный мир, спокойный темп, target-based combat, ощутимая прокачка, редкий лут, совместная охота и чувство, что за следующей дорогой есть ещё один кусок мира.

## Текущая цель

Первая целевая версия — **v0.1 Vertical Slice**.

Игрок должен получить законченный игровой цикл примерно на 45–90 минут:

`Luna Village → Moonfall Valley → Ruins of Selene`

В v0.1 должны работать:

- современное перемещение персонажа (WASD / gamepad / touch);
- классический target-based PvE-бой;
- 3 стартовых архетипа;
- уровни 1–15, где открытый мир покрывает 1–14, а LV15 зарезервирован под финал Ruins of Selene;
- skills и cooldowns;
- mobs, aggro и respawn;
- XP и level-up;
- loot, inventory и equipment;
- quests;
- party до 4 игроков;
- open-world elite/miniboss;
- небольшой instanced dungeon с финальным boss;
- persistent progress между игровыми сессиями.

## Принципы

1. **Gameplay раньше масштаба.** Один хороший регион важнее десяти пустых.
2. **Server authoritative.** Клиент никогда не является источником истины для damage, loot, XP, currency или persistence.
3. **Атмосфера C4 / Interlude, не копирование IP.** Не используем чужие модели, музыку, названия, интерфейс, персонажей или узнаваемые защищённые элементы.
4. **Mobile — полноценная платформа.** Интерфейс и управление проектируются сразу под PC и touch.
5. **Сначала интересная RPG, потом монетизация.** В v0.1 monetization не является целью.
6. **Технический долг не переносится бесконечно.** Между крупными milestone предусмотрены отдельные стабилизационные и рефакторинговые этапы.

## Документация

- [Product vision](docs/PRODUCT_VISION.md)
- [Game Design v0.1](docs/GAME_DESIGN_V0.1.md)
- [Мир и арт-направление](docs/WORLD_AND_ART_DIRECTION.md)
- [Архитектура](docs/ARCHITECTURE.md)
- [Multi-Place deployment](docs/MULTI_PLACE_DEPLOYMENT.md)
- [Roadmap до v0.1](docs/ROADMAP.md)
- [Правила разработки](docs/DEVELOPMENT_RULES.md)
- [Политика межэтапного рефакторинга](docs/REFACTORING_POLICY.md)
- [Стратегия тестирования](docs/TESTING_STRATEGY.md)
- [Версионирование](docs/VERSIONING.md)
- [Roadmap](docs/ROADMAP.md)
- [Design specification v0.1](docs/superpowers/specs/2026-09-13-luna-world-v0.1-design.md)
- [M5 Party & Multiplayer Hardening — design](docs/superpowers/specs/2026-09-24-m5-party-multiplayer-hardening-design.md)
- [M5 Party & Multiplayer Hardening — implementation plan](docs/superpowers/plans/2026-09-24-m5-party-multiplayer-hardening.md)
- [Release 0.1.0-alpha.1](docs/releases/2026-09-22-0.1.0-alpha.1.md)
- [Исторический dev0.1 checkpoint](docs/releases/2026-09-20-dev0.1-checkpoint.md)
- [Правила для AI-агентов](AGENTS.md)

## Toolchain

Основной рабочий контур:

- Roblox Studio;
- Luau;
- Git / GitHub;
- VS Code;
- Rokit;
- Rojo;
- Luau Language Server.

Git является source of truth для исходного кода и документации. Roblox Studio используется для world authoring, runtime и multiplayer playtests.

## Статус

Текущий release checkpoint: **0.1.0-alpha.3**.

Приняты production multi-place architecture `Lobby → Moonfall World → отдельные Dungeon/Region Places`, Studio-only `DevCombined`, authored Moonfall и текущий mobile landscape baseline. Опубликованный Lobby → Moonfall переход проверен на реальном мобильном Roblox-клиенте.

Функциональная база уже включает три архетипа и target-based PvE, open-world progression LV1–14, skills, XP/level-up, loot, inventory/equipment, persistence, Q1–Q7, open-world elites, деревенскую экономику, Character Lobby и responsive gameplay UI.

**M5 Party & Multiplayer Hardening** и локально принятая **M6 Ruins of Selene** завершены и находятся в `main`. Следующий обязательный этап — **M7 / 0.1.0 Release Candidate**: published Lobby → Moonfall → Dungeon acceptance, multiplayer/persistence regression, внешний playtest и release-sanity polish. Полный visual world pass и системная балансировка mobs вынесены в v0.2, чтобы не раздувать scope первого vertical slice.

Актуальный план: [Roadmap](docs/ROADMAP.md).
