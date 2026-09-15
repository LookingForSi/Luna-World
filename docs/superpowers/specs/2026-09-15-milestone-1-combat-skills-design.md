# Luna World — Milestone 1: Combat & Skills — draft-спецификация дизайна

Дата: 2026-09-15
Статус: **draft, требуется утверждение владельцем**
Область: Milestone 1 — Combat & Skills
Следующий документ после утверждения: отдельный implementation plan

## 1. Назначение и границы решения

Milestone 1 должен превратить технический combat loop Milestone 0 в небольшой, но цельный PvE-бой: игрок вручную задаёт ритм базовых атак, применяет первые умения, расходует ресурс, получает читаемый ответ мира, а несколько типов мобов способны самостоятельно войти в бой, преследовать игрока и вернуться домой.

Спецификация фиксирует gameplay- и network-контракты, но не является планом реализации. До явного утверждения владельцем по ней нельзя начинать implementation planning или gameplay implementation.

Luna World остаётся самостоятельной игрой. Упоминание классических MMORPG описывает только темп и ощущение target-based боя; нельзя переносить названия, интерфейс, анимации, модели, звуки, lore или иные защищённые элементы Lineage II либо другой игры.

## 2. Зафиксированные продуктовые решения

Эти решения не являются предметом пересмотра в рамках данной спецификации:

1. Бой — target-based old-school MMORPG combat.
2. Основная базовая атака требует ритмичного ручного input: `удар → cooldown → удар`.
3. Сервер авторитетно определяет cooldown и результат действия.
4. Перед завершением cooldown действует короткий input buffer.
5. В PvE ручная атака является основным режимом; autoattack — необязательное удобство.
6. В будущем PvP не будет autoattack: только ручной запрос каждой атаки. Сам PvP не входит в v0.1.
7. Обычный свободный jump не является частью Luna World. Мир строится для наземного перемещения по дорогам, склонам и лестницам.
8. На mobile стандартная Jump button должна быть убрана, а главной кнопкой справа станет крупная собственная Attack button.
9. Финальные balance values и финальный art не определяются в Milestone 1.

## 3. Термины и единый combat pipeline

- **Intent** — недоверенный запрос клиента совершить действие, а не сообщение о результате.
- **Accepted action** — действие, прошедшее серверную проверку и занявшее разрешённое место в cadence/buffer.
- **Resolve point** — серверный момент, когда повторно проверяются условия и применяются damage, heal или effect.
- **Recovery / cooldown** — серверный период, запрещающий следующее использование соответствующего действия.
- **Selected target** — подтверждённая сервером текущая цель игрока.
- **Home point** — серверная точка, к которой mob возвращается после leash.
- **Combat context** — как минимум `PvE`; будущий `PvP` должен явно запрещать autoattack, но не реализуется сейчас.

Все базовые атаки — ручные, созданные PvE-autoattack или будущие PvP — проходят один серверный pipeline:

`intent/source → validation → optional buffer → accept → wind-up/presentation hook → resolve validation → outcome → recovery/cooldown → ready`

Autoattack не имеет отдельной формулы damage, отдельного cooldown или обхода validation. Это только серверно контролируемый источник следующих basic-attack intents для PvE.

## 4. Combat state и контракты состояния

### 4.1. Состояние combatant

Для каждого player и mob сервер хранит только необходимое runtime-состояние:

- alive/dead;
- выбранная цель, если combatant поддерживает выбор цели;
- текущая accepted action и её временные границы;
- следующий допустимый момент по cooldown group;
- не более одного buffered basic-attack intent;
- текущие HP и combat resource;
- активные эффекты Milestone 1 с серверным временем окончания;
- PvE-autoattack mode для player;
- признаки, запрещающие действие: смерть, respawn transition и предусмотренный skill-control effect.

Это transient state. Оно не добавляется в persistent schema Milestone 1. Progression, inventory и equipment позднее предоставят combat-системе рассчитанный stat snapshot через узкий interface, но CombatService не должен владеть этими системами.

### 4.2. Наблюдаемое состояние клиента

Клиент может получить только данные, нужные для UI/presentation:

