# M5 — Party & Multiplayer Hardening — Design Specification

Дата: 2026-09-24  
Целевой baseline: `0.1.0-alpha.3`  
Tracking: GitHub Issue #76

## 1. Цель milestone

M5 добавляет минимальную, но production-oriented party-систему для текущего Moonfall gameplay и подготавливает стабильный контракт для следующего milestone M6 — Ruins of Selene.

После M5 два и более игрока в одном Moonfall server должны уметь:

1. создать party через invite;
2. видеть состав party;
3. совместно убивать mobs;
4. получать общий quest kill credit;
5. получать предсказуемо распределённые XP и loot;
6. переживать death/respawn участника без разрушения party;
7. корректно обрабатывать leave/disconnect;
8. не иметь возможности подделать membership/rewards через client Remote.

M5 — не social-system expansion. Он решает только то, что необходимо v0.1 Vertical Slice и будущему 1–4 player dungeon.

## 2. Scope и non-goals

### Входит

- максимум 4 участника;
- leader;
- invite / accept / decline / leave;
- server-authoritative party state;
- compact party HUD;
- простой экран/панель управления party и приглашениями;
- shared kill credit;
- XP split;
- single-roll round-robin loot;
- death/respawn lifecycle;
- disconnect cleanup;
- multiplayer security/validation;
- автоматические и ручные multiplayer checks.

### Не входит

- matchmaking;
- поиск группы;
- guild/clan;
- raid groups;
- roles / ready check;
- master loot;
- loot need/greed;
- party chat;
- PvP;
- player trade;
- persistent party между игровыми сессиями;
- cross-server/cross-Place party persistence;
- teleport группы в dungeon — это M6;
- переработка current mob ownership / contribution model.

## 3. Product rules

## 3.1 Party creation

Отдельной операции "Create Party" нет.

Party создаётся только когда первый invite принят:

- solo player A приглашает B;
- B принимает;
- сервер создаёт party;
- A становится leader;
- порядок участников: A → B.

Это не создаёт пустых party и уменьшает количество переходных состояний.

## 3.2 Membership

Один игрок может состоять максимум в одной party.

Максимальный размер party: **4**.

Party membership привязан к Roblox `Player.UserId`, а не к client-provided nickname или character object.

Party является server-session state. Ничего из party state не записывается в `AccountProfile`, `Profile` или DataStore.

Respawn не меняет membership.

## 3.3 Leader

Leader:

- может приглашать новых участников;
- не получает бонусов к rewards;
- не имеет отдельного gameplay authority.

Если leader выходит из party или отключается:

- leader становится первый оставшийся участник по устойчивому join order;
- revision party увеличивается;
- всем участникам отправляется новый snapshot.

Если после leave/disconnect остаётся один участник, party автоматически распускается. Оставшийся игрок становится solo.

Kick в M5 не нужен.

## 3.4 Invites

Только:

- CharacterReady player;
- находящийся в Moonfall gameplay runtime;
- solo player либо current party leader

может отправить invite.

Invite нельзя отправить:

- самому себе;
- игроку вне текущего server;
- игроку, который не CharacterReady;
- игроку, уже состоящему в другой party;
- если party inviter уже заполнена;
- если inviter состоит в party и не является leader.

Invite имеет server-generated `inviteId` и TTL **30 секунд**.

Client не сообщает partyId, leader status или membership. Он сообщает только намерение и целевой `UserId`/inviteId. Все остальные данные сервер выводит из собственного state.

Повторный invite той же паре в течение короткого cooldown не создаёт новый поток уведомлений. Рекомендуемый invite cooldown: 3 секунды на пару inviter→target.

Accept/decline после истечения TTL возвращают безопасный отказ и ничего не меняют.

При изменении состояния, делающем invite невалидным (party full, inviter больше не leader, target вступил в другую party, player ушёл), invite аннулируется.

## 4. Reward eligibility

Это ключевой M5 contract.

### 4.1 Базовое правило

Текущий `MobService` определяет credited killer по существующему last-attacker поведению. M5 **не** заменяет эту модель damage contribution системой.

