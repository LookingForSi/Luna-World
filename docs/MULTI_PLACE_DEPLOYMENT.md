# Развёртывание нескольких Places

## Production-контур

Production multi-place контур Luna World зафиксирован в `PlaceConfig` и `tools/deploy/production.json`:

- Experience / GameId: `10767283011`;
- Lobby: `81197415020315`;
- Moonfall World: `133570003635782`;
- Ruins of Selene: `72524197323645`.

`PlaceConfig` работает fail-closed: неизвестный `GameId` или `PlaceId` не превращается в `DevCombined`. Роль `DevCombined` разрешена только явным Studio-контуром.

## Source of truth

- **Lobby**: `projects/lobby.project.json` и Git-managed `src/**`; полностью собирается Rojo.
- **Ruins of Selene**: `projects/dungeon-selene.project.json` и Git-managed `src/**`; полностью собирается Rojo.
- **Moonfall runtime code**: `projects/moonfall.project.json` и `src/**`.
- **Moonfall Terrain/static environment**: принятый owner-side export `tools/worldgen/moonfall-current-accepted.rbxlx`, уже сохранённый в Git. Это текущий канонический authored baseline, несмотря на историческое расположение под worldgen.

`rojo build projects/moonfall.project.json` создаёт code-only Place без сохранённых Terrain/static instances. Поэтому он используется только как источник текущего production code/config для overlay и **никогда** не публикуется самостоятельно. `tools/deploy/build.py` проверяет canonical path, source Place ID, release version и SHA-256 baseline; manifest `deploy/canonical/moonfall.manifest.json` имеет `ready: true`.

Принятый SHA-256: `e7346cdc211c6e1e1e41df8f258d7537b751f4a93402448d53ad049c935cd9ba`.
`.gitattributes` запрещает преобразование строк этого файла при checkout, в том
числе на Windows. Второй canonical export в `deploy/canonical` не создаётся.

Сборка заменяет целиком управляемые поддеревья `ReplicatedStorage/Shared`,
`ReplicatedStorage/Remotes`, `ReplicatedStorage/StudioPlaceRole`,
`ServerScriptService/Server`, `StarterPlayer/StarterPlayerScripts/Client`.
Так удаляется устаревший код и добавляется текущий код Git, включая BuildInfo
`0.1.0`. Контейнеры и прочее authored окружение сохраняются; остаточный
`ServerStorage/MoonfallAuthoring` удаляется из выходного файла. Worldgen не запускается.
Referents согласуются по путям экземпляров; неоднозначные управляемые пути,
dangling references, неожиданные исполняемые модули и неподдерживаемые изменения
ownership останавливают сборку. Одноимённые authored props вне управляемых путей
допустимы.

Overlay работает с исходной Studio/Rojo serialization как с байтами и заменяет
только полные `<Item>` управляемых корней. Полная пересериализация canonical Place
через generic XML writer запрещена: она удаляет CDATA и namespace declarations,
переписывает binary/empty property representation и может создать XML, который
Studio открывает локально, но Open Cloud Place Publishing отклоняет как
`Invalid Content stream`. После сборки проверяется побайтная неизменность полного
Workspace (Terrain и static environment) и Lighting. Канонический входной файл
не изменяется.

## Development, authoring и production

- **Development**: `default.project.json` / `projects/dev-combined.project.json` в Studio; не публикуется.
- **Authoring**: `projects/moonfall-authoring.project.json` выполняет one-shot bake на backup/copy; не является runtime Place и не публикуется.
- **Production**: Lobby, полный canonical authored Moonfall и Ruins. Test, preview, authoring и DevCombined projects исключены из deployment config.

Код `tools/worldgen` разрешён только в development/authoring projects. Production projects его не маппят и не запускают `PlayableWorldBlockout.rebuild()`. Сохранённый в этом каталоге canonical Moonfall export — отдельный authored asset; layout contracts, generator tooling и gameplay source остаются в своих Git-каталогах.

## Обновление принятого authored baseline

