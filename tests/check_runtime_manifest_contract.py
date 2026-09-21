#!/usr/bin/env python3
"""Static contract for Gate A place roles and runtime manifests."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read(path: str) -> str:
    candidate = ROOT / path
    assert candidate.exists(), f"missing Gate A file: {path}"
    return candidate.read_text(encoding="utf-8")

place_role = read("src/shared/core/runtime/PlaceRole.luau")
place_runtime = read("src/shared/core/runtime/PlaceRuntime.luau")
place_config = read("src/shared/config/PlaceConfig.luau")
runtime = read("src/shared/core/runtime/RuntimeManifest.luau")
server_main = read("src/server/main.server.luau")
client_main = read("src/client/main.client.luau")

for role in ("Lobby", "World", "Dungeon", "DevCombined"):
    assert f'"{role}"' in place_role
assert 'StudioDefaultRole = PlaceRole.DevCombined' in place_config
assert "local deployments: { Deployment } = {}" in place_config, "Gate A must not invent production Place IDs"
assert "PlaceRole override is allowed only in Studio" in place_runtime
assert "No production PlaceRole configured" in place_runtime
assert "currentRole" not in place_runtime, "PlaceRuntime must stay pure/stateless"

assert "for index = #started, 1, -1 do" in runtime
assert "pcall(component.start)" in runtime
assert "pcall(component.stop)" in runtime
assert "Duplicate runtime component" in runtime

for entrypoint in (server_main, client_main):
    assert "PlaceRuntime.resolve(game.PlaceId, game.GameId" in entrypoint
    assert "Bootstrap.start(manifest)" in entrypoint

allowed_place_id_files = {
    "src/server/main.server.luau",
    "src/client/main.client.luau",
}
actual_place_id_files = set()
for path in (ROOT / "src").rglob("*.luau"):
    if "game.PlaceId" in path.read_text(encoding="utf-8"):
        actual_place_id_files.add(path.relative_to(ROOT).as_posix())
assert actual_place_id_files <= allowed_place_id_files, (
    f"arbitrary game.PlaceId checks found: {sorted(actual_place_id_files - allowed_place_id_files)}"
)

lobby_server = read("src/server/bootstrap/manifests/LobbyServerManifest.luau")
world_server = read("src/server/bootstrap/manifests/WorldServerManifest.luau")
dungeon_server = read("src/server/bootstrap/manifests/DungeonServerManifest.luau")
dev_server = read("src/server/bootstrap/manifests/DevCombinedServerManifest.luau")

for forbidden in ("Components.combat()", "Components.mobs()", "Components.worldBootstrap()", "Components.npcWorld()"):
    assert forbidden not in lobby_server, f"Lobby server illegally contains {forbidden}"
assert "Components.character()" not in world_server, "World server must not boot Character Lobby service"
assert "Components.worldBootstrap()" not in world_server, "production World manifest must not own runtime worldgen"
for forbidden in ("Components.character()", "Components.economy()", "Components.economyWorld()", "Components.npcWorld()", "Components.travel()", "Components.quests()", "Components.worldBootstrap()"):
    assert forbidden not in dungeon_server, f"Dungeon server illegally contains {forbidden}"
assert "Components.worldBootstrap()" in dev_server
assert "Components.worldSpawnAnchor()" in dev_server
assert "Components.devCombinedGameplay()" in dev_server
assert "Components.character()" not in dev_server and "Components.combat()" not in dev_server

lobby_client = read("src/client/bootstrap/manifests/LobbyClientManifest.luau")
world_client = read("src/client/bootstrap/manifests/WorldClientManifest.luau")
dungeon_client = read("src/client/bootstrap/manifests/DungeonClientManifest.luau")
dev_client = read("src/client/bootstrap/manifests/DevCombinedClientManifest.luau")
assert "Components.characterLobby()" in lobby_client
assert "Components.gameplayAfterCharacterReady()" not in lobby_client
assert "Components.characterLobby()" not in world_client
assert "Components.characterLobby()" not in dungeon_client
assert "Components.characterLobby()" in dev_client and "Components.gameplayAfterCharacterReady()" in dev_client

print("Runtime manifest contract: PASS")
