# Milestone 0: Playground — план реализации

> **Для агентных исполнителей:** ОБЯЗАТЕЛЬНЫЙ SUB-SKILL: использовать `superpowers:subagent-driven-development` (рекомендуется) или `superpowers:executing-plans` для пошаговой реализации этого плана. Шаги используют checkbox (`- [ ]`) для отслеживания выполнения.

**Цель:** получить первый рабочий multiplayer-прототип Luna World: два игрока могут выбрать одного Grey Wolf, запустить server-authoritative autoattack, видеть общий HP, убить моба, получить XP за убийство и дождаться корректного respawn.

**Архитектура:** Git/Rojo являются source of truth для кода. Клиент отвечает только за выбор цели, input и HUD; сервер хранит authoritative target/attack state, рассчитывает валидность и урон, управляет жизненным циклом Wolf и начисляет session XP. Для Milestone 0 не вводятся persistence, уровни, skills, loot, party и полноценный AI.

**Tech Stack:** Roblox Studio, Luau (`--!strict`), Rojo `7.7.0`, Rokit, Roblox RemoteEvent, ContextActionService, встроенные Roblox Instances. Внешний test framework на этом milestone не добавляется; используется небольшой assert-based runner только для детерминированных unit tests.

**Spec:** `docs/superpowers/specs/2026-09-13-luna-world-v0.1-design.md`

## Глобальные ограничения

- Основной язык проектной документации — русский; `AGENTS.md` может оставаться на английском.
- Server authoritative для damage, death, XP и gameplay state.
- Клиент отправляет намерение, но не числовой результат (`damage`, `XP` и т.п.).
- Каждый RemoteEvent валидирует типы, entity existence и допустимое состояние на сервере.
- Никакого внешнего backend, PostgreSQL, Redis, custom auth или общего gameplay framework.
- Milestone завершается multiplayer smoke test минимум `1 server + 2 clients`.
- Между Milestone 0 и следующим функциональным блоком выполняется stabilization/refactor gate.
- Текущая версия игры остаётся `0.1.0-dev.0`; этот milestone сам по себе не является релизом и не требует version bump.

---

## Структура файлов Milestone 0

Будут созданы:

```text
Luna-World/
├─ default.project.json
├─ test.project.json
├─ .gitignore
├─ src/
│  ├─ shared/
│  │  ├─ config/
│  │  │  └─ CombatConfig.luau
│  │  ├─ definitions/
│  │  │  └─ MobDefinitions.luau
│  │  └─ combat/
│  │     └─ CombatRules.luau
│  ├─ server/
│  │  ├─ services/
│  │  │  ├─ MobService.luau
│  │  │  ├─ ProgressionService.luau
│  │  │  └─ CombatService.luau
│  │  └─ main.server.luau
│  └─ client/
│     ├─ controllers/
│     │  ├─ TargetController.luau
│     │  └─ CombatInputController.luau
│     ├─ ui/
│     │  └─ CombatHud.luau
│     └─ main.client.luau
└─ tests/
   ├─ TestRunner.luau
   ├─ CombatRulesSpec.luau
   └─ run.server.luau
```

Границы ответственности фиксируются именно так: `CombatRules` — чистая логика, `MobService` — mob lifecycle, `CombatService` — target/attack validation и cadence, `ProgressionService` — session XP, client controllers — только input/presentation.

---

### Task 1: Rojo-каркас и воспроизводимый unit-test контур

**Files:**
- Create: `default.project.json`
- Create: `test.project.json`
- Create: `.gitignore`
- Create: `tests/TestRunner.luau`
- Create: `tests/run.server.luau`

**Interfaces:**
- Consumes: `rokit.toml` с `rojo-rbx/rojo@7.7.0`.
- Produces: Rojo mapping для `Shared`, `Server`, `Client`, двух RemoteEvent; test mapping с `ServerScriptService/Tests`; `TestRunner.run(name, callback)` и `TestRunner.summary()`.

- [ ] **Step 1: создать `default.project.json`**

