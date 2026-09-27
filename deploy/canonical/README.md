# Канонический authored Place Moonfall

Этот каталог зарезервирован для полного принятого production-export
`moonfall.rbxlx`. Сейчас export отсутствует, а `moonfall.manifest.json` оставляет
guard в состоянии `ready: false`. Поэтому production build и публикация всех
трёх Places намеренно заблокированы.

Единственная допустимая процедура подготовки файла описана в
`docs/MULTI_PLACE_DEPLOYMENT.md`. Нельзя подменять его результатом code-only
`rojo build projects/moonfall.project.json`: такой build не содержит сохранённые
Terrain и static authored environment.
