# Changelog

Все значимые изменения Luna World фиксируются в этом файле.

Формат основан на Keep a Changelog, версии проекта следуют Semantic Versioning с учётом того, что до `1.0.0` публичные интерфейсы ещё могут меняться.

## [Unreleased]

### Playtest RC — consolidated build

- Коррекция отката озера: предыдущий rollback к ранней 12-stud версии отменён. Озеро восстановлено ТОЧНО к owner-accepted состоянию PR #29 после `world: deepen lake basin and remove terrain overhang` (4ec5d6f) и его контрактов до начала `world: open lake to boundary...`: глубина 30, basin 40, margin 34, swimmable Terrain.Water, recessed hill-bank cliff; без world-edge extension и без prepareGoblinCampBoundaryShelf. GoblinShelfEdge также восстановлен как в этом состоянии.

- Озеро и lake-facing terrain откатаны к последнему принятому состоянию до серии экспериментов с расширением воды: восстановлены три исходных water-lobe, прежняя глубина 12, вертикальный hill-bank cliff/«стена» и старый shoreline; полностью удалены prepareGoblinCampBoundaryShelf, flat-slab/organic lake, искусственное дно Mud и все последующие расширения воды к границе карты. Остальные изменения dev0.3 сохранены.

- Чаша озера доведена до физически цельной геометрии: убрана воздушная канавка между водой и берегом, вода заходит под берег на небольшой overlap, а под всем водяным объёмом восстановлено непрерывное Mud-дно без воздушного кармана.

- Исправлен QuestMarker snapshot race после Character Lobby: QuestService при старте догоняет уже CharacterReady игроков, а клиент повторяет первый QuestSnapshotRequest до получения валидного snapshot; `!/?` над NPC больше не зависят от порядка запуска сервисов.

- Собрана единая playtest-сборка: Crafting World Pass, responsive mobile UI, Character Lobby, reordered LV1–14 mob route, Spider Hollow polish, swimming, lake/world-edge polish и full restore при level-up.
- Character Lobby дополнительно защищён для playtest: Roblox auto-spawn отключается до world bootstrap, Studio nickname index работает без включённого API Services, creation modal адаптирован под phone portrait и показывает результат проверки nickname внутри окна.
- Character Lobby теперь занимает весь viewport устройства; исправлен input-race, при котором `LastInputTypeChanged` мог перерисовать lobby между нажатием и `Activated` и визуально делать кнопку «Создать персонажа» нерабочей.
- Creation UX переработан: выбранные класс и пол теперь визуально фиксируются, Studio принимает любое непустое имя без TextService/боевого nickname-policy, а live nickname-pattern исправлен для обычных имён вроде `Astrafox` и `LookingFor`.
- Lobby переведён с горчичной палитры на холодную лунную сине-фиолетовую тему Luna World; незавершённые настройки UI/text/sound временно скрыты до отдельного прохода.
- Добавлена кнопка «Мой Roblox ник» и сохранена генерация случайного fantasy nickname.
- Spider Hollow использует непрерывные изогнутые terrain-ridges вместо отдельных куч.
- Озеро перестроено как единый глубокий swimmable water body с плоской поверхностью: вместо Terrain.FillCylinder-слайсов используются короткие перекрывающиеся FillBlock-секции на одной отметке воды; западный берег меандрирует, а весь water volume жёстко ограничен WorldBounds и больше не выходит за карту.
- Поднятая boundary-facing площадка Goblin Camp сохраняет высоту, но внутренний край переходит в длинный пологий terrain-склон вместо резкого обрыва.
- При фактическом level-up CP, HP и class resource полностью восстанавливаются до новых максимумов; обычный XP без повышения уровня refill не даёт.
- Исправлен Character Lobby → runtime bridge: выбранный archetype и nickname переносятся до первого spawn, CombatService больше не создаёт ранний default-knight state, RespawnService не спавнит персонажа до CharacterReady; nickname показывается в HUD и над персонажем.
- Инвентарь больше не затемняет весь экран: modal blocker оставлен только как невидимый input shield, а панель инвентаря сделана практически непрозрачной для чтения.
- То же правило применено ко всем gameplay-модалкам: торговец/кузнец, NPC dialogue, quest offer и travel confirm больше не используют fullscreen dark veil; EconomyUi переведён на sibling Z-order, чтобы текст и кнопки не попадали под собственный blocker.


