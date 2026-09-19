# Luna World — план реализации production-rework мира v0.1

Статус: **draft — 2026-09-19**.

## 1. Рабочая ветка

`feature/world-v01-production-rework`

Base: текущий approved/prototyped world layout.

Цель — заменить Part-platform landscape на production-oriented Terrain-based blockout, не смешивая эту работу с Milestone 2 progression/persistence.

## 2. Phase 0 — freeze prototype contract

- зафиксировать текущие stable IDs;
- зафиксировать scale 1.5× как baseline;
- сохранить route topology;
- отметить PR #9 как geometry prototype;
- добавить top-down coordinate export / debug map.

## 3. Phase 1 — authoring pipeline

Создать authoring-tooling:

- world-source config;
- deterministic heightmap generator;
- optional colormap generator;
- route/POI/spawn overlay PNG;
- README с точными Roblox Terrain import settings.

Generator не запускается в runtime.

## 4. Phase 2 — macro terrain

Создать единый landscape:

- Village hill;
- Meadows basin;
- river valley;
- Moonfall Road spine;
- Goblin high side;
- Spider low side;
- Dark Woodland threshold.

Проверить:

- нет отдельных floating islands;
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
