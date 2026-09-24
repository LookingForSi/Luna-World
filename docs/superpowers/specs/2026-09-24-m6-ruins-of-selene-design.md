# M6 — Ruins of Selene — Design Specification

Дата: 2026-09-24  
Tracking: GitHub Issue #79, release gate #63  
Baseline: принятый owner runtime-тестом M5 Party API (#76)

## 1. Цель и границы

M6 добавляет первый production-shaped instanced dungeon для 1–4 игроков в отдельном Place роли `Dungeon`. Полный маршрут: `Entrance → pack 1 → miniboss → pack 2 → Selene's Fallen Guardian LV15 → reward → Moonfall`.

Это greybox vertical slice на 8–15 минут. В M6 не входят art overhaul, matchmaking, guilds, PvP, trade, dungeon finder, procedural generation, difficulty modes, raid mechanics, сложные puzzles и системный rebalance mobs (#75).

## 2. Place и runtime ownership

- `projects/dungeon-selene.project.json` остаётся production mapping без Moonfall worldgen и Lobby UI.
- Каноническая роль сохраняет существующее имя `Dungeon`; dungeon identity — `selene` в конфигурации run/content.
- Moonfall runtime владеет входом и leader-authorized transfer; Dungeon runtime владеет admission, run, encounters, boss, rewards и exit.
- `DevCombined` поднимает отдельный локальный Selene runtime adapter без подмены production Place roles.

## 3. Run lifecycle

Серверный `DungeonRunService` хранит один run на reserved dungeon server:

`CREATED → ENTERING → ACTIVE → BOSS → COMPLETED → CLOSED`

и failure path `ACTIVE|BOSS → FAILED → CLOSED`.

Run содержит `runId`, ordered participant UserIds, leader UserId, timestamps/expiry, state, encounter index, gate state, boss phase/dead flag, arrived/disconnected sets и per-user reward claim keys. Переходы выполняются только серверными событиями. Client не получает Remote для открытия gate, убийства boss или completion.

Посторонний UserId не допускается. Duplicate arrival/rejoin одного participant идемпотентно возвращает существующую membership, но не создаёт новый run и не откатывает encounter.

## 4. Cross-Place handoff

M5 party остаётся session-state и source of truth в Moonfall. Leader получает immutable snapshot через публичный M5 API; solo использует snapshot из одного участника. Member в party не может начать transfer.

Moonfall создаёт reserved server и server-issued handoff версии 1: `runId`, leader, ordered members, source/destination roles, reserved server code, random nonce, issued/expiry timestamps. Полный contract сохраняется в MemoryStore с TTL; TeleportData несёт только lookup identity (`runId`, token, destination/schema), а не доверенное membership.

Dungeon атомарно валидирует/потребляет token, destination, TTL и membership. Token привязан к run, но arrival каждого ожидаемого UserId отмечается отдельно: повторная delivery безопасна, spoofed member/token/expired contract отклоняются. Registry сохраняет краткий rejoin ticket до run expiry; rejoin направляется в тот же reserved server. Handoff не является permanent party persistence.

Возврат использует новый server-issued handoff Dungeon → World с тем же ordered membership. World восстанавливает M5 party через выделенный trusted import API; если часть игроков не вернулась, party содержит только валидно прибывших участников и применяет обычные M5 leader/disband rules.

## 5. Entry validation

Вход — server-owned `ProximityPrompt`. До reserve/teleport проверяются: `CharacterReady`, отсутствие conflicting transfer/run, размер 1–4, leader authority, неизменность party revision/snapshot и присутствие каждого member в server. Client не передаёт runId или список участников и не телепортирует другого игрока.

## 6. Greybox и progression

`DungeonWorldService` создаёт только детерминированный greybox Selene: safe spawn, две combat rooms, miniboss chamber, final arena и exit. Полы физически закрыты; маршрут читается светом/цветом/коридорами.

`DungeonEncounterService` сопоставляет authoritative spawn groups с последовательностью:

1. pack 1 dead → gate 1 open;
2. miniboss dead → gate 2 open;
3. pack 2 dead → final gate open и boss activation;
4. boss dead → exit/reward enabled.

Gate collision/visibility меняет только сервер. Mob deaths принимаются по уникальному entityId ровно один раз.

## 7. Mobs и boss

Roster data-driven: Selene Warden (melee), Selene Acolyte (ranged magic), Ruin Sentinel (elite/miniboss), `selenes_fallen_guardian` LV15. Они используют существующие `MobService`, AI, combat и M5 shared kill/reward path.

Guardian имеет server-authoritative state machine:

- `BASE`: обычная target attack;
- `TELEGRAPH`: сервер публикует presentation danger zone и фиксирует origin/radius/deadline;
- `IMPACT`: сервер повторно проверяет живых participants и расстояние, затем наносит damage;
- `ENRAGED`: один переход при HP ≤ 35%, усиливающий damage/cadence.

Target выбирается только среди живых присутствующих participants; смерть/disconnect цели вызывает retarget. `bossDead` latch обеспечивает один kill/completion.

## 8. Death, wipe и rejoin

Individual death использует существующий respawn lifecycle и возвращает игрока на последний открытый checkpoint текущего run. Принято простое правило wipe: если все подключённые participants мертвы одновременно, текущий encounter сбрасывается сервером (mobs/HP/boss phase), прогресс завершённых encounters сохраняется. Reward/completion latch никогда не сбрасывается.

Disconnect оставляет membership до TTL. Быстрый rejoin по registry возвращает participant в тот же reserved server/run; после expiry/close безопасный fallback — Moonfall. Leader disconnect не отменяет run; operational leader выбирается по M5 stable order среди присутствующих.

## 9. Completion и rewards

Первый валидный death Guardian атомарно переводит run в `COMPLETED`. Для каждого participant создаётся стабильный claim key `runId:userId`. Reward service один раз выдаёт XP, Luna и один Selene reward item через существующие progression/economy/inventory APIs. Повтор boss event, rejoin, Remote replay или повторный claim возвращает прежний результат без повторной mutation.

Boss обычный loot roll не дублирует completion reward: его definition не содержит дополнительную generic reward table. Party semantics используют M5 eligibility там, где выдаются обычные mob rewards.

## 10. Security и observability

Все входные payload проходят strict type/finite/integer/length checks и per-player throttling. Run/gate/completion APIs не экспонируются клиенту. Server logs содержат reason codes без token/nonce. Тесты покрывают spoofed run/member/token, expiry, duplicate arrival/completion/kill/claim, malformed values, stale entity events и попытку member инициировать party transfer.

## 11. Acceptance status

Automated checks и canonical builds являются обязательным gate. Studio/published teleport, solo и `1 server + 2 clients` проверки имеют статус **DEFERRED — pending owner runtime acceptance**. До owner acceptance M6 описывается только как «готов к owner review», но не как завершённый milestone.