```json
{
  "name": "LunaWorld",
  "tree": {
    "$className": "DataModel",
    "ReplicatedStorage": {
      "Shared": { "$path": "src/shared" },
      "Remotes": {
        "$className": "Folder",
        "TargetRequest": { "$className": "RemoteEvent" },
        "AttackRequest": { "$className": "RemoteEvent" }
      }
    },
    "ServerScriptService": {
      "Server": { "$path": "src/server" }
    },
    "StarterPlayer": {
      "StarterPlayerScripts": {
        "Client": { "$path": "src/client" }
      }
    }
  }
}
```

- [ ] **Step 2: создать `test.project.json`**

Использовать тот же mapping и добавить tests только в тестовый проект:

```json
{
  "name": "LunaWorldTests",
  "tree": {
    "$className": "DataModel",
    "ReplicatedStorage": {
      "Shared": { "$path": "src/shared" },
      "Remotes": {
        "$className": "Folder",
        "TargetRequest": { "$className": "RemoteEvent" },
        "AttackRequest": { "$className": "RemoteEvent" }
      }
    },
    "ServerScriptService": {
      "Server": { "$path": "src/server" },
      "Tests": { "$path": "tests" }
    },
    "StarterPlayer": {
      "StarterPlayerScripts": {
        "Client": { "$path": "src/client" }
      }
    }
  }
}
```

- [ ] **Step 3: создать `.gitignore`**

```gitignore
*.rbxl
*.rbxlx
*.rbxm
*.rbxmx
sourcemap.json
.DS_Store
Thumbs.db
```

- [ ] **Step 4: создать минимальный `tests/TestRunner.luau`**

```lua
--!strict

local TestRunner = {}

local passed = 0
local failed = 0

function TestRunner.run(name: string, callback: () -> ()): ()
    local ok, err = pcall(callback)
    if ok then
        passed += 1
        print("[PASS] " .. name)
    else
        failed += 1
        warn("[FAIL] " .. name .. ": " .. tostring(err))
    end
end

function TestRunner.summary(): ()
    print(string.format("Tests: %d passed, %d failed", passed, failed))
    assert(failed == 0, string.format("%d test(s) failed", failed))
end

return TestRunner
```

- [ ] **Step 5: создать `tests/run.server.luau`**

```lua
--!strict

local TestRunner = require(script.Parent.TestRunner)

for _, child in script.Parent:GetChildren() do
    if child:IsA("ModuleScript") and string.match(child.Name, "Spec$") then
        local register = require(child)
        register(TestRunner)
    end
end

TestRunner.summary()
```

- [ ] **Step 6: проверить Rojo-конфигурации**

Run:

```powershell
rojo build default.project.json -o LunaWorld-check.rbxlx
rojo build test.project.json -o LunaWorldTests-check.rbxlx
```

Expected: обе команды завершаются успешно и создают локальные `.rbxlx`, которые игнорируются Git.

- [ ] **Step 7: удалить локальные check-файлы и сделать commit**

```powershell
Remove-Item LunaWorld-check.rbxlx,LunaWorldTests-check.rbxlx
git add default.project.json test.project.json .gitignore tests/TestRunner.luau tests/run.server.luau
git commit -m "chore: scaffold Rojo project and test runner"
```

---

### Task 2: Shared combat contract и Grey Wolf definition

**Files:**
- Create: `src/shared/config/CombatConfig.luau`
- Create: `src/shared/definitions/MobDefinitions.luau`
- Create: `src/shared/combat/CombatRules.luau`
- Create: `tests/CombatRulesSpec.luau`

**Interfaces:**
- Consumes: Roblox `Vector3`.
- Produces: `CombatConfig.BasicAttackDamage`, `BasicAttackRange`, `BasicAttackInterval`, `TargetSelectionRange`; `MobDefinitions.grey_wolf`; `CombatRules.canSelectTarget(...)`; `CombatRules.canBasicAttack(...)`.

- [ ] **Step 1: написать failing unit tests**