### Changed

- Добавлен единый responsive layout для desktop, tablet и телефонов в portrait/landscape: HUD стал компактнее, модальные окна ограничиваются safe area, а торговля на узком экране переходит в вертикальный flow.
- Quest offer получил прокручиваемое описание и фиксированную доступную шапку/нижние действия; открытые модальные окна блокируют gameplay taps под собой.

### Added

- Добавлен предыгровой Character Lobby dev0.3: до пяти независимых персонажей аккаунта, выбор класса и типа тела, глобальная атомарная резервация nickname, безопасное подтверждение удаления и responsive creation flow.
- Persistent account schema поднята до `DataVersion = 3`; migration v2→v3 переносит весь прежний progression, Luna, inventory, equipment и quests в legacy-персонажа без потери данных.
- Lifecycle разделён на `AccountReady` и `CharacterReady`; Roblox character и gameplay-клиент не запускаются до server-authoritative выбора принадлежащего аккаунту героя.

- Реализованы четыре раздела кузнеца, переработка сырья и полные ранние No-Grade наборы Рыцаря, Следопыта и Мистика.
- LV6 crafting balance привязан к реальному маршруту Q2–Q5: ранние переработки и рецепты откалиброваны так, чтобы weapon + первая class armor были достижимы без скрытого фарма уровня LV9–10.
- Добавлены server-authoritative требования уровня, количество результата рецепта, стабильная сортировка и состояния доступности в интерфейсе.

### Changed

- Готовая классовая экипировка и обработанные материалы убраны из обычного ассортимента торговца; ранние рецепты теперь используют добычу маршрута Wolves → Spiders → Goblins.
- Goblin Shaman получил надёжный signature-drop Magic Dust для первого Mystic-рецепта; обычные crafting materials сохраняют пониженный drop-rate.
- Login starter-repair больше не переэкипирует учебное оружие поверх подходящего классу оружия; legacy mismatch автоматически исправляется.
- В двухпанельной продаже количество можно редактировать напрямую; Enter переносит/обновляет позицию и пересчитывает итог.

### dev0.2 — Economy usability / crafting planning

- Стартовое Newbie-оружие приведено к классовой схеме: Рыцарь — «Учебный меч», Следопыт — «Учебный лук», Мистик — «Учебный посох»; Studio-переключение класса теперь атомарно обновляет persistent archetype и экипирует соответствующее стартовое оружие.
- Продажа торговцу переведена на двухпанельную корзину «Инвентарь → К продаже»: игрок задаёт количество по каждой позиции, видит цену за штуку, subtotal и итоговую сумму до подтверждения.
- Массовая продажа выполняется одним server-authoritative atomic SellBatch, с валидацией payload и без частично проведённых продаж.
- Зафиксирован отдельный Crafting World Pass v0.2: классовые наборы, четыре вкладки кузнеца, переработка сырья и выравнивание рецептов по реальному уровню доступности материалов.

### dev0.2 — Playtest UX / chase / inventory pass

- Платный телепорт теперь требует отдельного подтверждения с названием локации и стоимостью в Luna; обратные маршруты явно показывают Luna Village.
- Горячие клавиши перенесены с конфликтующих Roblox-кнопок: инвентарь — `T`, журнал заданий — `Y`; карта остаётся на `M`, AUTO — на `G`.
- Последний слот панели действий зарезервирован под быстрый предмет `0`: лечебное/ресурсное зелье можно назначить из инвентаря кнопкой «НА [0]», а количество отображается прямо в слоте.
- Инвентарь получил фильтры «Зелья / Вещи / Ресурсы»; utility-consumables вроде свитка возврата относятся к «Вещам».
- Вероятность выпадения всех crafting-материалов уменьшена вдвое без изменения Luna, consumables и редкого gear-drop.
- Преследование моба теперь ограничивается расстоянием между мобом и его текущей целью, а не удалением моба от точки респауна: пока игрок не оторвался дальше `leashDistance`, моб может продолжать chase далеко от home; при превышении этой дистанции (в том числе после телепорта игрока) цель сбрасывается и моб возвращается домой. Застрявший на возврате моб через 150 секунд переносится в home.
- Свежий урон снова выводит возвращающегося моба в Aggro. Гоблинам расширены aggro/reacquire радиусы.
- Частокол Luna Village и Goblin Camp уплотнён до шага 4 studs и получил непрерывный невидимый collision-барьер. У лагеря сохранён один дорожный западный вход; низкий декоративный забор не возвращался.

