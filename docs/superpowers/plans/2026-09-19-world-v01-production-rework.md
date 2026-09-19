# Luna World — план реализации production-rework мира v0.1

Статус: **implementation in progress — 2026-09-19**.

## 1. Рабочая ветка

`feature/world-v01-production-rework`

Base: текущий approved/prototyped world layout.

Цель — заменить Part-platform landscape на production-oriented Terrain-based blockout, не смешивая эту работу с Milestone 2 progression/persistence.

## 2. Phase 0 — freeze prototype contract

- зафиксировать текущие stable IDs;
- зафиксировать scale **2×** как baseline;
- сохранить route topology;
- отметить PR #9 как geometry prototype;
- добавить top-down coordinate export / debug map — **DONE**;

## 3. Phase 1 — authoring pipeline

Создать authoring-tooling:

- world-source config — **DONE**;
- deterministic heightmap generator — **DONE**;
- optional colormap generator;
- route/POI/spawn overlay PNG — **DONE**;
- README с точными Roblox Terrain import settings — **DONE**;

Generator не запускается в runtime.

Первая версия generator формирует карту 2600 × 4800 studs, 16-bit heightmap 650 × 1200, water mask, top-down и overlays. Следующий checkpoint — owner import в Terrain Editor и runtime traversal review.

## 4. Phase 2 — macro terrain

Статус: **terrain v0.3 implemented, owner re-import pending**.

Создать единый landscape:

- Village hill — **DONE**;
- Meadows basin — **DONE**;
- river valley — **DONE**;
- Moonfall Road spine — **DONE**;
- Goblin high side — **DONE, strengthened in v0.2**;
- Spider low side — **DONE, strengthened in v0.2**;
- Dark Woodland threshold — **DONE**;
- Selene horizon massif — **DONE**;
- future Old Cemetery raised terrace — **RESERVED**;
- future Fallen Shrine raised promontory — **RESERVED**.

Terrain v0.3 additionally:

- regular terrain floor no longer reaches zero except intentional river carving;
- vertical authoring range increased from 128 to 192 studs to avoid clipping Selene massif;
- Goblin Camp has a raised playable shelf plus rough outer rim;
- Spider Hollow has a lower playable core plus enclosing rim;
- Old Cemetery/Fallen Shrine are terrain reservations only, not v0.1 gameplay zones.

Проверить после owner re-import:

- нет отдельных floating islands / zero-height holes;
- Village Hill и Selene massif сохраняют approved concept silhouette;
- Goblin Camp географически читается до props;
- Spider Hollow читается как hollow до props;
- future Old Cemetery/Fallen Shrine не выглядят как случайные ямы;
- terrain скрывает соседние зоны;
- карты хватает по ширине вокруг маршрутов;
- world boundary визуально объяснима.

## 5. Phase 3 — traversal shaping

Проложить:

- Village internal slopes;
- Village → Meadows slope;
- road around river;
- bridge approaches;
- Meadows → Moonfall transition;
- Goblin climb;
- Spider descent;
- Spider return;
- Dark Woodland approach.

Каждый путь acceptance-test без прыжка.

## 6. Phase 4 — river and natural boundaries

- Terrain Water;
- русло;
- берега;
- cliff/forest boundaries;
- remove reliance on exposed baseplate;
- retain server recovery as fallback.

## 7. Phase 5 — landmark replacement

Сохранить/переиспользовать только полезный blockout intent:

- Village buildings;
- Farm;
- Bridge;
- Stone Circle;
- Broken Wagon;
- Waystone;
- Goblin structures;
- Spider Cave Mouth;
- Dark Woodland boundary stones.

При необходимости сделать modular assets в Blender.

Дополнительно использовать Blender Studio subscription как источник production references и пригодных reusable assets. Для каждого внешнего asset перед включением в Luna World фиксировать источник и конкретную лицензию; не считать наличие подписки автоматическим разрешением на любой контент.

## 8. Phase 6 — grounding and gameplay anchors

- ground-snap POI;
- ground-snap NPC anchors;
- spawn-area projection to terrain;
- update zone volumes;
- add automated validation where practical;
- debug markers Studio-only.

## 9. Phase 7 — runtime acceptance

Owner test:

- full no-jump traversal;
- return traversal;
- deliberate escape attempts;
- deliberate falls;
- bridge;
- river banks;
- all enemy pockets;
- 1 server + 2 clients;
- desktop/gamepad/mobile.

## 10. Phase 8 — cleanup

- remove obsolete Part-terrain builders;
- retain only necessary authored-world bootstrap/validation;
- update architecture/world docs;
- update PR ledger;
- conscious debt list;
- final independent review.

## 11. Stop conditions

Не переходить к art polish, пока не выполнены:

- continuous terrain;
- all intended paths walkable without jumping;
- no floating world objects;
- containment works;
- owner accepts scale and route readability.

Не тратить время на финальные материалы/foliage до этого checkpoint.


## Terrain v0.3 — centered encounter forms

Реализовано после owner review:

- authoring pads получили `raise / lower / set` semantics;
- Goblin Camp больше не использует positive outer ring как главный рельеф: camp core поднят до centered shelf;
- Spider Hollow использует intentional lowered core + surrounding rim;
- Old Cemetery и Fallen Shrine сдвинуты внутрь карты и формируются как raised future terraces;
- artifact output переведён на `terrain-v03`;
- contract-test теперь генерирует actual height field и проверяет, что Goblin/Cemetery/Shrine выше ближайшего окружения, а Spider Hollow ниже rim.