Первичная owner-side миграция выполнена: принятый export находится в Git.
Для будущего изменения окружения владелец сохраняет backup production version,
принимает изменённый Place в Studio и заменяет тот же
`tools/worldgen/moonfall-current-accepted.rbxlx`, обновляя SHA в manifest вместе
с файлом. Повторная генерация текущего accepted Terrain для deployment запрещена.
Обычные code/config-изменения не требуют нового export: они поступают из Git при сборке.

Открытие собранного `artifacts/deploy/moonfall.rbxlx` на backup/copy и первый
managed production deployment остаются owner-side проверками; автоматическая
сохранность XML не заменяет runtime/visual acceptance Roblox.

## Сборка

Rokit закрепляет Rojo `7.7.0`. Полная production сборка:

```bash
python3 tools/deploy/build.py
```

Результаты: `artifacts/deploy/dungeon-selene.rbxlx`, `moonfall.rbxlx`, `lobby.rbxlx`.
Сначала весь набор собирается и проверяется во временном каталоге, затем файлы
переносятся в output. Режим неполной сборки удалён. Ошибка source/SHA или overlay
по-прежнему блокирует deployment job до публикации любого Place.

## Публикация и порядок

Локальная команда предназначена для аварийно контролируемого запуска только после полной сборки:

```bash
ROBLOX_API_KEY='...' python3 tools/deploy/publish.py
```

Ключ не сохраняется и не печатается. Скрипт предварительно проверяет все три artifact, затем вызывает официальный Place Publishing API с `versionType=Published` строго fail-fast:

1. Ruins of Selene;
2. Moonfall World;
3. Lobby.

Entry point публикуется последним, чтобы новый Lobby не отправлял игроков в ещё старые destinations.

## GitHub Actions

Workflow `.github/workflows/roblox-deploy.yml` запускается только вручную (`workflow_dispatch`) от `main` либо SemVer release tag `vMAJOR.MINOR.PATCH`, чей commit входит в `main`. Build/contract job не имеет environment secret и обязан завершить весь artifact set до deploy job. Deploy job использует GitHub Environment `ROBLOX_API_KEY` и одноимённый secret с `universe-places:write`. Для Environment рекомендуется required reviewer protection.

После merge владелец выбирает Actions → Roblox Production Deploy → Run workflow, проверяет ref и подтверждает Environment. Summary содержит commit SHA и ответы Roblox с версиями Places. Запуск с feature branch будет отклонён.

## Откат

Fail-fast не является транзакцией: если следующий Place упал, уже опубликованный нужно откатить через Roblox Creator Dashboard на записанную предыдущую version. Откатывать в обратном порядке затронутой части, оставляя Lobby согласованным с destinations. Для полного неудачного релиза: Lobby → Moonfall → Ruins. Затем повторить smoke test. Не менять production IDs, не включать DevCombined и не передавать profile state через `TeleportData`.

## Первый production deploy v0.1.0 — OWNER CHECKLIST

1. Включить обновлённую сборку в `main`; проверить clean checkout и полный `python3 tools/deploy/build.py`; открыть собранный Moonfall на backup/copy в Studio и подтвердить сохранность мира и runtime.
2. Убедиться, что `VERSION` и runtime BuildInfo равны `0.1.0`, ref — merge commit в `main` или `v0.1.0`, Lobby остаётся Start Place.
3. Записать текущие опубликованные Roblox version всех трёх Places для rollback.
4. Проверить Environment `ROBLOX_API_KEY`, required reviewer и secret с `universe-places:write` только для universe `10767283011`.
5. Вручную запустить workflow на проверенном ref; подтвердить Environment только после зелёного build job; сверить summary и версии.
6. Published-client smoke: Lobby → видимая версия v0.1.0 → Moonfall (мир и gameplay intact) → Ruins → возврат в Moonfall.
7. Multiplayer acceptance: 1 server + 2 clients → party → Moonfall → reserved-server handoff в Ruins → retreat/return.

Пункты 5–7 не выполняются агентом и остаются **DEFERRED — pending owner runtime acceptance**.