- подтверждённую selected target;
- authoritative HP/resource и их пределы;
- accepted/rejected action feedback;
- server timestamps начала/resolve/окончания cooldown, либо эквивалент, позволяющий согласованно рисовать HUD;
- combat outcome events для animation/FX/UI;
- включён ли PvE-autoattack mode.

Клиентская полоса cooldown и локальный animation anticipation не дают права применить результат. При расхождении клиент корректируется сервером.

### 4.3. Состояния действия

Минимальные состояния: `Ready`, `WindUp`, `Recovery`. `Buffered` — слот ожидающего intent, а не параллельно выполняемое действие. Не требуется универсальная combo/ability state machine.

Одновременно combatant не может выполнять две несовместимые accepted actions. Конкретный skill definition указывает, блокирует ли он basic attack на wind-up; по умолчанию блокирует. Global cooldown вводится только если его отдельно утвердит владелец; базовый контракт использует cooldown конкретного action и явно названные cooldown groups.

## 5. Жизненный цикл базовой атаки

1. Игрок выбирает валидную цель через существующий target intent.
2. Игрок нажимает Attack. Один physical press создаёт один manual basic-attack intent; удержание не превращается в autoattack силами клиента.
3. Сервер проверяет форму/rate запроса, состояние игрока, цель и момент cadence.
4. Если атака уже доступна, сервер принимает действие. Если cooldown почти завершён, сервер занимает единственный buffer slot. Слишком ранний запрос отклоняется без изменения cooldown.
5. В начале accepted action сервер публикует animation/FX hook, но ещё не доверяет положению цели до resolve.
6. В resolve point сервер повторно проверяет alive/state, target, range и facing, затем рассчитывает hit/crit/damage и применяет результат ровно один раз.
7. Сервер публикует подтверждённый outcome. Recovery/cooldown продолжает считаться по серверному времени независимо от частоты клиентских запросов.
8. Когда cadence разрешает следующую атаку, buffered intent, если он существует и всё ещё валиден, потребляется один раз.

Cooldown не начинается заново из-за rejected/spam request. Отдельный press после заполнения buffer не создаёт очередь из нескольких атак.

### 5.1. Сетевой смысл manual request

Milestone 1 меняет смысл `AttackRequest`:

```text
AttackRequest()
```

Событие означает: «попробовать выполнить одну базовую атаку по моей подтверждённой selected target». Оно не принимает `active`, damage, range, timestamp, facing, attack speed или target-owned Instance. Сервер сам находит player combat state и selected target.

Повтор, replay или высокая частота запросов не могут ускорить cadence. Network rate limit защищает сервер от spam отдельно от gameplay cooldown и не должен служить самой механикой cooldown.

### 5.2. Input buffer

- Buffer принимает только следующий manual basic-attack intent, поступивший в настраиваемое короткое окно до `readyAt`.
- Working range для playtest: примерно **100–250 ms**; конкретное значение — tuning decision.
- На игрока существует максимум один такой intent. Более новый request не создаёт очередь и по умолчанию не продлевает срок жизни уже занятого slot.
- Buffered intent привязан к выбранной цели в момент запроса. Смена/потеря цели очищает buffer: скрыто переносить удар на другую цель нельзя.
- Buffer очищается при смерти, respawn, disconnect, входе в запрещающее действие/состояние и выключении соответствующего режима.
- На момент исполнения выполняется полная повторная validation. Невалидный intent удаляется без damage и без автоматического ожидания возвращения цели в range.
- Сервер может сообщить `Buffered`, `Accepted` или причину rejection для UI, но клиент не должен симулировать подтверждённый hit.

### 5.3. PvE-autoattack

PvE-autoattack включается и выключается отдельным явным intent, концептуально:

```text
AutoAttackModeRequest(enabled: boolean)
```

Контракт режима:

