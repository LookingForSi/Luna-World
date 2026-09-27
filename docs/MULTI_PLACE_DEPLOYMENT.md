# Развёртывание нескольких Places

## Production-контур

Production multi-place контур Luna World зафиксирован в `PlaceConfig` и `tools/deploy/production.json`:

- Experience / GameId: `10767283011`;
- Lobby: `81197415020315`;
- Moonfall World: `133570003635782`;
- Ruins of Selene: `72524197323645`.

`PlaceConfig` работает fail-closed: неизвестный `GameId` или `PlaceId` не превращается в `DevCombined`. Роль `DevCombined` разрешена только явным Studio-контуром.

## Source of truth и обнаруженный разрыв

- **Lobby**: `projects/lobby.project.json` и Git-managed `src/**`; полностью собирается Rojo.
- **Ruins of Selene**: `projects/dungeon-selene.project.json` и Git-managed `src/**`; полностью собирается Rojo.
- **Moonfall runtime code**: `projects/moonfall.project.json` и `src/**`.
- **Moonfall Terrain/static environment**: принят только внутри production Place. В Git пока есть contracts и generator tooling, но нет точного export принятого мира.

`rojo build projects/moonfall.project.json` создаёт code-only Place без сохранённых Terrain/static instances. Публикация такого файла whole-place API уничтожила бы принятый мир. Поэтому этот build **никогда** не является deployment artifact. `tools/deploy/build.py` принимает Moonfall только как полный проверенный `deploy/canonical/moonfall.rbxlx`, сверяет его SHA-256 и требует `ready: true` в manifest. Пока файла нет, guard закрыт и GitHub Actions не может начать ни одну сетевую публикацию.

Следовательно, сейчас чистый checkout безопасно воспроизводит Lobby и Ruins, но не все три Places. Это намеренный fail-closed промежуточный контур.

## Development, authoring и production

- **Development**: `default.project.json` / `projects/dev-combined.project.json` в Studio; не публикуется.
- **Authoring**: `projects/moonfall-authoring.project.json` выполняет one-shot bake на backup/copy; не является runtime Place и не публикуется.
- **Production**: Lobby, полный canonical authored Moonfall и Ruins. Test, preview, authoring и DevCombined projects исключены из deployment config.

`tools/worldgen` разрешён только в development/authoring projects. Production projects его не маппят и не запускают `PlayableWorldBlockout.rebuild()`. После однократной миграции полный canonical Moonfall export становится source of truth для развёртываемого authored Place; layout contracts, generator tooling и gameplay source остаются в своих Git-каталогах.

## Однократная миграция Moonfall в Git

1. Сделать backup/copy production Moonfall `133570003635782` и записать текущую опубликованную version для rollback.
2. Открыть copy в Studio и визуально подтвердить, что это принятый v0.1.0 Terrain/static environment.
3. Синхронизировать на copy **production** `projects/moonfall.project.json`, не authoring project. Не запускать worldgen.
4. Выполнить solo runtime smoke: root `ManagedBy=MoonfallAuthoredWorld`, ожидаемая terrain revision, `LunaVillageSpawn`, дороги, encounter floors и gameplay intact.
5. Сохранить copy локально как полный XML Place `deploy/canonical/moonfall.rbxlx` (`Save to File`, формат `.rbxlx`). Не использовать результат `rojo build`.
6. Выполнить `sha256sum deploy/canonical/moonfall.rbxlx`; записать digest в `deploy/canonical/moonfall.manifest.json` и переключить `ready` в `true`.
7. Выполнить `python3 tools/deploy/build.py`, открыть `artifacts/deploy/moonfall.rbxlx` в Studio и повторить визуальный/runtime acceptance на backup/copy.
8. Закоммитить `.rbxlx` и manifest вместе. Если размер превышает GitHub limits, до commit настроить Git LFS для этого единственного пути; не хранить файл как Actions secret/artifact.

Эта миграция является **DEFERRED — pending owner runtime acceptance**. До неё production workflow закономерно падает до deploy job.

## Сборка

Rokit закрепляет Rojo `7.7.0`. Полная production сборка:

```bash
python3 tools/deploy/build.py
```

Результаты: `artifacts/deploy/dungeon-selene.rbxlx`, `moonfall.rbxlx`, `lobby.rbxlx`. Для аудита до миграции можно собрать только безопасные Places:

```bash
python3 tools/deploy/build.py --allow-incomplete-moonfall
```

Этот флаг не создаёт Moonfall и не используется workflow для публикации.

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

1. Завершить и закоммитить однократную миграцию Moonfall выше; проверить clean checkout и полный `python3 tools/deploy/build.py`.
2. Убедиться, что `VERSION` и runtime BuildInfo равны `0.1.0`, ref — merge commit в `main` или `v0.1.0`, Lobby остаётся Start Place.
3. Записать текущие опубликованные Roblox version всех трёх Places для rollback.
4. Проверить Environment `ROBLOX_API_KEY`, required reviewer и secret с `universe-places:write` только для universe `10767283011`.
5. Вручную запустить workflow на проверенном ref; подтвердить Environment только после зелёного build job; сверить summary и версии.
6. Published-client smoke: Lobby → видимая версия v0.1.0 → Moonfall (мир и gameplay intact) → Ruins → возврат в Moonfall.
7. Multiplayer acceptance: 1 server + 2 clients → party → Moonfall → reserved-server handoff в Ruins → retreat/return.

Пункты 5–7 не выполняются агентом и остаются **DEFERRED — pending owner runtime acceptance**.
