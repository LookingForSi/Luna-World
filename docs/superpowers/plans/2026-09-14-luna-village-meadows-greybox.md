# Luna Village + Luna Meadows Greybox Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Создать воспроизводимый из Git greybox первого world-block: Luna Village на склоне, спуск в Luna Meadows, Moonfall Farm с овцами, landmarks и stable spawn markers.

**Architecture:** Shared `WorldLayout` хранит IDs, координаты и blockout dimensions. Server-only builders создают только `Workspace/LunaWorldGreybox` из простых anchored Parts/Models. Финальный Terrain/art позже авторится вручную в Studio; этот builder — временный blockout.

**Tech Stack:** Roblox Studio, Luau, Rojo 7.7.x, Git/GitHub. Без сторонних runtime dependencies.

**Spec:** `docs/superpowers/specs/2026-09-14-luna-village-meadows-design.md`

## Global Constraints

- Не менять combat-код Milestone 0.
- Не реализовывать quests, NPC dialogue, Mob AI, loot, persistence или финальный art.
- Stable IDs из spec не переименовывать.
- Builder удаляет/перестраивает только собственный managed container.
- После каждого task review gate: commit + push в `feature/luna-village-meadows-greybox` и проверка remote HEAD.
- Документация — на русском; код/идентификаторы — на английском.

## Resulting files

```text
src/shared/world/WorldLayout.luau
src/shared/world/WorldLayoutValidator.luau
src/server/world/GreyboxPrimitives.luau
src/server/world/LunaVillageGreybox.luau
src/server/world/LunaMeadowsGreybox.luau
src/server/world/WorldGreyboxBuilder.luau
src/server/world/WorldBootstrap.server.luau
tests/world/TestRunner.luau
tests/world/WorldLayoutSpec.luau
tests/world/run.server.luau
world.project.json
world.test.project.json
```

---

### Task 1: World definitions + automated validation

**Files:**
- Create: `src/shared/world/WorldLayout.luau`
- Create: `src/shared/world/WorldLayoutValidator.luau`
- Create: `tests/world/TestRunner.luau`
- Create: `tests/world/WorldLayoutSpec.luau`
- Create: `tests/world/run.server.luau`
- Create: `world.test.project.json`

**Interfaces:**
- `WorldLayout.Dimensions`, `.Zones`, `.PointsOfInterest`, `.SpawnMarkers`, `.Route`
- `WorldLayoutValidator.validate(layout: any): (boolean, {string})`

- [ ] **Step 1: Define canonical layout**

Use `+Z` as direction deeper into Moonfall Valley. Fix these important values:

```luau
Dimensions = {
    VillageFootprint = Vector2.new(250, 220),
    VillageElevationAboveMeadows = 36,
    MeadowsRouteLength = 900,
}
```

Required POI positions:

```text
poi_main_gate          (0,32,0)
poi_training_ground    (-75,38,-55)
poi_blacksmith         (75,40,-65)
poi_village_square     (0,46,-120)
poi_merchant           (68,47,-125)
poi_residential        (-72,47,-130)
poi_elder_house        (55,62,-185)
poi_shrine             (-55,66,-195)
poi_moonfall_farm      (-180,8,365)
poi_meadow_bridge      (-35,7,300)
poi_stone_circle       (135,6,545)
exit_moonfall_road     (0,4,900)
```

Required spawn definitions:

```text
spawn_young_wolf_farm       mob_young_wolf    (-110,8,415) radius 55
spawn_wolf_stone_circle     mob_grey_wolf     (100,7,585) radius 70
spawn_spider_meadow_pocket  mob_meadow_spider (220,8,690) radius 60
```

Route points:

```text
(0,32,0) → (0,20,90) → (-20,11,210) → (-35,7,300) →
(20,6,450) → (90,6,560) → (45,5,720) → (0,4,900)
```

- [ ] **Step 2: Implement validator**

Validator returns errors instead of throwing and checks:

```text
all required stable IDs exist
IDs are unique across zones/POIs/spawns
levelMin <= levelMax
spawn radius > 0
route has >= 2 points
XZ distance gate→exit >= 700 studs
```

- [ ] **Step 3: Add tests**

Tests must prove:

```text
canonical layout passes
duplicate ID fails
invalid level range fails
non-positive radius fails
missing required POI fails
exit too close fails
```

- [ ] **Step 4: Add isolated Rojo test project and verify**

Map `src/shared -> ReplicatedStorage/Shared`, `tests/world -> ServerScriptService/WorldTests`.

Run:

```bash
rojo build world.test.project.json -o luna-world-tests.rbxlx
rojo sourcemap world.test.project.json -o luna-world-tests-sourcemap.json
```

Expected: exit 0.

- [ ] **Step 5: Commit + push**

```bash
git add src/shared/world tests/world world.test.project.json
git commit -m "feat: define Luna Village world layout"
git push origin feature/luna-village-meadows-greybox
```

---

### Task 2: Focused greybox primitives

**Files:**
- Create: `src/server/world/GreyboxPrimitives.luau`

**Interfaces:**

```luau
createBlock(parent, name, size, cframe, material, attributes) -> BasePart
createMarker(parent, name, position, attributes) -> BasePart
createLabel(adornee, text) -> BillboardGui
createSegment(parent, name, fromPosition, toPosition, width, thickness) -> BasePart
```