- доступен только в серверно подтверждённом PvE context;
- выключен по умолчанию, пока playtest/owner decision не утвердит иной UX;
- не подменяет manual Attack button и не генерирует client Remote spam;
- сервер инициирует очередную попытку basic attack через тот же pipeline, когда cadence готов;
- manual input имеет приоритет для ощущения ритма, но не добавляет второй hit к тому же cadence;
- out-of-range цель не получает damage; режим может оставаться включённым во время краткого chase игроком, но не двигает персонажа автоматически;
- target change требует новой server validation; death/respawn, потеря target, переход из PvE context или явное выключение прекращают режим;
- будущий PvP context безусловно отклоняет включение режима и не создаёт автоматические intents.

Точный UX включения autoattack (отдельный toggle, long press или настройка) требует owner decision. Он не должен делать случайный double-tap неявным постоянным режимом.

## 6. Validation: цель, дистанция, facing и cooldown

Каждый action request проверяется на сервере при приёме, а изменяемые пространственные условия — повторно в resolve point.

Обязательные проверки:

- shape/type и допустимая частота Remote;
- player существует, его текущий character жив и не находится в respawn transition;
- action/skill ID известен и разрешён выбранному archetype;
- selected/explicit target существует, разрешён типом target policy, жив и принадлежит текущему world/session context;
- action не запрещён текущим state/effect;
- cooldown group готов либо manual basic intent попадает в buffer window;
- достаточно authoritative resource;
- server-measured range между согласованными combat origins не превышает definition range;
- server-measured facing удовлетворяет definition policy;
- действие допустимо в текущем PvE context.

### 6.1. Range

Каждый action использует собственную data-driven range category/значение. Melee, ranged и magic basic attack не обязаны иметь одинаковую дистанцию. Допуск на latency/размер модели должен быть малым server-side tuning parameter, единым для соответствующей категории, а не присланным клиентом.

### 6.2. Facing

Target-based действие использует горизонтальное направление от server-known attacker origin к target origin. Вертикальный уклон не должен ложно ломать facing на обычных дорогах/склонах.

Сервер может довернуть персонажа к выбранной цели в разрешённых пределах gameplay presentation, но не принимает client-supplied facing как доказательство. Working cone для playtest следует выбирать в диапазоне примерно **90–140° полного угла** в зависимости от категории; точные значения и поведение hard snap — tuning/UX decisions. Вне cone действие не resolve и возвращает понятную причину.

### 6.3. Cooldown

Authoritative time хранится сервером как `readyAt` на action/cooldown group. Клиентские часы не участвуют в eligibility. Resource списывается ровно один раз при принятии action либо в resolve point согласно единому утверждённому правилу; при server-cancel применяется явно заданная refund policy, а не ad hoc исключение.

## 7. Interruption и cancel

Milestone 1 различает:

- **rejection до accept** — action не началось, resource/cooldown не расходуются;
- **hard interrupt после accept** — смерть attacker, despawn/session removal или специальный interrupt effect отменяют нерешённое действие;
- **resolve failure** — target умер, исчез, сменил context, вышел из range/facing; outcome не применяется;
- **player cancel** — разрешён только там, где это явно указано skill definition; basic attack после accept вручную не отменяется;
- **movement** — само по себе не отменяет basic attack, но итоговая range/facing validation всё равно действует. Skills могут явно требовать stationary cast.

По умолчанию при interrupt/resolve failure cooldown остаётся занятым после accept, чтобы request spam не давал бесплатный перебор. Resource refund policy (`None`, `FullBeforeResolve`) задаётся определением; рабочий default для первых skills — полный refund только при server-caused hard interrupt до resolve, но это требует owner approval.

Смерть/respawn очищает текущую action, buffer, target, autoattack mode, временные эффекты и pending presentation tokens. Shield Bash может получить interrupt/control effect только после отдельного утверждения его контракта; универсальная crowd-control система здесь не проектируется.

## 8. Resource и минимальная модель stats

### 8.1. Resource model

Минимум содержит `Health` и один `CombatResource` с `Current/Max`. Сервер владеет расходом и восстановлением. Basic attack не расходует resource. Активные skills используют фиксированную data-driven cost; при нехватке skill отклоняется.

