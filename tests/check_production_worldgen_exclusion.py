from pathlib import Path
for project in ('lobby','moonfall','dungeon-selene'):
 text=Path(f'projects/{project}.project.json').read_text()
 assert 'src/server/world' not in text and 'tools/worldgen' not in text
assert 'PlayableWorldBlockout.rebuild()' not in Path('src/server/features/world/MoonfallWorldRuntime.luau').read_text()
assert 'LakeBasin' not in Path('tools/worldgen/moonfall/PlayableWorldBlockout.luau').read_text()
print('Production worldgen exclusion: PASS')
