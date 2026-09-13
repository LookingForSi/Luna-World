# Luna World — Refactoring Policy

## 1. Зачем нужен отдельный refactoring gate

Luna World будет развиваться итерациями, а AI-агенты и быстрые feature changes способны очень быстро накопить архитектурный долг. Поэтому между крупными milestone рефакторинг является частью процесса, а не задачей «когда-нибудь потом».

Цель — не идеальная архитектура, а сохранение понятной, тестируемой и безопасной базы перед следующим ростом функциональности.

## 2. Когда проводится

После каждого крупного milestone из `ROADMAP.md` выполняется stabilization/refactor gate **до начала следующего крупного feature block**.

Дополнительный внеплановый gate проводится, если появляется хотя бы один сигнал:

- модуль одновременно отвечает за несколько независимых systems;
- один gameplay rule реализован в нескольких местах;
- агенты регулярно неправильно понимают границы modules;
- изменения в одной системе вызывают неожиданные regressions в другой;
- Remote validation размазана по проекту и противоречива;
- save schema стало сложно безопасно менять;
- тесты трудно писать из-за сильной связанности;
- временные решения стали постоянными.

## 3. Обязательный порядок

Refactor gate начинается только с известного рабочего baseline.

1. Воспроизвести и закрыть критические regressions.
2. Запустить relevant tests.
3. Добавить недостающие characterization/regression tests для поведения, которое будет затронуто.
4. Удалить dead/debug/temporary code.
5. Уменьшить duplication.
6. Пересмотреть module boundaries и public interfaces.
7. Проверить server/client boundary и Remote validation.
8. Проверить lifecycle, cleanup, connections/tasks.
9. Проверить persistence schema и migrations.
10. Повторно запустить tests и multiplayer smoke test.
11. Обновить architecture/development docs.
12. Только после этого открыть следующий крупный feature milestone.

## 4. Что считается хорошим refactor

Хороший refactor:

- сохраняет подтверждённое gameplay behavior;
- уменьшает количество связей и скрытых зависимостей;
- делает contracts явнее;
- облегчает тестирование;
- удаляет временные обходы;
- не добавляет архитектуру «на всякий случай»;
- имеет понятную причину и проверяемый результат.

## 5. Что запрещено

Не допускается:

- полный rewrite «потому что теперь понятно, как сделать красиво» без необходимости;
- смешивание большого refactor и большого gameplay feature в одном непрозрачном изменении;
- удаление тестов, которые мешают новой структуре, без изменения требований;
- изменение gameplay semantics под видом refactor;
- замена простых modules generic-framework'ом без доказанной пользы;
- изменение persistence IDs или schema без migration plan.

## 6. Feature freeze на время gate

Во время крупного stabilization gate новые несвязанные features не добавляются.

Допускаются:

- bug fixes;
- tests;
- tooling, необходимый для проверки;
- documentation;
- structural changes внутри согласованного scope refactor.

Это позволяет получить чистый baseline, а не двигать цель одновременно с рефакторингом.

## 7. Результат gate

Gate считается завершённым, когда:

- relevant automated tests зелёные;
- multiplayer smoke test прошёл;
- нет необъяснённых recurring runtime errors;
- known structural debt, который сознательно остаётся, записан явно;
- docs отражают текущие contracts;
- следующий milestone может опираться на понятные interfaces без знания внутренних временных обходов.

## 8. Отношение к версиям

Refactor не обязан сам по себе повышать SemVer, если поведение и release state не изменились.

Но любой refactor, который всё же меняет публично значимое behavior, persistent schema или developer contract, должен быть отражён в `CHANGELOG.md`, а при необходимости — в release version и migration instructions.