Рекомендуемый для v0.1 вариант: единый механический ресурс для всех archetypes с различным display name/presentation при необходимости. Это позволяет проверить pacing без трёх независимых resource systems. Владелец должен подтвердить, расходуют ли Knight/Ranger тот же восстанавливаемый pool, что и Mystic, и нужен ли им отдельный display name.

Passive regeneration допустима как простая server-authoritative cadence вне/в бою с data-driven rate. Consumables, item-based regeneration и persistence ресурса не входят в Milestone 1.

### 8.2. Минимальные stats

Combat snapshot Milestone 1:

- `MaxHealth`, `CurrentHealth`;
- `MaxResource`, `CurrentResource`, `ResourceRegen`;
- `PhysicalAttack`, `MagicAttack`, `PhysicalDefense`;
- `AttackSpeed`;
- `CritChance`, при необходимости единый `CritMultiplier` из combat config;
- `MovementSpeed` как внешний input для Mob chase/player movement, но не часть damage formula.

Не вводятся accuracy/evasion, armor penetration, elemental resistances, haste tiers, attributes наподобие STR/DEX/INT или сложная таблица derived stats. Milestone 2 сможет поставлять snapshot от progression/equipment без смены action contract.

## 9. Attack speed и crit

### 9.1. Attack speed

Attack speed изменяет только cadence базовой атаки, а не cooldown активных skills, cast time, movement или число hits. Рекомендуемая семантика:

```text
effectiveInterval = baseAttackInterval / attackSpeedMultiplier
```

Multiplier нормализован вокруг `1.0` и ограничивается server-side min/max caps. Base interval задаётся archetype/basic-attack definition. Конкретные base intervals, caps и источники AttackSpeed являются tuning/content decisions.

Animation playback получает effective interval как presentation hint, но animation length не определяет серверный resolve. Изменение stat во время recovery не должно ретроактивно создавать мгновенный дополнительный удар; новая скорость применяется к следующему принятому cadence boundary по единому правилу.

### 9.2. Crit

Crit roll выполняется сервером один раз на каждый eligible damaging resolve. Клиент получает только подтверждённый outcome. Минимальная формула:

```text
criticalDamage = normalResolvedDamage * critMultiplier
```

`CritChance` имеет server-side bounds. Heal, periodic effects и control effects не crit, если definition явно не разрешает это; для первых skills рекомендуется разрешить crit у прямых damaging hits и запретить у Heal. Crit multiplier, caps и наличие crit у каждого skill остаются tuning decisions. Для детерминированных тестов RNG передаётся через тестируемую границу, а не управляется клиентом.

## 10. Skill definition schema

Definitions являются data-driven и используют стабильные English IDs. Display names рабочие и не служат идентификаторами. Концептуальный минимальный schema:

```text
SkillDefinition
  Id: string
  ArchetypeId: string
  DisplayName: string
  ActionType: "Basic" | "Skill"
  TargetPolicy: "Enemy" | "Self" | "FriendlyOrSelf" | "EnemyArea"
  RangeCategory / Range: tuning reference
  FacingPolicy: "TargetCone" | "None"
  WindUp: tuning reference
  Cooldown: tuning reference
  CooldownGroup: string
  ResourceCost: tuning reference
  ScalingSource: "PhysicalAttack" | "MagicAttack" | "None"
  EffectContract: stable effect descriptor
  CanCrit: boolean
  MovementPolicy: "Allowed" | "Stationary"
  InterruptPolicy: explicit flags
  RefundPolicy: "None" | "FullBeforeResolve"
  PresentationKey: string
```

Schema не должен превращаться в универсальный scripting framework. Первые effects реализуют только реально нужные операции: direct damage, direct heal, короткий approved control, timed self modifier, timed attack-speed modifier, timed movement slow и небольшой targeted AoE.

Authoritative coefficients/values могут оставаться server-only. Клиенту реплицируется безопасный presentation subset: display, icon key, приблизительная usability, authoritative cooldown timing и resource cost. Клиент не выбирает effect payload.

## 11. Контракты archetypes и первых skills

Все названия ниже рабочие. Числовой balance определяется позднее.

### 11.1. Knight