### dev0.2 — Targeting / approach combat UX

- Goblin Camp targeting/approach work now coexists with a collision-sealed palisade and the authored road-side entrance.
- Manual basic attacks and enemy skills now keep the authoritative OutOfRange rejection feedback, then automatically approach the selected mob and execute the requested action once in range.
- Clearing the target cancels the approach immediately; desktop right mouse now issues the same semantic target-clear command while preserving normal camera input.
- When an untargeted player is hit by a mob, the server automatically selects that attacker as the player's current target.
- Out-of-range combat feedback now reads «цель слишком далеко».

### dev0.2 — Early combat + quest travel

- Young Wolf base damage increased from 8 to 12; player physical defense now mitigates proportionally instead of subtracting flat damage, preventing starter mobs from collapsing to the 1-damage floor.
- Wolf-family movement receives an additional ×1.25 multiplier on top of the global ×1.2 mob movement pass.
- Added quest-unlocked, server-authoritative paid travel: Luna Village ↔ Farm after «Волки у фермы» and Luna Village ↔ Moonfall Scout after «Стая у каменного круга».
- Travel prices are derived from four average direct-Luna kills in the destination tier (currently 8 Luna to Farm and 14 Luna to Moonfall).
- NPC dialogue now exposes unlocked travel destinations and reports insufficient-Luna / locked / unavailable failures.

### dev0.2 — Difficulty / progression / Spider Hollow pass

- Player progression cap restored to LV15; the current open world now spans LV1–14 and reserves LV15 for Ruins of Selene / Selene's Fallen Guardian.
- Late-game mobs were spread across the new level grid and received corresponding HP/defense/damage/XP increases.
- Goblin Chieftain now uses Sling Stone in addition to Battle Cry / Heavy Strike / Cleave and has 20% crit chance with ×1.80 critical damage.
- Goblin Shaman is now a true ranged magic support threat: ranged magic basic attack, stronger Spirit Bolt / War Chant, new Shaman Hex, and 12% ×1.60 crit.
- Added server-authoritative mob critical-hit support and a canonical `docs/MOB_BESTIARY.md` balance/ability reference.
- Resource regeneration was halved and updated more smoothly; player HP regeneration is now game-owned at 2/3 of Roblox's stock rate instead of relying on the default Health script.
- Spider Hollow was rebuilt as a depressed mud basin with raised terrain rims and a northern shoulder toward Fallen Shrine; hanging glass sheets were replaced by line-based spider webs.
- Removed the arbitrary western fence across the Spider Hollow approach and replaced it with deadwood/rock dressing.

### dev0.2 — Gameplay polish pass

- Expanded all Q1–Q7 quest descriptions and moved the young-wolf objective waypoint from the farmer to the wolf staging meadow.
- Rebalanced the combat action block after adding the quest journal button; current desktop bindings use `T` for inventory and `Y` for the quest journal.
- Mob target selection now aligns its forgiving screen-space pick area and physical hitbox with the visible silhouette.
- All mobs receive a 1.2× movement-speed multiplier for this tuning pass.
- Goblins have wider aggro/reacquire/social-assist radii; proximity aggro now alerts nearby members of the same social group.
- Goblin camp patrol pairs use authored perimeter pacing lanes, the shaman group stays inside the camp, and two mixed scout/warrior pairs were added to the interior.
- The goblin camp entrance was moved to the road-facing west wall; the accidental wolf-side opening is closed.

### dev0.2 — Quest UI polish

- Quest NPC dialog now opens a generic `Квест` topic before the dedicated quest offer window.
- Quest offer uses padded layout with centered title, description and accept/decline controls.
- Quest journal is collapsed by default, available from the action block and bound to `Y`.
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
- Подсказка инвентаря показывает актуальный binding для текущего устройства; desktop-инвентарь открывается по `T`.
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
