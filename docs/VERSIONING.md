# Luna World — Versioning

## 1. Game version

Luna World использует Semantic Versioning в формате:

`MAJOR.MINOR.PATCH`

До `1.0.0` проект находится в активной разработке, поэтому `0.x` releases могут содержать значимые изменения архитектуры и данных, но они всё равно должны быть управляемыми и задокументированными.

Примеры:

- `0.1.0` — первый Vertical Slice;
- `0.1.1` — исправления без нового крупного gameplay block;
- `0.2.0` — следующий существенный игровой milestone;
- `1.0.0` — первый полноценный публичный release, когда продукт и совместимость объявлены достаточно зрелыми.

## 2. Development prerelease

Во время разработки целевого релиза допускаются prerelease versions:

- `0.1.0-dev.0`;
- `0.1.0-dev.1`;
- `0.1.0-alpha.1`;
- `0.1.0-beta.1`;
- `0.1.0-rc.1`.

Текущая стартовая версия проекта: `0.1.0-dev.0`.

## 3. Когда меняется номер

### PATCH

Используется для совместимых исправлений и небольших корректировок уже выпущенного milestone:

- bug fixes;
- balance fixes без изменения концепции системы;
- UI fixes;
- safe performance improvements.

### MINOR

Используется для нового значимого функционального блока:

- новый регион;
- новая крупная система;
- новый progression phase;
- новый public milestone.

Для `0.x` minor bump также может сопровождать значимое изменение внутренних контрактов.

### MAJOR

До `1.0.0` не используется как обычный способ показать большой объём работы. Переход на `1.0.0` — отдельное продуктовое решение.

После `1.0.0` major означает намеренную несовместимость публично поддерживаемых контрактов.

## 4. Release tags

Release commit помечается Git tag:

`v0.1.0`

Prerelease при необходимости:

`v0.1.0-alpha.1`

Версия в `VERSION` должна соответствовать release/tag state.

## 5. Changelog

`CHANGELOG.md` содержит пользовательски или архитектурно значимые изменения.

Рекомендуемые группы:

- Added;
- Changed;
- Fixed;
- Removed;
- Security.

В процессе разработки изменения собираются в `[Unreleased]`, а при выпуске переносятся в секцию конкретной версии.

## 6. DataVersion — отдельная версия

Версия игры и версия persistent schema — разные вещи.

Пример:

```text
GameVersion = 0.4.0
DataVersion = 3
```

`DataVersion` увеличивается только при изменении структуры или semantics persistent player data, которое требует migration logic.

Нельзя использовать game SemVer как замену DataVersion.

## 7. Persistent migrations

При загрузке profile:

1. определяется сохранённый `DataVersion`;
2. migrations применяются последовательно;
3. результат валидируется;
4. только после успешной миграции profile используется текущими systems.

Например:

```text
v1 -> v2 -> v3
```

Предпочтительнее последовательные маленькие migrations, чем одна функция, пытающаяся распознать все исторические форматы.

## 8. Migration rules

Каждая migration должна быть:

- deterministic;
- идемпотентной в рамках предусмотренного вызова или защищённой от повторного применения;
- покрытой тестами на representative old data;
- не терять неизвестные/ценные данные без явного решения.

Нельзя считать failed migration поводом silently reset profile.

## 9. Milestone and refactor relationship

Перед новым `0.x.0` feature milestone выполняется stabilization/refactor gate из `DEVELOPMENT_RULES.md`.

Идея:

```text
feature milestone
    ↓
working tested state
    ↓
stabilization / refactor
    ↓
clean baseline
    ↓
next major feature milestone
```

Refactor сам по себе не обязан менять release version, если behavior не изменился и новый release не готовится.

## 10. Документирование breaking changes

Если до `1.0.0` всё же меняется внутренний контракт, save schema или developer workflow несовместимым образом:

- изменение явно отмечается в changelog/docs;
- migration/update instructions добавляются до merge;
- зависимые modules обновляются в той же согласованной серии изменений.

Скрытые breaking changes запрещены.