- **Basic melee attack** — single-target physical damage; короткая melee range; cadence зависит от AttackSpeed; движение разрешено при обязательной resolve validation.
- **Power Strike** — более сильный single-target physical hit в melee range; расходует resource; самостоятельный cooldown; может crit.
- **Shield Bash** — single-target melee physical hit с коротким interrupt/control rider. До owner decision безопасный baseline — interrupt текущего interruptible wind-up без длительного stun. Duration/immunity и применимость к boss требуют отдельного решения.
- **Defensive Stance** — self-only timed defensive state: повышает survivability ценой offensive/mobility trade-off. Рекомендуемый минимальный вариант — конечная duration + cooldown, а не toggle с upkeep, чтобы не вводить отдельную stance lifecycle. Точный trade-off требует owner decision.

### 11.2. Ranger

- **Ranged basic attack** — single-target physical damage на дальней дистанции; требует target facing и line/range validation; projectile FX не является authority и не решает попадание.
- **Power Shot** — усиленный single-target ranged physical hit с wind-up; расходует resource; может crit.
- **Rapid Shot** — рекомендуемый минимальный контракт: timed self buff к AttackSpeed базовых атак с cap, без multishot и без изменения skill cooldowns. Duration/bonus/cooldown — tuning.
- **Snare** — single-target ranged effect: небольшой direct damage опционален, основной результат — временное server-authoritative снижение MovementSpeed моба. Не root; повторное применение использует простое правило refresh или reject, требующее owner decision.

### 11.3. Mystic

- **Magic basic attack/cast** — single-target magic damage; имеет читаемый wind-up; cadence зависит от AttackSpeed; визуальный projectile не определяет hit.
- **Arcane Bolt** — быстрый single-target magic damage skill; расходует resource; может crit.
- **Flame Burst** — targeted enemy-centered small AoE magic damage. Сервер выбирает victims в утверждённом радиусе и world/session context; клиент не присылает список целей. Radius и target cap — tuning values.
- **Heal** — direct heal с `FriendlyOrSelf` target policy; не воскрешает, не превышает MaxHealth и по умолчанию не crit. Нужно owner decision, разрешать ли в Milestone 1 heal любого nearby player или только self (party eligibility появится позднее).

## 12. Mob AI

### 12.1. Обязательная state machine

```text
Idle → Aggro → Chase → Attack → Return → Idle
```

- **Idle** — mob жив, находится у home point/в допустимой roaming области и периодически ищет eligible PvE target.
- **Aggro** — сервер атомарно выбирает/подтверждает target и фиксирует начало encounter; это короткий переход, а не длительная параллельная логика.
- **Chase** — mob движется к target, пока target валиден и достижим в пределах leash.
- **Attack** — mob останавливается/держит допустимую дистанцию и создаёт server-owned attack intents через общий combat pipeline. При выходе target из range возвращается в Chase.
- **Return** — mob сбрасывает combat target/effects согласно reset policy, не принимает новый обычный aggro и возвращается к home point. По прибытии полностью восстанавливается согласно утверждённому reset policy и входит в Idle.

Переходы не должны существовать как несколько конкурирующих loops. State machine имеет один authoritative owner и cleanup token/generation для despawn/death.

### 12.2. Aggro, chase и leash

- Aggro radius, attack range, chase speed, leash distance/time и think interval задаются mob definition/config.
- Target eligibility проверяет alive player, PvE context, safe-zone/world/session ограничения и дистанцию.
- При нескольких целях Milestone 1 использует простое детерминируемое правило (например, ближайший eligible target). Полная threat table не требуется.
- Leash измеряется от home point, а не от последней позиции target. Допустим дополнительный timeout для недостижимой цели.
- При недоступном/умершем/disconnected target mob выбирает другого eligible target только по явно утверждённому простому правилу либо переходит в Return; сложная threat persistence не нужна.
- Pathfinding cadence ограничена; mob не пересчитывает path каждый frame.

### 12.3. Mob death и respawn

При достижении `0 HP` сервер один раз переводит mob в Dead lifecycle, отменяет AI/action/effects, публикует death hook и уведомляет будущие reward interfaces. Клиент не запрашивает death или respawn.

