# World assets — pipeline v0.1

Эта папка фиксирует мост между принятым world-layout в Roblox и финальным art pass через Blender / Blender Studio.

## Принцип

География, ширина дорог, размеры encounter-зон, sightlines и no-jump traversal принимаются в Roblox **до** замены blockout-объектов финальными мешами.

Файл `world_asset_manifest_v01.json` перечисляет семейства ассетов, которые должны постепенно заменить объекты с атрибутами `ReplacementCategory` / `ArtReplacementTarget`.

## Что брать из Blender Studio

Приоритетно искать не готовую «карту», а модульные наборы:

- fantasy village / medieval timber houses;
- fences / farm props;
- stylized or semi-realistic rocks and cliff chunks;
- conifer / deciduous tree sets;
- dead trees / roots;
- ancient stone ruins;
- cemetery fragments;
- primitive camp / palisade pieces.

Даже платный ассет используется только если его лицензия допускает нужный экспорт и использование в игре. Наличие подписки само по себе не отменяет проверку лицензии конкретного ресурса.

## Импортный контракт

Для заменяемых объектов:

- pivot: у земли по центру;
- up: +Y;
- forward: -Z;
- scale: 1.0 по умолчанию;
- коллизия: простой proxy, а не сложная collision geometry исходного high-poly;
- декоративные кроны, паутина и мелкий clutter не должны блокировать игрока;
- критические дороги и slope-переходы нельзя сужать после замены blockout;
- финальный ассет должен сохранять footprint и читаемый силуэт принятого placeholder'а.

## Порядок первого art pass

1. Rocks + trees — быстрее всего меняют ощущение всей долины.
2. Village house + roof kit — формируют силуэт Luna Village.
3. Fence/farm kit — насыщает Meadows и Moonfall Farm.
4. Ancient ruins — Old Cemetery, Fallen Shrine, Ancient Approach.
5. Goblin kit.
6. Spider-specific deadwood/web/cave props.

Blockout не удаляется заранее: замена делается категория за категорией, чтобы можно было сравнивать traversal и композицию до/после.
