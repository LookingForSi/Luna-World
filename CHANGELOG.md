# Changelog

Все значимые изменения Luna World фиксируются в этом файле.

Формат основан на Keep a Changelog, версии проекта следуют Semantic Versioning с учётом того, что до `1.0.0` публичные интерфейсы ещё могут меняться.

## [Unreleased]

### dev0.2 — Gameplay polish pass

- Expanded all Q1–Q7 quest descriptions and moved the young-wolf objective waypoint from the farmer to the wolf staging meadow.
- Rebalanced the combat action block after adding the quest journal button; inventory `I` and quest journal `O` now bypass camera CoreScript processing when no text box is focused.
- Mob target selection now aligns its forgiving screen-space pick area and physical hitbox with the visible silhouette.
- All mobs receive a 1.2× movement-speed multiplier for this tuning pass.
- Goblins have wider aggro/reacquire/social-assist radii; proximity aggro now alerts nearby members of the same social group.
- Goblin camp patrol pairs use authored perimeter pacing lanes, the shaman group stays inside the camp, and two mixed scout/warrior pairs were added to the interior.
- The goblin camp entrance was moved to the road-facing west wall; the accidental wolf-side opening is closed.

### dev0.2 — Quest UI polish

- Quest NPC dialog now opens a generic `Квест` topic before the dedicated quest offer window.
- Quest offer uses padded layout with centered title, description and accept/decline controls.
- Quest journal is collapsed by default, available from the action block and bound to `O`.
- Individual quests can be marked active/inactive; only active quests drive waypoint/map guidance.
- Waypoint cards are compact, show approximate meters (10 studs = 1 m) and hide inside 80 studs.
- NPC quest markers now attach directly to visible actors; active TalkToNpc objectives expose `?`.
- World map zones are rendered as soft borderless ellipses with larger zone names and fewer duplicate POI labels.

### dev0.2 — Mob presentation / Goblin Camp staging

- Все authoritative mobs получили nameplate `LV + имя` с дистанцией видимости около 100 studs.
- Исправлено преобразование screen → viewport координат для выбора цели и расширена forgiving pick-area; дополнительно мобам добавлен невидимый `TargetHitbox`.
- У подхода к Goblin Camp добавлены две компактные социальные пары гоблинов-разведчиков.
- Вожак гоблинов перенесён внутрь лагеря и получил отдельного гоблина-воина телохранителя.
- Группа шамана с двумя воинами сдвинута в отдельную внутреннюю часть лагеря.

### Changed

- Время жизни выброшенных world-drop предметов увеличено до 600 секунд.
- Подсказка инвентаря показывает актуальный binding для текущего устройства; клавиша `I` обрабатывается отдельным keyboard input path.
- Все текущие сервисные NPC начинают взаимодействие одинаковым prompt `Поговорить`; торговец открывает темы `Купить` / `Продать`, кузнец — `Ковать`.
- Обе обычные волчьи стаи приведены к составу 7 волков + 1 вожак; вторая стая перенесена ближе к подходу к лагерю гоблинов.
- Вой вожака теперь не только усиливает волков, но и призывает в бой сородичей в радиусе около 50 studs.
- Торговец и кузнец вынесены из placeholder-зданий на улицу и привязаны к видимым интерактивным NPC.
- Инвентарь переведён на прокручиваемую сетку из 40 слотов.
- Primary action HUD перестроен по схеме Inventory / Auto / Clear Target / Attack; навыки вынесены в отдельную горизонтальную панель из 10 слотов и показывают текст только после открытия.

### Added

- Добавлена server-authoritative цепочка Q1–Q7: onboarding Страж ворот → Фермер, kill/talk/reach objectives, атомарные XP/Luna rewards и persistent quest progress.
- Добавлены общий quest dialogue, tracker до трёх заданий, карта по кнопке/`M`, world waypoint с расстоянием и экранной стрелкой, а также authoritative `!` / `?` markers.
- Persistent schema поднята до `DataVersion = 2` с последовательной migration v1→v2 и сохранением данных dev0.1.
- Выброшенные предметы получают простую world-модель, nameplate/highlight и server-authoritative prompt «Подобрать».
- При невозможности создать world-drop предмет компенсируется обратно в инвентарь, чтобы discard не приводил к тихой потере.

## [0.1.0-dev.2] - 2026-09-20

Development checkpoint **dev0.1**: первая целостная playable-база проекта. Это ещё не финальный `v0.1.0` vertical slice.

### Added

