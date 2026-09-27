# Канонический authored Place Moonfall

`moonfall.manifest.json` описывает принятый production baseline:
`tools/worldgen/moonfall-current-accepted.rbxlx` (путь `artifact` относительно manifest).
Его SHA-256: `e7346cdc211c6e1e1e41df8f258d7537b751f4a93402448d53ad049c935cd9ba`.

Файл под историческим каталогом worldgen является каноническим authored export,
а не результатом повторной генерации. Второй canonical `.rbxlx` здесь не хранится.
`.gitattributes` отключает преобразование его строк, сохраняя SHA на Windows/Linux.

`tools/deploy/build.py` проверяет source/SHA и накладывает текущие production
code/config из Git. Workspace (включая Terrain/static geometry), Lighting и прочее
неуправляемое окружение сохраняются. Подробности: `docs/MULTI_PLACE_DEPLOYMENT.md`.