После data-driven respawn delay MobService создаёт/сбрасывает ровно один экземпляр с новым runtime lifecycle token, исходным home point, полным HP и Idle state. Reward/loot details принадлежат Milestone 2; Milestone 1 оставляет только idempotent `MobDefeated` interface с attacker/contributor context, достаточным для будущей интеграции.

Milestone 1 должен содержать несколько definition-driven mob variants, различающихся хотя бы melee/ranged поведением, stats и aggro/leash tuning, но финальные названия, состав и balance остаются content decisions.

## 13. Player death и respawn

Player death определяется сервером при `0 HP` и обрабатывается идемпотентно:

1. запрет новых combat actions;
2. cancel accepted/pending actions, buffer, target и PvE-autoattack;
3. очистка transient combat effects и связей AI с умершим target;
4. публикация death presentation hook;
5. переход через Roblox character lifecycle к утверждённой respawn location;
6. пересоздание чистого combat runtime state без дублированных connections/tasks;
7. восстановление HP/resource согласно respawn policy и возврат управления.

Death penalty, XP loss, item loss, corpse run, resurrection и persistent consequence не входят в Milestone 1. Рабочий v0.1 default — короткий server-controlled respawn delay и восстановление в безопасной точке без штрафа; точка, delay и процент восстановления являются tuning/world decisions.

## 14. Animation, FX и UI hooks

Milestone 1 задаёт события, но не финальные assets:

- `ActionAccepted` — actor, action/skill ID, action token, server timing, presentation key;
- `ActionResolved` — token, target(s), outcome type, amount category/value для разрешённого UI, crit flag;
- `ActionInterrupted` / `ActionRejected` — token/request context и ограниченный reason code;
- `EffectStarted` / `EffectEnded` — presentation key и server timing;
- `CombatantDied` / `CombatantRespawned`;
- mob state presentation hints, где они нужны для telegraph/readability.

Hooks не содержат asset IDs как gameplay contract. Пропущенный FX, поздняя animation или cosmetic client failure не меняют authoritative outcome. Локальный anticipation допустим для нажатия кнопки, но hit flash, damage number и crit подтверждаются серверным outcome. Reason codes должны быть стабильными и безопасными (`Cooldown`, `OutOfRange`, `InvalidTarget`, `InsufficientResource`, `InvalidState`, `RateLimited`), без внутренних stack/error details.

## 15. Input contract по платформам

Одна semantic action map обслуживает платформы: `SelectTarget`, `BasicAttack`, `UseSkill(slot)`, `TogglePvEAutoattack`, `Cancel/Back`. Платформенный input не меняет сетевой контракт.

### Desktop

- mouse/tap-equivalent выбирает target;
- отдельная переназначаемая клавиша/кнопка выполняет один BasicAttack intent;
- skill hotkeys вызывают один skill intent;
- удержание клавиши не должно обходить правило «один осознанный input — один manual intent»; OS key repeat фильтруется.

### Gamepad

- стандартный stick управляет наземным движением;
- face/trigger button выполняет BasicAttack;
- skills доступны через ограниченное читаемое mapping;
- focus navigation UI не должна случайно отправлять combat intent.

### Mobile

- virtual stick отвечает за движение;
- крупная custom Attack button находится в основной правой action area;
- skill buttons различимы по размеру и cooldown/resource feedback;
- стандартная Roblox Jump button удаляется/отключается;
- один tap создаёт один manual intent; long press сам по себе не включает PvE-autoattack без отдельного утверждённого UX;
- target selection не должна требовать pixel-perfect tap по движущейся модели.

Размеры, раскладка и конкретные bindings требуют отдельного UX pass, но должны проверяться на реальном mobile viewport и gamepad.

## 16. Решение об отсутствии свободного jump

Player character не имеет обычной freely activated jump action. Серверные movement rules и клиентский input должны согласованно блокировать jump, а UI не должен показывать неработающую кнопку.

