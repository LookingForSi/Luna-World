# Luna World — план Loot, Craft и деревенской экономики v0.1

## Baseline

- Исходный HEAD: `0cd2a6e` (`feature/mob-content-world-polish-integration` из FETCH_HEAD).
- 16 из 19 Python contracts проходят; три существующих UI contract падают из-за drift CombatLog/ActionBar.
- `rojo` отсутствует в PATH; четыре baseline build отложены до установки toolchain.

## Batch 1 — shared contracts (TDD)

1. Расширить `ItemTypes` grade и return effect; определить цены всех предметов.
2. Добавить `CraftingDefinitions`, `MerchantDefinitions`, `EconomyRules`, `EconomyBalance`.
3. Добавить pure tests grade, recipes, pricing/no-arbitrage и natural-route EV.
4. Перенастроить obtainable loot на No-Grade и умеренные drop chances.

## Batch 2 — profile и starter

1. Добавить pure idempotent `StarterGearRules` без изменения DataVersion.
2. При ProfileReady выбрать оружие по persisted archetype, выдать и экипировать при отсутствии starter stable ID этого архетипа; уже принадлежащий игроку правильный starter экипировать без второй выдачи.
3. Покрыть новый/существующий профиль, каждый archetype и повторный вызов.

## Batch 3 — authoritative economy

1. Добавить pure clone-based buy/sell/craft rules.
2. Создать `EconomyService` с одним atomic profile commit на transaction.
3. Создать `EconomyNetworkService`: strict action schema, integer quantity, per-player rate limit, profile/life/distance validation.
4. Добавить remotes во все Rojo projects и hostile request contracts.

## Batch 4 — return, NPC и UI

1. Расширить consumable dispatcher data-driven `ReturnToSettlement` и использовать общий tagged spawn anchor.
2. Добавить merchant/blacksmith interaction points около существующих POI.
3. Реализовать `EconomyController` и единый Village Economy UI с merchant/craft режимами.
4. Отобразить grade в Inventory и economy UI, причины отказа и актуальные balances.

## Batch 5 — onboarding, stabilization и документация

1. Добавить session-local LV6 toast на Profile snapshot/level attribute.
2. Выполнить все Python contracts по одному, Luau suite через test build, четыре Rojo build.
3. Обновить `ARCHITECTURE.md`, `GAME_DESIGN_V0.1.md`, `ROADMAP.md`, `CHANGELOG.md` как утверждённое исключение Issue #13.
4. Провести независимый transaction/security review, исправить findings и повторить relevant checks.

## Owner runtime checklist

Статус: **DEFERRED — pending owner runtime acceptance**.

1. Fresh Knight/Ranger/Mystic получает и сразу использует своё newbie weapon; повторный вход не дюпает его.
2. Newbie weapon даёт +3–4, No-Grade weapon +5–7 профильной атаки.
3. Ранние kills дают материалы и Luna; ready gear выпадает редко и только No-Grade.
4. Merchant/blacksmith не открываются издалека, открываются рядом с правильным NPC.
5. Buy material, potion и return scroll; sell loot получает около 60% retail.
6. Equipped/foreign item и invalid quantity продать нельзя.
7. Craft без ресурсов/full inventory отклоняется без потерь; успешный craft списывает ровно один набор и fee.
8. Готовый gear у merchant примерно на 30% дороже material+fee пути.
9. Scroll у живого игрока списывается один раз и переносит к Luna Village anchor; у мёртвого не расходуется.
10. На LV6 подсказка появляется один раз за сессию.
11. Natural run даёт ресурсы на полный active-archetype No-Grade set без чрезмерного grind.
12. Ancient Approach/Warden остаются проходимыми с newbie weapon, а No-Grade ощутимо помогает.
13. В 1 server + 2 clients нет duplication, negative Luna, stale UI и recurring Output errors.