- Реализован Milestone 2: уровни 1–10, XP curve, loot tables, inventory, equipment, пересчёт статов и persistence с отдельным `DataVersion`.
- Собрана Luna Village и открытый маршрут Moonfall Valley до Ancient Approach с authoritative world layout и terrain blockout.
- Населён полный Mob Content Pass v0.1: Young/Grey/Dire Wolves, Goblins, Spiders, Skeletons, Fallen Shrine и Ancient Approach encounters.
- Добавлены локальная social aggro, patrol lifecycle, ranged/magic mob attacks, poison, slow, buffs, cleave/AoE и elite abilities.
- Добавлены open-world elites/minibosses: Wolf Pack Leader, Goblin Chieftain, Dire Wolf Alpha, Grave Guardian и Moonbound Warden.
- Добавлена server-authoritative деревенская экономика: `Newbie` / `NoGrade` item grade, starter weapons, полный No-Grade blacksmith catalog, merchant buy/sell, материалы, consumables, return scroll и LV6 onboarding.
- Добавлены pure economy/pricing/crafting rules, atomic transactions, hostile Remote validation и expected-value balance model естественного маршрута.
- Добавлены merchant/blacksmith interaction points и единый economy UI.
- Добавлены Studio-only инструменты ускоренного playtest: смена класса/уровня, тестовый loot и `SPEED x5`.

### Changed

- World layout переведён из демонстрационного preview в authoritative gameplay dependency.
- Luna Meadows, Moonfall Road и северные зоны растянуты в единый маршрут уровней 1–10.
- Молодые волки перенесены в луговой карман между фермой и Spider Hollow; добавлена вторая стая обычных волков ближе к Moonfall Road.
- Волкам увеличены roaming, detection/aggro/reacquire и leash радиусы для более живого open-world поведения.
- Dark Woodland уплотнён деревьями.
- Максимальная доступная экипировка текущей карты ограничена No-Grade; future-tier stable IDs сохранены, но исключены из obtainable economy.
- Готовая No-Grade экипировка стала редким bonus drop, а основной progression loop строится вокруг материалов, Luna и кузнеца.
- Узкий No-Grade crafting признан частью v0.1; профессии, collectible recipes, affixes, enchantment и player-driven economy остаются вне scope.

### Fixed

- Деревья теперь создаются только на подходящей травяной поверхности и не должны появляться в воде, на голом rock или на крутых обрывах.
- Опущен уровень Goblin/Cemetery lake и сформирован читаемый скальный берег вместо нависающей травяной полки.
- Исправлены social-assist edge cases при `Return` и lifecycle устаревших AI decisions.
- Исправлены poison/effect cleanup и защита от stale delayed mob actions.
- Исправлены устаревшие static UI contracts после перехода Combat Log и player HUD на общую `HudLayout.CornerMargin`.

## [0.1.0-dev.1] - 2026-09-18

### Added

- Реализован Milestone 1: ручная базовая атака с cooldown и коротким input buffer.
- Добавлен опциональный PvE AUTO только для базовой атаки.
- Добавлены классовые ресурсы Рыцаря, Следопыта и Мистика, критические удары и attack speed.
- Добавлены первые наборы умений трёх архетипов.
- Добавлен server-authoritative AI существ: passive/aggressive режимы, aggro, chase, leash, reacquire и обход низких препятствий.
- Добавлены смерть игрока, ручное возвращение в город и server-authoritative respawn.
- Добавлены combat log, action bar, target HUD и единая угловая HUD-сетка.
- Добавлен отдельный CP как подготовленный PvP-only слой, не расходуемый PvE-уроном.
- Добавлены desktop/gamepad/mobile combat contracts и Studio-only переключатель архетипов для тестирования.
- Усилена RemoteEvent validation и lifecycle cleanup серверных сервисов.

### Changed

- Свободный прыжок отключён; наземное перемещение остаётся доступным.
- Рыцарь получил небольшое преимущество базовой мобильности для входа в ближний бой.
- Штраф скорости Защитной стойки смягчён до -30%.
- Следопыт сохраняет отдельный ресурс FCS/Focus для будущего независимого баланса.

### Fixed

- Исправлены stale combat state после смерти/смены цели/respawn.
- Исправлены визуальная синхронизация target/attack state и повторный запуск атаки после respawn цели.
- Исправлена геометрия HUD относительно физических углов viewport.
- Исправлен lifecycle delayed mob respawn при остановке/перезапуске сервисов.

## [0.1.0-dev.0] - 2026-09-13

### Added

- Инициализирован проект Luna World.