Level design обязан обеспечивать traversal дорогами, плавными склонами и лестницами без обязательных прыжков. Проверяются застревания на малых препятствиях, Roblox humanoid state transitions, knockback/physics и respawn spawn points. Возможные vault, climb, gap-crossing или другие contextual actions — отдельная будущая система с собственными validation/animation contracts; Milestone 1 не симулирует их скрытым jump.

## 17. Multiplayer и server authority

- Damage, healing, crit RNG, resource, cooldown, target eligibility, effects, AI state, death и respawn являются server-authoritative.
- Все Remotes проверяют types/shape, identity/context, state, rate и применимые spatial/resource/cooldown условия.
- Сервер дедуплицирует outcome по internal action token; client request не задаёт trusted token результата.
- Два игрока видят одинаковые HP/death/effect outcomes; presentation может прийти позже, но не расходиться по gameplay state.
- Одновременные lethal hits завершают death один раз. Никакой будущий reward callback не вызывается повторно.
- Disconnect/character replacement очищает actions, buffers, autoattack, AI targeting и connections.
- Client не передаёт damage, heal amount, crit result, victims list, cooldown completion, resource balance или mob AI command.
- Future PvP использует тот же manual action pipeline с другим target/context policy; наличие PvP target никогда не включает autoattack. PvP damage/rules/teams не проектируются сейчас.

## 18. Стратегия тестирования и acceptance evidence

### 18.1. Unit tests

- cooldown eligibility на границах server time;
- buffer: too early / inside window / один slot / consumption / invalidation;
- AttackSpeed formula и caps;
- crit bounds, deterministic RNG и применение multiplier один раз;
- resource spend/refund и insufficient-resource rejection;
- range/facing на границах и с вертикальным уклоном;
- effect duration/refresh policy для утверждённых skills;
- AI transition table, leash и respawn token/idempotency;
- damage/heal не применяются дважды одним action token.

### 18.2. Integration tests

- manual request → accept → resolve → recovery → buffered next attack;
- PvE-autoattack и manual input используют один cadence без double hit;
- смерть/target loss/range loss между accept и resolve;
- skill cost/cooldown/outcome и feedback;
- player death очищает state, respawn не дублирует connections;
- Mob `Idle → Aggro → Chase → Attack → Return → Idle`;
- два players атакуют одного mob, death и notification происходят один раз;
- ranged/magic presentation projectile не влияет на server outcome.

### 18.3. Exploit/negative Remote tests

- старый `AttackRequest(true/false)` payload после migration;
- лишние args, неверные types, неизвестный skill ID;
- request чужой/dead/другой-session цели;
- spam/replay во время cooldown и после заполнения buffer;
- поддельные damage/crit/range/time/resource значения;
- autoattack enable вне PvE context;
- skill вне range/facing, без resource, во время смерти/respawn;
- client-supplied AoE victims или forbidden friendly target.

### 18.4. Roblox runtime acceptance

Обязательны solo smoke и multiplayer playtest `1 server + 2 clients`:

- ручной ритм basic attack каждого archetype и отзывчивость buffer;
- один общий authoritative mob HP/outcome у обоих клиентов;
- одновременные attacks, crit, skills и death;
- aggro/chase/leash/return с несколькими players, disconnect и respawn;
- отсутствующий jump на desktop/gamepad/mobile и проходимость representative road/slope/stairs;
- mobile Attack button и skill usability на representative viewport/device/emulation;
- отсутствие recurring errors, duplicate loops/connections и чрезмерного Remote traffic;
- basic hooks работают с placeholder presentation без зависимости результата от assets.

Milestone 1 нельзя объявлять завершённым без этих evidence. До implementation реальные runtime/performance результаты остаются непроверенными.

## 19. Миграция от Milestone 0

Milestone 0 использует `AttackRequest(active: boolean)`, где `true` запускает server autoattack loop, а `false` останавливает его. Milestone 1 намеренно меняет этот developer/network contract.

Миграция должна быть атомарной внутри Milestone 1 implementation branch:

