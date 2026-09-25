# Инструменты генерации Moonfall

Этот каталог — **только authoring/dev tooling**. Production Lobby / Moonfall / Dungeon Place не должны маппить `tools/worldgen` и не должны запускать `PlayableWorldBlockout.rebuild()` на старте сервера.

## Режимы

- `world.project.json` — preview текущего генератора в Studio.
- `default.project.json` и `projects/dev-combined.project.json` — dev-combined flow; генератор доступен явно через dev-only `Worldgen` mapping.
- `projects/moonfall-authoring.project.json` — one-shot bake tooling для подготовки authored Moonfall Place.
- `projects/moonfall.project.json` — production runtime; generator туда не входит.

## One-shot bake

1. Сделать backup/copy текущего Moonfall Place.
2. Открыть целевой Moonfall Place в Roblox Studio.
3. Синхронизировать `projects/moonfall-authoring.project.json`.
4. Убедиться, что `Workspace/LunaWorldPlayableBlockout` отсутствует. Если там уже есть authored world — сначала работать только с backup/copy.
5. В **Server Command Bar** выполнить:

   `require(game.ServerStorage.MoonfallAuthoring.Bake).run("BAKE_MOONFALL_TERRAIN_V11")`

6. Проверить Terrain, дороги, высоты, воду, POI, spawn anchors и северные зоны.
7. Убедиться, что Goblin/Cemetery lake не появился.
8. Сохранить Place. Полученный root маркируется `ManagedBy=MoonfallAuthoredWorld`, поэтому generator не сможет молча перезаписать его повторным rebuild.
9. Переключить Studio на production `projects/moonfall.project.json` и запустить без authoring tooling. Production runtime должен принять authored root и не генерировать мир заново.

Physical bake и визуальное сравнение остаются owner acceptance checkpoint.

## DevCombined и сохранённый authored root

`DevCombinedWorldBootstrap` различает два допустимых ownership-состояния `Workspace/LunaWorldPlayableBlockout`:

- `ManagedBy=PlayableWorldBlockout` — root принадлежит dev generator и может быть детерминированно перестроен;
- `ManagedBy=MoonfallAuthoredWorld` — root принадлежит принятому authored Place и переиспользуется без второго worldgen.

Два одноимённых root или неизвестный/missing `ManagedBy` по-прежнему останавливают bootstrap fail-closed. Обычный Rojo sync не требует ручного удаления принятого authored root. `stop()` освобождает traversal lifecycle, поэтому повторный `start()` в той же Studio session безопасен.