```lua
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CombatRules = require(ReplicatedStorage.Shared.combat.CombatRules)

return function(TestRunner)
    TestRunner.run("target inside selection range is valid", function()
        assert(CombatRules.canSelectTarget(Vector3.zero, Vector3.new(0, 0, 50), true, 100))
    end)

    TestRunner.run("dead target cannot be selected", function()
        assert(not CombatRules.canSelectTarget(Vector3.zero, Vector3.new(0, 0, 5), false, 100))
    end)

    TestRunner.run("basic attack requires range", function()
        assert(CombatRules.canBasicAttack(Vector3.zero, Vector3.new(0, 0, 10), true, 12))
        assert(not CombatRules.canBasicAttack(Vector3.zero, Vector3.new(0, 0, 13), true, 12))
    end)
end
```

- [ ] **Step 2: запустить test project и убедиться, что тест падает из-за отсутствующего module**

Run:

```powershell
rojo serve test.project.json --port 34873
```

В Roblox Studio подключить Rojo к `localhost:34873`, нажать Play.

Expected: test runner сообщает ошибку `CombatRules` отсутствует / не может быть required.

- [ ] **Step 3: создать `CombatConfig.luau`**

```lua
--!strict

return {
    BasicAttackDamage = 25,
    BasicAttackRange = 12,
    BasicAttackInterval = 1.2,
    TargetSelectionRange = 100,
}
```

- [ ] **Step 4: создать `MobDefinitions.luau`**

```lua
--!strict

return {
    grey_wolf = {
        id = "mob_grey_wolf",
        displayName = "Grey Wolf",
        maxHealth = 100,
        rewardXP = 25,
        respawnSeconds = 5,
    },
}
```

- [ ] **Step 5: создать минимальный `CombatRules.luau`**

```lua
--!strict

local CombatRules = {}

local function withinRange(a: Vector3, b: Vector3, range: number): boolean
    return (a - b).Magnitude <= range
end

function CombatRules.canSelectTarget(
    playerPosition: Vector3,
    targetPosition: Vector3,
    targetAlive: boolean,
    selectionRange: number
): boolean
    return targetAlive and withinRange(playerPosition, targetPosition, selectionRange)
end

function CombatRules.canBasicAttack(
    playerPosition: Vector3,
    targetPosition: Vector3,
    targetAlive: boolean,
    attackRange: number
): boolean
    return targetAlive and withinRange(playerPosition, targetPosition, attackRange)
end

return CombatRules
```

- [ ] **Step 6: повторить tests**

Expected: 3 tests PASS, 0 failed.

- [ ] **Step 7: commit**

```powershell
git add src/shared tests/CombatRulesSpec.luau
git commit -m "test: define milestone zero combat rules"
```

---

### Task 3: MobService и server-owned lifecycle одного Wolf

**Files:**
- Create: `src/server/services/MobService.luau`

**Interfaces:**
- Consumes: `MobDefinitions.grey_wolf`.
- Produces:
  - `MobService.start(): ()`
  - `MobService.getByEntityId(entityId: string): Model?`
  - `MobService.applyDamage(entityId: string, amount: number, attacker: Player): boolean`
  - `MobService.MobDied: RBXScriptSignal`, параметры `(killer: Player, mobId: string)`.

- [ ] **Step 1: реализовать placeholder Wolf factory внутри MobService**

Wolf создаётся сервером как `Model` с `Humanoid`, `HumanoidRootPart` и атрибутами:

```lua
model:SetAttribute("EntityId", entityId)
model:SetAttribute("MobId", definition.id)
```

Spawn position для Milestone 0 фиксирован:

```lua
local SPAWN_CFRAME = CFrame.new(0, 3, -20)
```

RootPart должен быть `Anchored = false`, `CanCollide = true`; внешний вид — простой серый placeholder без арт-ассетов.

- [ ] **Step 2: реализовать registry по `EntityId`**

```lua
local mobsByEntityId: {[string]: Model} = {}
```

`getByEntityId` возвращает только актуальный зарегистрированный Model.

- [ ] **Step 3: реализовать server-side damage**

`applyDamage` должен:

