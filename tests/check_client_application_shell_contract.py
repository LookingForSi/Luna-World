#!/usr/bin/env python3
"""Gate B static ownership/readiness/lifecycle contract."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


main = read("src/client/main.client.luau")
application = read("src/client/bootstrap/ClientApplication.luau")
lobby = read("src/client/bootstrap/LobbyClientRuntime.luau")
gameplay = read("src/client/bootstrap/GameplayClientRuntime.luau")
local_transition = read("src/client/bootstrap/transport/LocalPlaceTransitionAdapter.luau")
teleport_transition = read("src/client/bootstrap/transport/TeleportTransitionAdapter.luau")
controller = read("src/client/controllers/CharacterLobbyController.luau")

assert "ClientApplication.new" in main and "application:start" in main
assert "LocalPlaceTransitionAdapter.new" in main
assert "TeleportTransitionAdapter.new" in main
assert "TeleportService" not in teleport_transition, "the client must not own teleport authority"

assert "Components.characterLobby(onEnterWorld)" in lobby
assert "Components.gameplay()" not in lobby
assert "Components.gameplay()" in gameplay
assert "characterLobby" not in gameplay

assert 'GetAttribute("CharacterReady")' in application
assert 'GetAttribute("ArrivalReady")' in application
assert "gate:setArrivalReady" in application
assert application.index("self.lobby:stop()") < application.index("self.gameplay:start()")
assert "self.characterReadyConnection:Disconnect()" in application
assert "self.arrivalReadyConnection:Disconnect()" in application
assert "self.gate:destroy()" in application
assert "local lobbyStopped, lobbyStopError = pcall" in application
assert "if nextState == self.state" in application

assert "onEnterWorld(chosen.characterId)" in controller
assert "resultConnection:Disconnect()" in controller
assert "accountReadyConnection:Disconnect()" in controller
assert 'selectCharacter(characterId)' in local_transition
for forbidden in ("Luna", "Inventory", "XP", "profile"):
    assert forbidden not in local_transition, f"local transition carries authoritative field {forbidden}"

print("Client application shell contract: PASS")
