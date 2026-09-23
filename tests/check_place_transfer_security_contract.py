from pathlib import Path

root = Path(__file__).resolve().parents[1]
transfer = (root / "src/server/core/transfer/PlaceTransferService.luau").read_text()
arrival = (root / "src/server/core/transfer/PlaceArrivalService.luau").read_text()
store = (root / "src/server/core/transfer/MemoryStoreTransferIntentStore.luau").read_text()
rules = (root / "src/shared/core/transfer/TransferIntentRules.luau").read_text()
data = (root / "src/server/services/PlayerDataService.luau").read_text()
character = (root / "src/server/services/CharacterService.luau").read_text()
client = (root / "src/client/main.client.luau").read_text()
lobby = (root / "src/server/bootstrap/manifests/LobbyServerManifest.luau").read_text()
world = (root / "src/server/bootstrap/manifests/WorldServerManifest.luau").read_text()

assert transfer.index("beginTransfer") < transfer.index("intents:create") < transfer.index("gateway:teleport")
assert "onInitFailed" in transfer and "recoverTransfer" in transfer
for call in ("getActiveCharacterId", "beginTransfer", "recoverTransfer", "failSession"):
    assert f"self.data.{call}(" in transfer
    assert f"self.data:{call}(" not in transfer
for call in ("selectCharacter", "confirmArrival", "failSession", "isAccountReady"):
    assert f"self.data.{call}(" in arrival
    assert f"self.data:{call}(" not in arrival
assert "self.pending[player]" in transfer
assert "Rules.routingPayload(intent)" in transfer
assert "UpdateAsync" in store and "MemoryStoreService" in store
assert "intents:consume" in arrival and "intent.userId ~= player.UserId" in arrival
assert "entryPointId = payload.entryPointId" in arrival and "confirmArrival" in arrival
assert "failSession" in arrival and "Rules.validateRouting" in arrival
assert "AUTHORITATIVE_KEYS" in rules and "AuthoritativeStateForbidden" in rules
assert 'session.state ~= "CharacterReady"' in data
assert 'setState(player, session, "Transferring")' in data
assert 'setState(player, session, "AccountReady")' in data
assert "cancelPreparedTransfer" in data and "cancelPreparedTransfer" in character
assert "TeleportTransitionAdapter.new(selectCharacter)" in client
assert "Components.placeTransfer()" in lobby
assert 'Components.placeArrival("World")' in world
assert 'Components.placeArrival("Dungeon")' not in (root / "src/server/bootstrap/manifests/DungeonServerManifest.luau").read_text()
print("place transfer security contract passed")
