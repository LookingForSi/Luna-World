# Luna World — Loot, Craft и деревенская экономика v0.1

## 1. Назначение и границы

Этот блок является явным продуктовым исключением к прежнему запрету crafting в v0.1: Issue #13 утверждает узкую кузнечную систему без профессий, изучаемых рецептов, affix, enchantment и player trade. В текущем мире доступны только `Newbie` и `NoGrade`; rarity остаётся независимой характеристикой presentation.

`Newbie` — только три стартовых оружия (+3 профильной атаки), которые выдаются и экипируются один раз согласно активному архетипу. `NoGrade` — максимальная доступная ступень карты: три оружия (+6 профильной атаки), четыре общих части брони и аксессуар. Moonsteel, moonstring, moonveil и lunar sigil остаются stable future IDs, но не входят в loot, магазин или craft.

## 2. Каталог No-Grade

| Craft ID / предмет | Состав | Fee | Retail | Основной эффект |
|---|---:|---:|---:|---|
| `craft_weapon_iron_blade` | iron scrap 8, fang 3, token 2 | 50 | 351 | +6 P.Atk, Knight |
| `craft_weapon_hunter_bow` | iron scrap 4, silk 6, pelt 3 | 50 | 322 | +6 P.Atk, Ranger |
| `craft_weapon_rune_staff` | iron scrap 4, magic dust 6, relic 2 | 50 | 413 | +6 M.Atk, Mystic |
| `craft_armor_guard_head` | iron scrap 4, leather 2 | 30 | 174 | +4 P.Def, +8 HP |
| `craft_armor_guard_chest` | iron scrap 7, leather 5 | 55 | 339 | +8 P.Def, +18 HP |
| `craft_armor_guard_gloves` | iron scrap 3, leather 2, silk 2 | 25 | 183 | +2 P.Def, crit |
| `craft_armor_guard_boots` | iron scrap 3, leather 4 | 25 | 186 | +2 P.Def, +5 HP |
| `craft_accessory_silver_moon_charm` | magic dust 4, shard 2, relic 2 | 40 | 317 | +12 resource, crit |

Retail рассчитывается единственным правилом: `round((retail материалов + fee) × 1.30)`. Buyback равен `floor(retail × 0.60)`. Это исключает обе петли arbitrage; кузнец всегда дешевле покупки готовой вещи.

## 3. Материалы и маршрут

Существующие тематические материалы сохраняются. Добавляются только `material_iron_scrap`, `material_cured_leather` и `material_magic_dust`. Ранние волки дают pelt/fang/leather; Goblin Camp — token/iron; Spider Hollow — silk/venom; Dark Woodland — dire hide/leather; Cemetery — bone/iron; Shrine — relic/dust; Ancient Approach — shard/dust. Торговец продаёт каждый crafting material, поэтому RNG не создаёт жёсткую стену.

Natural-route профиль фиксирует 5 young wolves, 5 grey wolves и pack leader; 6 scouts, 3 warriors, shaman и chieftain; 5 spiders и brood; 4 dire wolves, 2 forest spiders и alpha; 4 skeletons, 2 archers и guardian; 3 acolytes и 2 shrine guardians; 3 sentinels, watcher и Warden. Expected-value контракт суммирует средние Luna, quantity × chance и 60% стоимости продаваемых излишков. Модель даёт около 116,7% стоимости Knight-комплекта (варианты archetype проверяются тем же диапазоном), а к уровню 6 должна обеспечивать хотя бы одно заметное upgrade. Готовый gear считается приятным rebate, но не обязательным ресурсом модели.

Обычный mob имеет 0,5–2% шанса подходящего No-Grade gear; сильный/elite — 3–8%. Gear выше `NoGrade` не obtainable.

## 4. Транзакции

Клиент отправляет только action и stable ID/instance ID/целое quantity. Сервер проверяет schema, rate limit, ready profile, живого персонажа, расстояние до authoritative POI, ownership, equipped state, capacity, материалы и Luna. Цена, состав и output берутся только из shared definitions.

Buy, sell и craft строят clone профиля через pure rules и публикуют его одной `PlayerDataService.mutate`; ошибка до commit не меняет профиль. Последовательная обработка Roblox event thread и повторная проверка актуального profile предотвращают double-spend. Продажа equipped item запрещена. Quantity — finite positive integer.

## 5. NPC и UI

`poi_merchant` и `poi_blacksmith` создают tagged interaction point с `ProximityPrompt`. Сервер открывает соответствующее окно только после собственной проверки расстояния. Merchant UI содержит stock, детали, grade, цену, Buy и отдельный список сумки с Sell. Blacksmith UI показывает весь каталог, stats, owned/required materials, fee и доступность Craft. Snapshot обновляется после каждой profile mutation.

## 6. Свиток возвращения

`consumable_scroll_return_luna` — stackable `ReturnToSettlement` effect. Сервер проверяет ownership и живого персонажа, получает tagged settlement anchor через общий respawn contract, затем атомарно списывает один предмет и переносит character. При отсутствии anchor предмет не списывается; отдельные координаты не хардкодятся.

## 7. Onboarding и progression

При первом достижении LV6 либо первом входе LV6+ клиент один раз за сессию показывает спокойную подсказку о кузнеце, продаже loot и покупке материалов/расходников. Persistence-флаг не добавляется. Newbie weapon остаётся достаточным для обычного маршрута; No-Grade облегчает LV6–9 и подготовку к Ancient Approach/Warden, но gear-score gate отсутствует.

## 8. Проверка и runtime acceptance

Pure tests покрывают grade, definitions, pricing/no-arbitrage, starter grant, atomic craft/trade, expected value и hostile inputs. Contract checks покрывают runtime wiring, POI distance, prompts, UI, onboarding и return anchor. Studio acceptance остаётся `DEFERRED — pending owner runtime acceptance` до ручного теста 1 server + 2 clients по checklist из implementation plan.