1. Зафиксировать tests текущей cadence/validation и новый manual-intent contract.
2. Заменить смысл `AttackRequest` на безаргументный one-shot manual intent.
3. Удалить boolean toggle loop и состояние, которое считает manual attack постоянным режимом.
4. Добавить отдельный `AutoAttackModeRequest(enabled)` только для optional PvE convenience и направить его в тот же basic-attack executor.
5. Обновить client input: каждый press отправляет один `AttackRequest()`; key repeat/hold не создаёт автоматический режим.
6. Добавить single-slot server buffer и authoritative timing feedback.
7. На переходе строго отклонять legacy boolean payload; не поддерживать молчаливо две semantics одного Remote.
8. Обновить attributes/UI terminology: состояние autoattack не должно называться общим `IsBasicAttacking`; отдельно отображать action/cooldown и PvE-autoattack mode.
9. Повторить malicious tests и `1 server + 2 clients` regression playtest.

Это runtime migration, не save migration: Milestone 0 combat state transient, поэтому `DataVersion` не меняется. Совместный mixed-version client/server deploy не поддерживается; Rojo/Studio playtest должен использовать согласованный source revision.

## 20. Явно вне scope

- PvP implementation, PvP balance, duels, factions и rewards;
- inventory, equipment, loot tables, item ownership и глубокая reward eligibility;
- persistence combat state или изменение `DataVersion`;
- levels/progression beyond interface для stat snapshot;
- party threat/heal eligibility beyond минимального owner decision для Heal;
- полная threat table, taunt system и сложный crowd-control framework;
- combo chains, animation cancel meta, dodge/active block, hitbox action combat;
- accuracy/evasion, elemental systems, resist/penetration и сложные derived stats;
- consumables, resurrection и death penalties;
- финальные balance numbers, character models, animations, VFX, SFX, icons и UI art;
- свободный jump и contextual traversal implementation;
- generic ability scripting framework или новый third-party dependency.

## 21. Решения владельца до implementation planning

Зафиксированные в разделе 2 решения повторно утверждать не требуется. Требуется выбрать:

1. **Resource:** единый механический `CombatResource` для трёх archetypes или разные правила; какие display names у Knight/Ranger/Mystic.
2. **Autoattack UX:** выключен ли режим по умолчанию и каким отдельным действием он включается (toggle/button/иной явный gesture).
3. **Shield Bash:** только interrupt wind-up или короткий stun; действует ли control на elite/boss.
4. **Defensive Stance:** рекомендуемый timed buff либо toggle; какой тип offensive/mobility trade-off допустим.
5. **Snare:** refresh duration или rejection при повторном наложении; нужен ли direct damage.
6. **Heal:** self-only или любой nearby friendly player до появления PartyService.
7. **Cancel economy:** подтвердить default cooldown/resource refund при hard interrupt/resolve failure.
8. **Mob target switching:** после потери target сразу выбирать ближайшего eligible player или всегда Return.
9. **Respawn:** безопасная точка и правило восстановления HP/resource (без death penalty).
10. **Global cooldown:** подтвердить отсутствие общего GCD в Milestone 1 либо явно определить его необходимость.

После ответов и утверждения draft можно писать implementation plan. До этого неоднозначности не должны маскироваться случайными implementation defaults.

## 22. Намеренно оставленные tuning/content decisions

- base damage, scaling coefficients, defense formula и rounding;
- HP/resource pools, costs, regen rates и regen delay;
- basic intervals, wind-ups, cooldowns, AttackSpeed caps;
- input-buffer duration внутри предложенного рабочего диапазона;
- ranges, facing cones, spatial tolerance и target caps;
- CritChance, CritMultiplier, caps и skill-by-skill crit flags;
- effect magnitude/duration для stance, rapid shot, snare и control;
- AoE radius и victim cap Flame Burst;
- aggro radius, leash distance/time, AI tick/pathfinding cadence;
- mob stats, точный набор/names/visual variants и respawn delays;
- player respawn delay и восстановление ресурса;
- точные bindings, mobile layout и presentation assets;
- animation timings и FX/SFX keys/content.

Все такие числа должны жить в definitions/config, быть помечены как tuning values и проверяться playtest, а не дублироваться в gameplay modules.