```lua
assert(amount >= 0, "damage must not be negative")
```

затем найти mob, проверить `Humanoid.Health > 0`, сохранить `lastAttacker` только на сервере и вызвать `Humanoid:TakeDamage(amount)`.

Клиент никогда не передаёт `amount`.

- [ ] **Step 4: реализовать single-fire death lifecycle**

При `Humanoid.Died`:

1. удалить entity из registry;
2. один раз вызвать внутренний `BindableEvent` `MobDied` с последним валидным attacker;
3. через `definition.respawnSeconds` удалить старый model, если он ещё существует;
4. создать нового Grey Wolf с новым `EntityId` ровно один раз.

- [ ] **Step 5: ручной solo smoke test**

Временно из Studio command bar / debugger подтвердить:

- в Workspace появляется один `Grey Wolf`;
- у него есть `EntityId` и `MobId`;
- уничтожение Humanoid приводит ровно к одному respawn через ~5 секунд;
- одновременно не остаётся два живых wolf после одного death cycle.

- [ ] **Step 6: commit**

```powershell
git add src/server/services/MobService.luau
git commit -m "feat: add grey wolf server lifecycle"
```

---

### Task 4: ProgressionService для session XP

**Files:**
- Create: `src/server/services/ProgressionService.luau`

**Interfaces:**
- Consumes: `Player` и `rewardXP` из Mob definition.
- Produces:
  - `ProgressionService.start(): ()`
  - `ProgressionService.awardXP(player: Player, amount: number): ()`
  - replicated player Attribute `SessionXP`.

- [ ] **Step 1: реализовать инициализацию игроков**

При `PlayerAdded`:

```lua
player:SetAttribute("SessionXP", 0)
```

Также обработать уже подключённых игроков при старте service.

- [ ] **Step 2: реализовать server-only award**

```lua
function ProgressionService.awardXP(player: Player, amount: number): ()
    assert(amount >= 0, "XP reward must not be negative")
    if player.Parent == nil then
        return
    end

    local current = player:GetAttribute("SessionXP")
    local currentXP = if typeof(current) == "number" then current else 0
    player:SetAttribute("SessionXP", currentXP + amount)
end
```

- [ ] **Step 3: явно зафиксировать временное правило Milestone 0**

В кодовом комментарии рядом с death wiring указать: **на Milestone 0 XP получает последний attacker; shared credit / party contribution реализуются позже и это правило не является финальной экономикой v0.1.**

- [ ] **Step 4: commit**

```powershell
git add src/server/services/ProgressionService.luau
git commit -m "feat: add session xp progression"
```

---

### Task 5: CombatService — target intent и server-authoritative autoattack

**Files:**
- Create: `src/server/services/CombatService.luau`
- Create: `src/server/main.server.luau`

**Interfaces:**
- Consumes: `TargetRequest`, `AttackRequest`, `CombatConfig`, `CombatRules`, `MobService`, `ProgressionService`.
- Produces: authoritative per-player target state и attack loop; никаких client-provided damage values.

- [ ] **Step 1: реализовать target registry**

```lua
local targetsByPlayer: {[Player]: string} = {}
local attackGeneration: {[Player]: number} = {}
```

`TargetRequest.OnServerEvent(player, entityId)` принимает только `string`.

Перед сохранением target сервер проверяет:

- player Character существует;
- `HumanoidRootPart` существует;
- entity существует в `MobService`;
- target Humanoid жив;
- target находится не дальше `CombatConfig.TargetSelectionRange`.

Некорректный request ничего не изменяет.

- [ ] **Step 2: реализовать cancellable autoattack loop**

`AttackRequest.OnServerEvent(player, active)` принимает только `boolean`.

При `active == true` увеличить generation и запустить task:

```lua
while attackGeneration[player] == generation do
    local targetId = targetsByPlayer[player]
    if targetId == nil then
        break
    end

    local target = MobService.getByEntityId(targetId)
    if target == nil then
        break
    end

    if canAttackNow(player, target) then
        local applied = MobService.applyDamage(
            targetId,
            CombatConfig.BasicAttackDamage,
            player
        )
        if not applied then
            break
        end
    end

    task.wait(CombatConfig.BasicAttackInterval)
end
```

