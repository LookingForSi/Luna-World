# Инструменты генерации Moonfall

Этот каталог используется только для одноразовой генерации и preview в Studio. Production Moonfall не должен запускать `PlayableWorldBlockout.rebuild()` при старте сервера. После генерации владелец сохраняет Terrain и статическое окружение непосредственно в Place и сравнивает anchors, дороги, воду и POI с принятым baseline.