Если killer solo — rewards сохраняют прежнее solo-поведение.

Если killer состоит в party — потенциальными получателями становятся party members.

### 4.2 Eligible member

Участник считается eligible для конкретной смерти mob, если одновременно:

- он всё ещё находится в `Players`;
- `PlayerDataService.isReady(player) == true`;
- является участником той же party на момент смерти;
- его character существует;
- humanoid жив: `Health > 0`;
- `HumanoidRootPart` существует;
- расстояние от root до death position mob не больше `PartyConfig.RewardRadiusStuds`.

Baseline радиус: **120 studs**.

Credited killer, если он удовлетворяет общим runtime требованиям, включается в результат. Никакой отдельной privilege для leader нет.

Если ни один party member не eligible, reward не должен быть ошибочно выдан далёкому/мёртвому игроку.

### 4.3 Kill context

`MobService.MobDied` должен передавать death position в дополнение к существующим данным.

Целевой совместимый contract:

```lua
MobDied:Fire(killer, mobId, entityId, deathPosition)
```

Старые listeners, принимающие меньше аргументов, в Luau не ломаются, но M5 listeners должны использовать position.

## 5. Shared quest credit

Для kill-objective каждый eligible party member получает один credit за смерть mob.

Нельзя выдавать credit:

- party member вне reward radius;
- мёртвому party member;
- игроку, вступившему в party уже после смерти mob;
- игроку из другой party;
- случайному helper вне party.

Идемпотентность существующего quest state сохраняется: одна смерть = максимум один increment конкретного objective на одного eligible player.

## 6. XP rules

M5 не добавляет party bonus.

Reward budget одного mob сохраняется.

Если eligible один:

- поведение эквивалентно solo.

Если eligible N:

1. `definition.rewardXP` делится между N;
2. целая часть выдаётся всем;
3. остаток распределяется в устойчивом party order, начиная с первого eligible участника;
4. каждому участнику его base share передаётся в существующий `ProgressionService.awardMobXP(player, share, mobLevel)`;
5. существующий level-difference modifier применяется индивидуально.

Пример:

- rewardXP = 41;
- 3 eligible;
- base = 13;
- remainder = 2;
- shares = 14 / 14 / 13.

Таким образом party не создаёт XP из воздуха. Баланс группового прохождения позже можно менять через отдельные explicit rules, но не в M5.

## 7. Loot rules

Loot table roll выполняется **один раз на смерть mob** — как и сейчас.

В party результат roll целиком назначается одному eligible player.

### 7.1 Round-robin

Party хранит только runtime cursor/order, необходимый для следующего loot owner.

На каждой reward-eligible смерти:

- сервер берёт устойчивый member join order;
- начиная после предыдущего loot recipient ищет первого eligible member;
- найденный member получает весь Luna + item result этой смерти;
- cursor переводится на следующую позицию.

Неeligible участники пропускаются, но не удаляются из party.

Если выбранный owner имеет полный inventory:

- существующая `InventoryFull` семантика сохраняется;
- item не перекидывается автоматически другому party member;
- Luna выдаётся владельцу обычным путём;
- reward не reroll-ится.

Это делает систему детерминированной и не позволяет манипулировать reroll через заполнение inventory.

Solo остаётся прежним: killer является loot owner.

## 8. Server architecture

Новые party boundaries должны быть отдельным feature, а не логикой внутри combat UI или persistence.

Рекомендуемая структура:

```text
src/shared/party/
├─ PartyRules.luau
├─ PartyTypes.luau
└─ PartyConfig.luau

src/server/features/party/
├─ PartyService.luau
├─ PartyNetworkService.luau
└─ KillCreditService.luau

src/client/features/party/
├─ PartyController.luau
└─ PartyUi.luau
```

Названия могут быть уточнены при реализации, но ownership должен остаться таким.

### 8.1 PartyRules

Pure logic:

- max size;
- membership transitions;
- leader transition;
- stable join order;
- XP split;
- eligibility helpers, не зависящие от Roblox Instances там, где это возможно;
- round-robin index/cursor logic;
- invite expiry decision.

Эта логика должна иметь Luau tests без Roblox multiplayer runtime.