Если target временно вне attack range, loop **не наносит damage**, но остаётся активным: игрок может подойти вручную и удары начнутся без повторного нажатия Attack.

- [ ] **Step 3: остановить attack при `active == false`, смерти target, PlayerRemoving**

Отмена реализуется только изменением generation / очисткой state; не использовать бесконтрольные forever-tasks.

- [ ] **Step 4: подключить death → XP в `main.server.luau`**

Порядок старта:

```lua
ProgressionService.start()
MobService.start()
CombatService.start()
```

Затем:

```lua
MobService.MobDied:Connect(function(killer, mobId)
    local definition = MobDefinitionsById[mobId]
    if definition then
        ProgressionService.awardXP(killer, definition.rewardXP)
    end
end)
```

Если `MobDefinitions` пока индексирован ключом `grey_wolf`, создать локальный helper поиска по стабильному `id`; не использовать display name как ключ.

- [ ] **Step 5: negative remote smoke tests**

В Studio с test client проверить, что сервер без error отклоняет:

```lua
TargetRequest:FireServer(12345)
TargetRequest:FireServer("not_existing_entity")
AttackRequest:FireServer("yes")
```

Expected: no damage, no XP, no server crash.

- [ ] **Step 6: commit**

```powershell
git add src/server
git commit -m "feat: add server authoritative basic combat"
```

---

### Task 6: Клиентский target, Attack input и минимальный HUD

**Files:**
- Create: `src/client/controllers/TargetController.luau`
- Create: `src/client/controllers/CombatInputController.luau`
- Create: `src/client/ui/CombatHud.luau`
- Create: `src/client/main.client.luau`

**Interfaces:**
- Consumes: `TargetRequest`, `AttackRequest`, replicated Mob attributes/Humanoid health, `Player.SessionXP` Attribute.
- Produces: mouse/touch target selection, локальный Highlight, `F` / gamepad / touch Attack action, target HP frame, XP text.

- [ ] **Step 1: реализовать TargetController**

Контроллер должен raycast-ить из screen position через `CurrentCamera:ViewportPointToRay`, найти ближайший ancestor `Model` с string Attribute `EntityId` и отправить только этот ID:

```lua
TargetRequest:FireServer(entityId)
```

После клика / tap локально показать `Highlight` на выбранном model.

Для mouse использовать `UserInputService.InputBegan`; для touch — `UserInputService.TouchTap`.

- [ ] **Step 2: реализовать CombatInputController через ContextActionService**

Bind action:

```lua
ContextActionService:BindAction(
    "LunaBasicAttack",
    onAttackAction,
    true,
    Enum.KeyCode.F,
    Enum.KeyCode.ButtonR2
)
ContextActionService:SetTitle("LunaBasicAttack", "Attack")
```

Первое нажатие отправляет:

```lua
AttackRequest:FireServer(true)
```

повторное — `false`.

Touch button создаётся самим `ContextActionService` благодаря `createTouchButton = true`.

- [ ] **Step 3: реализовать минимальный CombatHud программно**

На Milestone 0 не нужен полноценный UI framework. Создать `ScreenGui` с:

- target name;
- HP text / простым HP bar;
- `XP: <SessionXP>`.

HUD должен подписываться на `Humanoid.HealthChanged` текущей target model и `player:GetAttributeChangedSignal("SessionXP")`.

При смене target старый HealthChanged connection обязательно отключается.

- [ ] **Step 4: собрать client bootstrap**

`main.client.luau` создаёт HUD, затем инициализирует TargetController и CombatInputController. Не помещать gameplay authority в bootstrap.

- [ ] **Step 5: solo smoke test**

Expected:

1. игрок двигается обычным Roblox WASD;
2. click/tap по Wolf выделяет его;
3. HUD показывает Grey Wolf и HP;
4. `F` / Attack запускает autoattack;
5. вне 12 studs урон не проходит;
6. после подхода урон начинается без client-supplied damage;
7. после смерти target атака прекращается;
8. XP изменяется только после server-confirmed death.

