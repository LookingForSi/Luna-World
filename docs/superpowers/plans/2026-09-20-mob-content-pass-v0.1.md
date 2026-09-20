# План реализации Mob Content Pass v0.1

Дата: 2026-09-20
Основа: `feature/world-v01-m2-integration` (`e6c63b3`)
Целевая ветка: `feature/mob-content-pass-v01`

## Цель и границы

Населить authoritative-мобами весь открытый маршрут от Luna Meadows до Ancient Approach, переиспользуя combat, effects, XP, loot и persistence M2. Ruins of Selene не реализуется. Координаты принадлежат только `WorldLayout.SpawnMarkers`; клиент не принимает gameplay-решений.

## Этапы

1. **Baseline и документы.** Запустить доступные static checks, отдельно записать существующие ошибки; утвердить design и этот план.
2. **Shared content contracts.** Расширить типы мобов defense/rank/attack/abilities/social metadata; определить roster, ability catalog, XP, respawn и stable IDs; покрыть validation tests.
3. **Defense, effects и abilities.** Добавить общий physical/magic defense path для мобов и server-owned ability runner: ranged damage, DoT, cripple, non-stacking buffs и area damage. Проверять cooldown/range/liveness после windup.
4. **Social и patrol AI.** Подключить локальные `socialGroupId`, bounded assist, patrol metadata и переход Return → Idle → resume; сохранить single-flight decisions и stale-generation guards. Отдельно проверить cleanup/races.
5. **World population.** Заполнить Meadows/Wolf Pack/Road, Goblin Camp, Spider Hollow, Dark Woodland, Cemetery/Shrine и Ancient Approach; убрать совпадающие blockout placeholders до authoritative spawn.
6. **Loot/progression/presentation.** Дать каждому mob валидную table, тематические материалы, возрастающие Luna/XP и различимые primitive profiles без новых внешних assets.
7. **Стабилизация.** Запустить все доступные contract checks и Rojo builds; исправить только regressions pass, baseline-проблемы перечислить отдельно. Провести независимый review AI lifecycle/server authority и закрыть findings.
8. **Доставка.** Коммиты по завершённым batches, push feature branch, PR, final HEAD и единый owner checklist. Studio acceptance не объявлять пройденным без владельца.

## Автоматическая проверка

- `python3 tests/check_mob_content_pass_contract.py` — roster, population, social/patrol и authority wiring.
- Все `tests/check_*.py` по отдельности, чтобы import-style scripts не скрывали результат друг друга.
- Roblox/Luau specs через `test.project.json` в Studio: definition validation, damage types, AI state/return, cooldown/effect semantics и integration.
- `rojo build` для default/test/world проектов, если repository toolchain доступен.
- Проверить clean worktree и diff от `e6c63b3`.

## Риски и меры

- **Race после path yield/death:** один in-flight decision и comparison lifecycle generation.
- **Delayed ability после leash/death:** mob action generation и повторная проверка model/target/range.
- **Assist chain:** только одинаковый marker group и radius; Return/Dead не инициируют и не принимают помощь.
- **Duplicate respawn:** service generation, единственный death handler и проверка service state перед spawn.
- **Status leak/stacking:** generation replacement, weak player keys и восстановление authoritative attributes.
- **Стоимость AI:** decision intervals; pathfinding только на AI decision при необходимости движения, не каждый Heartbeat на каждого моба.

## Owner runtime checklist

Статус: **DEFERRED — pending owner runtime acceptance**.

Один play session, 1 server + 2 clients:

1. У фермы есть Young Wolves, они не social; Stone Circle содержит локальные wolf packs и leader.
2. Moonfall Road допускает обход противников и не образует стену.
3. Вокруг Goblin Camp движутся четыре отдельные пары patrol scouts; удар по одному зовёт только допустимого близкого партнёра.
4. Warrior применяет Sling Stone с паузой и затем способен перейти в melee.
5. Shaman применяет Spirit Bolt и War Chant без stacking; Chieftain показывает Heavy Strike, Cleave и Battle Cry.
6. В Spider Hollow соседний паук не агрится автоматически; Venom наносит конечный DoT, reapply обновляет его; Crippling Venom временно замедляет движение и атаку; Brood Spider читаемо крупнее.
7. Dark Woodland содержит wolves/spiders следующего tier и сохраняет читаемый маршрут.
8. Cemetery показывает melee Skeletons, ranged Archers и elite Guardian; Shrine — caster Acolytes и melee Guardians малыми группами.
9. Ancient Approach содержит Sentinels/Watchers; Warden использует минимум две читаемые способности и отличается наградой/respawn.
10. XP ведёт примерно 1→10 по маршруту; каждый тип выдаёт ожидаемые Luna/items, elite loot лучше, без гарантированного редкого предмета.
11. Обычные, uncommon и elite мобы respawn в своих диапазонах ровно по одному экземпляру.
12. После потери цели/leash мобы возвращаются, сбрасывают encounter и возобновляют patrol.
13. На двух клиентах HP, damage, effects, XP и loot согласованы; клиент не может ускорить cooldown или выбрать outcome.
14. Studio Output не содержит recurring errors; нет заметного FPS/server degradation, runaway pathfinding или зависших NPC.
