# Luna World UI Responsive Design System

## Цель

UI Luna World не должен зависеть от конкретной модели телефона, физического разрешения или списка устройств.
Основная единица принятия layout-решений — **реально доступный safe viewport**.

Архитектура использует гибрид:

1. **Adaptive composition** — при нехватке/избытке пространства меняется сама композиция.
2. **Responsive sizing** — внутри композиции размеры плавно следуют за viewport.
3. **Min/max constraints** — элементы не становятся ни слишком маленькими, ни чрезмерно большими.
4. **Content-driven layout** — list/grid/scroll/AutomaticSize предпочтительнее ручных абсолютных координат.

## 1. Не phone/tablet, а классы пространства

`ResponsiveLayout.Metrics.layoutClass`:

- `CompactLandscape` — короткий/узкий landscape viewport;
- `RegularLandscape` — обычный landscape phone / небольшое touch-окно;
- `ExpandedLandscape` — большой touch viewport / tablet;
- `PortraitFallback` — defensive fallback, production mobile должен быть landscape-only;
- `Desktop`.

Класс определяется по safe width + safe height, а не по названию устройства.

Планшет в split-screen может стать Regular/Compact. Большой телефон может оказаться Regular. Это ожидаемое поведение.

## 2. Fluid + clamp вместо фиксированного размера

Запрещён основной mobile-паттерн:

```lua
panel.Size = UDim2.fromOffset(210, 120)
```

Предпочтительно:

```lua
local width = ResponsiveLayout.fluidWidth(metrics, 0.22, 184, 248)
local height = ResponsiveLayout.fluidHeight(metrics, 0.30, 108, 132)
```

То есть:

```text
desired = viewport * ratio
result  = clamp(desired, minimum, maximum)
```

Pixels остаются как **guard rails**, а не как единственный источник геометрии.

## 3. Safe viewport

Для ScreenGui с `IgnoreGuiInset = true`:

- layout считается от physical viewport;
- `GuiService:GetGuiInset()` входит в `ResponsiveLayout.metrics()`;
- позиционирование к краям использует safe inset + `metrics.edge`;
- нельзя повторно добавлять inset внутри дочерних компонентов.

HUD anchors:
- status — top-right;
- target — top-center;
- log — bottom-left action-safe area;
- skills — bottom-center;
- primary actions — bottom-right.

## 4. Logical UI scale

`metrics.uiScale` нормализуется от доступного viewport и ограничен диапазоном.

Назначение:
- слегка поджать UI на маленьком телефоне;
- слегка увеличить на большом touch-screen;
- не превращать tablet UI в увеличенный screenshot телефона.

Использовать `ResponsiveLayout.scaled(...)` для padding, text sizes, auxiliary heights и secondary controls.
Не использовать uiScale как замену adaptive composition.

## 5. Touch target и visual size — разные понятия

`metrics.touchTarget`:
- минимум 44;
- максимум 56;
- между ними зависит от safe short side.

Визуальная иконка может быть меньше hit target.
Attack/primary actions могут иметь hit area больше secondary controls.

## 6. Content-driven layout

Приоритет:

1. `UIListLayout` / `UIGridLayout`;
2. flex/wrap;
3. `AutomaticSize`;
4. `UISizeConstraint`;
5. ScrollingFrame;
6. derived offsets из shared metrics;
7. hardcoded absolute coordinates — только для desktop/static art или локального декоративного элемента.

Форма Character Creation, recipe lists, inventory actions и topic choosers не должны зависеть от цепочки абсолютных Y для конкретного телефона.

## 7. Modal policy

Mobile/touch modal:

```text
width  <= safeWidth  * classWidthFraction
height <= safeHeight * classHeightFraction
width  <= desktopMaxWidth
height <= desktopMaxHeight
```

Compact занимает почти весь safe viewport.
Expanded перестаёт расти после разумного max.

Обязательно:
- header visible;
- close visible;
- footer critical actions visible;
- middle content scrollable;
- desktop MinSize constraints выключаются на touch;
- modal blocker не даёт gameplay принимать tap.

## 8. Adaptive composition

Responsive scaling не заменяет reflow.

### Blacksmith
Compact/Regular:
```text
[Рыцарь]   [Следопыт]
[Мистик]   [Материалы]
```

### Inventory
Landscape touch:
- item grid;
- equipment/details рядом;
- action footer.

PortraitFallback:
- вертикальный stack только как defensive режим.

### Character Lobby
Touch landscape:
- roster constrained примерно 31% safe width с min/max;
- preview занимает оставшееся пространство;
- card height зависит от safe height с clamp;
- preview actions привязаны к нижней границе content area.

## 9. Runtime resize

Layout должен переживать:
- изменение ViewportSize;
- camera replacement;
- orientation transition;
- tablet split-screen/resize;
- изменение input mode.

Не пересоздавать весь UI только из-за каждого LastInputTypeChanged, если геометрия не изменилась.

## 10. Desktop regression

Desktop остаётся отдельной composition.

Mobile architecture не должна:
- уменьшать desktop HUD глобальным UIScale;
- убирать desktop hotkeys;
- заменять 10-slot desktop bar шестью слотами;
- ломать desktop modal max sizes.

## 11. Правило для новых UI

Перед добавлением нового экрана ответить:

1. Где его anchor в safe viewport?
2. Что у него fluid?
3. Каковы min/max?
4. Какой minimum touch target?
5. Что происходит в Compact / Regular / Expanded?
6. Какие content areas scroll?
7. Что остаётся fixed header/footer?
8. Как он возвращается в Desktop?
9. Есть ли static contract, фиксирующий product semantics?

Если ответ сводится к «на iPhone поставить 215×120», implementation считается неполной.