### 8.2 PartyService

Authoritative runtime state:

```text
PartyRecord
- id
- revision
- leaderUserId
- memberUserIds[]       -- stable join order
- nextLootCursor
```

Также:

- mapping userId → partyId;
- pending invites;
- create-on-accept;
- add member;
- leave;
- disconnect cleanup;
- leader handoff;
- disband;
- reward member resolution;
- loot recipient selection.

Public API должен возвращать copies/snapshots, а не mutable internal tables.

### 8.3 PartyNetworkService

Единственная сетевой boundary party feature.

Он создаёт/использует Remotes и:

- валидирует тип action;
- валидирует payload;
- применяет rate limit;
- проверяет server-side state через PartyService;
- отправляет snapshot только тем клиентам, которым он положен;
- не доверяет client partyId/leader/member list.

Рекомендуемые semantics:

```text
PartyActionRequest
  Invite { targetUserId }
  Accept { inviteId }
  Decline { inviteId }
  Leave {}

PartySnapshot
PartyInviteReceived
PartyResult
```

Не обязательно создавать отдельный Remote под каждую кнопку.

### 8.4 KillCreditService

Один bridge от `MobService.MobDied` к reward consumers.

На событии смерти он формирует immutable kill context:

```lua
{
    killer = Player?,
    mobId = string,
    entityId = string,
    deathPosition = Vector3,
    eligiblePlayers = { Player },
    lootRecipient = Player?,
}
```

И публикует одно server-side event для consumers.

Цель: `LootService` и `QuestService` не должны независимо вычислять eligibility и потенциально расходиться.

### 8.5 LootService migration

`LootService` перестаёт напрямую считать, что единственный recipient = killer.

Он получает resolved kill context и:

- сохраняет existing rewardedEntityIds ledger;
- делит XP между eligible;
- делает один loot roll;
- выдаёт весь roll одному `lootRecipient`;
- публикует reward presentation каждому фактическому recipient.

Solo contract остаётся идентичным текущему.

### 8.6 QuestService migration

`QuestService` для `KillMob` слушает resolved kill context и вызывает существующий credit path для каждого eligible member.

ReachLocation / TalkToNpc и прочие objectives M5 не меняет.

## 9. Bootstrap order

Party должен стартовать до reward-resolution consumers.

Для Moonfall production target порядок концептуально должен быть:

```text
PlayerData
Progression
Combat
...
Mobs
PartyService
PartyNetworkService
KillCreditService
Loot
...
Quests
```

Точный порядок следует согласовать с существующим service graph и dependencies.

`DevCombined` должен получить тот же party feature через existing gameplay component, без отдельной несовместимой реализации.

`DungeonServerManifest` может подключить Party feature contract заранее только если это не создаёт ложную cross-Place поддержку. Полный party arrival/handoff делается в M6.

## 10. Client UX

M5 UI обязан быть functional и responsive, но не должен запускать новый большой mobile redesign.

### 10.1 Entry point

В gameplay action block появляется вторичное действие **«ГРУППА»**.

На desktop допустим keyboard shortcut, если он не конфликтует с текущими bindings.

На phone-landscape кнопка должна занимать место secondary action, а не вытеснять ATTACK или skill bar.

### 10.2 Party panel

Если player solo:

- показывает список доступных CharacterReady players текущего server;
- исключает самого player;
- напротив каждого есть «Пригласить»;
- после запроса показывается краткий result state.

Если player в party:

- leader отмечен;
- видны участники и уровни;
- leader может приглашать до лимита;
- любой участник может нажать «Выйти из группы».

Никакого kick/settings/loot-mode UI в M5.

### 10.3 Invite

Invite показывается как compact blocking dialog:

- nickname inviter;
- «Принять»;
- «Отклонить»;
- countdown необязателен, но expired invite должен исчезать/становиться неактивным.

### 10.4 Party HUD

Когда party существует, под текущим Player Status отображаются максимум три compact member rows.

Каждая row:

- nickname;
- LVL;
- HP bar;
- state `DEAD` при смерти;
- leader marker.

Не показывать CP/resource/XP других игроков.