- [ ] **Step 6: commit**

```powershell
git add src/client
git commit -m "feat: add target combat client controls"
```

---

### Task 7: Multiplayer acceptance и stabilization gate Milestone 0

**Files:**
- Modify: `CHANGELOG.md` только если принято решение фиксировать milestone-level development changes в секции Unreleased.
- Modify: `docs/ROADMAP.md` — отметить Milestone 0 завершённым только после всех checks.
- Modify: другие документы только если реализация выявила реальное расхождение с утверждённым дизайном.

**Interfaces:**
- Consumes: завершённые server/client системы Milestone 0.
- Produces: проверенное поведение и documented known issues; основание для перехода к Combat & Skills.

- [ ] **Step 1: подтянуть код в Studio через Rojo**

Run во встроенном терминале VS Code:

```powershell
rojo serve default.project.json
```

В Roblox Studio открыть Baseplate DEV place и подключить Rojo plugin к server.

- [ ] **Step 2: запустить multiplayer test**

Roblox Studio → Test → Server & Clients:

- Server: 1;
- Clients: 2.

- [ ] **Step 3: проверить обязательную матрицу**

Оба клиента должны подтвердить:

1. видят одного и того же Grey Wolf;
2. видят один и тот же authoritative HP;
3. могут независимо выбрать его target;
4. client A и client B могут одновременно атаковать;
5. частота каждого autoattack ограничена server cadence;
6. смерть срабатывает ровно один раз;
7. ровно один respawn появляется примерно через 5 секунд;
8. XP получает только определённый временным правилом last attacker;
9. второй клиент не получает phantom XP;
10. повторные/неверные remote requests не создают damage или XP;
11. после respawn новый Wolf имеет новый `EntityId`;
12. старый target не может наносить damage новому Wolf автоматически через stale ID.

- [ ] **Step 4: проверить lifecycle cleanup**

Во время активного autoattack закрыть один client.

Expected:

- server Output без recurring errors;
- attack task этого Player прекращается;
- оставшийся client продолжает играть;
- respawn Wolf продолжает работать.

- [ ] **Step 5: выполнить test project ещё раз**

Run:

```powershell
rojo serve test.project.json --port 34873
```

Expected: все deterministic tests PASS.

- [ ] **Step 6: stabilization/refactor review**

Перед закрытием milestone проверить:

- нет дублирующихся combat constants;
- нет `GameManager` / catch-all module;
- connections после target change и PlayerRemoving очищаются;
- remote arguments валидируются;
- client нигде не передаёт damage / XP;
- временные debug prints удалены или осмысленны;
- документация соответствует фактическим interfaces.

- [ ] **Step 7: финальный commit Milestone 0**

```powershell
git add .
git status
git commit -m "milestone: complete multiplayer combat playground"
```

Не выполнять version bump: `VERSION` остаётся `0.1.0-dev.0`.

---

## Definition of Done Milestone 0

Milestone 0 считается завершённым только при одновременном выполнении всех условий:

- Rojo build/serve работает из чистого checkout после `rokit install`;
- deterministic unit tests зелёные;
- Roblox Studio solo smoke test зелёный;
- Roblox Studio multiplayer smoke test `1 server + 2 clients` зелёный;
- Grey Wolf имеет server-owned health/death/respawn lifecycle;
- клиент не определяет damage, XP или death;
- invalid RemoteEvent payload не ломает сервер и не меняет authoritative state;
- target/attack работают на PC и имеют touch/gamepad path через Roblox input APIs;
- после death начисляется session XP;
- respawn не создаёт дубликатов;
- stale target не переносится на новый entity;
- Output не содержит необъяснённых recurring errors;
- пройден stabilization/refactor gate;
- документация обновлена при фактическом расхождении с планом.

После этого следующий отдельный implementation plan должен покрыть **Milestone 1: Combat & Skills**, а не расширять этот план новыми подсистемами.