- [ ] **Step 1:** Implement `createBlock`: anchored, collidable, attributes applied before parenting.
- [ ] **Step 2:** Implement `createMarker`: anchored, non-colliding debug marker with `StableId` and BillboardGui.
- [ ] **Step 3:** Implement `createSegment` using midpoint + `CFrame.lookAt` for roads/streams.
- [ ] **Step 4:** Review: no Workspace scans, no global mutation, one responsibility only.
- [ ] **Step 5:** Commit + push as `feat: add world greybox primitives`.

---

### Task 3: Luna Village blockout

**Files:**
- Create: `src/server/world/LunaVillageGreybox.luau`

**Interface:** `LunaVillageGreybox.build(parent: Instance) -> Model`

- [ ] **Step 1:** Create three terraces: lower (gate/training/blacksmith), middle (square/merchant/residential), upper (elder/shrine/viewpoint).
- [ ] **Step 2:** Create exactly eight logical POIs from spec. `poi_residential` contains two house volumes under one logical POI.
- [ ] **Step 3:** Create one main gate, one guard tower and only short local palisade/retaining-wall sections; no full perimeter wall.
- [ ] **Step 4:** Add viewpoint near shrine with attributes `Purpose="Viewpoint"`, `LooksToward="ruins_of_selene_future"`.
- [ ] **Step 5:** Review: elevations rise away from gate; no combat dependency; no final-art scope.
- [ ] **Step 6:** Commit + push as `feat: block out Luna Village`.

---

### Task 4: Luna Meadows + Moonfall Farm blockout

**Files:**
- Create: `src/server/world/LunaMeadowsGreybox.luau`

**Interface:** `LunaMeadowsGreybox.build(parent: Instance) -> Model`

- [ ] **Step 1:** Build broad meadow ground sections following `WorldLayout.Route`; first ~200 Z-studs after gate contain no mob spawn marker.
- [ ] **Step 2:** Build continuous road from gate to `exit_moonfall_road` using route segments.
- [ ] **Step 3:** Build shallow stream crossing near `poi_meadow_bridge` plus collidable bridge carrying `StableId="poi_meadow_bridge"`.
- [ ] **Step 4:** Build Moonfall Farm: farmhouse, barn, fenced pen, well, three decorative anchored sheep placeholders and three future-NPC markers. Root gets `StableId="poi_moonfall_farm"`.
- [ ] **Step 5:** Build stone circle from 5–7 standing stones and a small off-road spider pocket from dark tree/rock blockouts.
- [ ] **Step 6:** Create exactly three spawn markers from `WorldLayout.SpawnMarkers`; attributes: `StableId`, `MobId`, `Radius`, `ZoneId="zone_luna_meadows"`. Do not spawn mobs.
- [ ] **Step 7:** Add `exit_moonfall_road` marker with `Destination="zone_moonfall_road_future"`.
- [ ] **Step 8:** Commit + push as `feat: block out Luna Meadows and Moonfall Farm`.

---

### Task 5: Safe idempotent world builder + preview project

**Files:**
- Create: `src/server/world/WorldGreyboxBuilder.luau`
- Create: `src/server/world/WorldBootstrap.server.luau`
- Create: `world.project.json`

**Interface:** `WorldGreyboxBuilder.rebuild(workspaceRoot: Instance?) -> Model`

- [ ] **Step 1: Managed-container safety**

Use:

```text
Container name: LunaWorldGreybox
Attribute: ManagedBy
Value: LunaWorldGreyboxBuilder
```

If matching managed container exists, replace it. If same-named object lacks the marker, abort with actionable error and delete nothing. Never delete other Workspace objects.

- [ ] **Step 2:** `rebuild()` creates managed root and calls village + meadows builders exactly once.
- [ ] **Step 3:** Bootstrap calls `rebuild(workspace)` once at server startup; no Heartbeat/per-frame loop.
- [ ] **Step 4:** `world.project.json` maps `src/shared` and `src/server/world`; it must support `rojo serve world.project.json`.
- [ ] **Step 5: Build checks**

```bash
rojo build world.project.json -o luna-world-preview.rbxlx
rojo sourcemap world.project.json -o luna-world-preview-sourcemap.json
rojo build world.test.project.json -o luna-world-tests.rbxlx
git diff --check
```

Expected: exit 0.

- [ ] **Step 6:** If Roblox runtime is available, call `rebuild()` twice and verify exactly one managed root remains.
- [ ] **Step 7:** Commit + push as `feat: assemble Luna Village and Meadows greybox`.

---

### Task 6: Final independent review package

**Files:** modify Tasks 1–5 files only if review finds a defect. Do not add gameplay scope.

- [ ] **Step 1:** Spec review against all acceptance criteria.
- [ ] **Step 2:** Code-quality review for destructive cleanup, duplicate IDs, repeated layout constants, combat coupling, per-frame loops and module bloat.
- [ ] **Step 3:** Run all build/test-project checks from Task 5.
- [ ] **Step 4:** Push all review fixes to the same branch.
- [ ] **Step 5:** Return manual Studio checklist:

```text
[ ] Village visibly above Meadows
[ ] 8 village functional points readable
[ ] One main gate clearly leads downhill
[ ] Safe transition feels plausible
[ ] Moonfall Farm reads as farm + sheep pen
[ ] Stream, bridge and stone circle readable
[ ] Spawn markers are sensibly placed outside safe farm pen
[ ] Moonfall Road exit is obvious
[ ] Village visible from at least one Meadows point
[ ] Future Ruins direction readable from village viewpoint
[ ] Rebuild creates no duplicates
[ ] Studio Output has no recurring errors
```

- [ ] **Step 6:** Report final HEAD, Draft PR number, automated checks and unverified manual items. Do not merge and do not claim world-block accepted before owner Studio review.
