from pathlib import Path

root = Path(__file__).resolve().parents[1]
transfer = (root / "src/server/core/transfer/PlaceTransferService.luau").read_text()
arrival = (root / "src/server/core/transfer/PlaceArrivalService.luau").read_text()
store = (root / "src/server/core/transfer/MemoryStoreTransferIntentStore.luau").read_text()
rules = (root / "src/shared/core/transfer/TransferIntentRules.luau").read_text()
data = (root / "src/server/services/PlayerDataService.luau").read_text()
lobby = (root / "src/server/bootstrap/manifests/LobbyServerManifest.luau").read_text()
world = (root / "src/server/bootstrap/manifests/WorldServerManifest.luau").read_text()

assert transfer.index("beginTransfer") < transfer.index("intents:create") < transfer.index("gateway:teleport")
assert "onInitFailed" in transfer and "recoverTransfer" in transfer
assert "self.pending[player]" in transfer
assert "Rules.routingPayload(intent)" in transfer
assert "UpdateAsync" in store and "MemoryStoreService" in store
assert "intents:consume" in arrival and "intent.userId ~= player.UserId" in arrival
assert "failSession" in arrival and "Rules.validateRouting" in arrival
assert "AUTHORITATIVE_KEYS" in rules and "AuthoritativeStateForbidden" in rules
assert 'session.state ~= "CharacterReady"' in data
assert "Components.placeTransfer()" in lobby
assert 'Components.placeArrival("World")' in world
print("place transfer security contract passed")
