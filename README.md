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
- уровни 1–10;
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
- [Правила разработки](docs/DEVELOPMENT_RULES.md)
- [Политика межэтапного рефакторинга](docs/REFACTORING_POLICY.md)
- [Стратегия тестирования](docs/TESTING_STRATEGY.md)
- [Версионирование](docs/VERSIONING.md)
- [Roadmap](docs/ROADMAP.md)
- [Design specification v0.1](docs/superpowers/specs/2026-09-13-luna-world-v0.1-design.md)
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

Проект находится на стадии проектирования и подготовки v0.1. Игровой код ещё не считается начатым до утверждения спецификации и плана реализации.