UI читает membership из server snapshot, а live HP — из replicated character/humanoid state. Никакой authoritative gameplay state клиент не рассчитывает.

На phone-landscape строки должны быть компактнее desktop. Они не должны перекрывать target frame, attack cluster или Roblox Core UI.

## 11. Lifecycle

### Player death

- party membership не меняется;
- HUD показывает dead;
- dead member не получает kill rewards;
- после respawn снова становится reward-eligible при выполнении distance rule.

### Player disconnect

- pending invites с его участием удаляются;
- player удаляется из party;
- leader при необходимости передаётся;
- если остаётся один member — party disband;
- snapshots отправляются оставшимся.

### Service stop / Studio restart

- все connections disconnect;
- все pending timers/generation guards инвалидируются;
- runtime tables очищаются;
- повторный start не дублирует handlers.

## 12. Security contract

Все client actions считаются hostile input.

Обязательные отказы:

- неизвестный action;
- payload не table;
- targetUserId не number/integer;
- self invite;
- target не в server;
- target not CharacterReady;
- spoofed inviteId;
- expired invite;
- accept чужого invite;
- inviter no longer leader;
- party full;
- already in party;
- duplicate accept;
- invite spam;
- leave while solo.

Никакая ошибка клиента не должна вызывать:

- server exception;
- duplicate membership;
- party > 4;
- duplicate rewards;
- изменение party другого пользователя через spoofed ID.

## 13. Compatibility

M5 не меняет:

- persistence schema/DataVersion;
- character identity;
- archetype;
- combat damage authority;
- equipment;
- economy;
- world authoring;
- PlaceRole model;
- mobile baseline;
- current last-hit mob ownership.

Потребность в DataVersion bump отсутствует.

## 14. M6 seam

M5 должен оставить понятные read-only seams:

- получить party snapshot по Player/UserId;
- получить ordered memberUserIds;
- получить leaderUserId;
- определить, является ли набор players одной party.

M6 использует эти данные для подготовки party dungeon transfer.

M5 **не** должен сам сохранять party в DataStore или MemoryStore и не должен имитировать cross-server support.

## 15. Automated acceptance

Минимум:

- `PartyRulesSpec.luau`;
- `PartyRewardRulesSpec.luau`;
- `PartyRemoteValidationSpec.luau`;
- lifecycle/service tests или fixtures;
- contract test, что World/DevCombined manifests стартуют party dependencies в допустимом порядке;
- regression solo reward test;
- regression quest kill test;
- duplicate entity reward protection;
- cleanup test после leave/disconnect;
- start/stop idempotency.

Canonical repository test suite и canonical Rojo builds должны оставаться green.

## 16. Manual Roblox Studio acceptance

Минимум `1 server + 2 clients`, затем желательно `1 server + 4 clients`.

Проверить:

1. A приглашает B;
2. B видит invite и принимает;
3. оба видят party HUD;
4. A и B стоят рядом с mob;
5. kill даёт quest credit обоим;
6. XP budget делится;
7. loot owner меняется на следующей смерти;
8. B отходит дальше reward radius — следующую награду не получает;
9. B умирает рядом — не получает reward;
10. B respawn — party сохраняется;
11. B выходит из party — оба становятся solo;
12. party из 4 не принимает пятого;
13. leader disconnect передаёт лидерство;
14. repeated/malformed requests не ломают server.

## 17. Definition of Done M5

M5 считается закрытым, если:

- party 2–4 игроков формируется и распускается только сервером;
- membership и leader lifecycle корректны;
- shared kill/quest credit работает;
- XP не дублируется относительно mob budget;
- loot roll не дублируется и round-robin наблюдаем;
- dead/far players исключаются из reward;
- client не может spoof membership/reward;
- UI работает на desktop и принятом phone-landscape baseline;
- `1 server + 2 clients` manual smoke пройден;
- automated suite/builds green;
- docs/CHANGELOG обновлены перед следующим alpha checkpoint.

До manual acceptance версия не bump-ится автоматически: development остаётся поверх `0.1.0-alpha.3`. Следующий prerelease checkpoint формируется только после принятия M5.
