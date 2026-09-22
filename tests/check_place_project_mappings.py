from pathlib import Path
import json
for name in ('lobby','moonfall','dungeon-selene','dev-combined','tests'):
    data=json.loads(Path(f'projects/{name}.project.json').read_text())
    assert data['tree']['ReplicatedStorage']['Shared']['$path']=='../src/shared'
config=Path('src/shared/config/PlaceConfig.luau').read_text()
assert 'local deployments: { Deployment } = {}' in config
assert 'StudioDefaultRole = PlaceRole.DevCombined' in config
print('Place project mappings and fail-closed config: PASS')
