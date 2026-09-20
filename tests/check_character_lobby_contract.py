from pathlib import Path
import json

ROOT = Path(__file__).parents[1]
def read(path): return (ROOT / path).read_text()

account = read("src/shared/persistence/AccountSchema.luau")
migration = read("src/shared/persistence/MigrationRules.luau")
service = read("src/server/services/CharacterService.luau")
data = read("src/server/services/PlayerDataService.luau")
client = read("src/client/main.client.luau")
lobby = read("src/client/controllers/CharacterLobbyController.luau")
project = json.loads(read("default.project.json"))

assert "DataVersion = 3" in account
for field in ("CharacterOrder", "Characters", "SelectedCharacterId", "CharacterSlotLimit"):
    assert field in account and field in migration
for action in ('action == "Create"', 'action == "Select"', 'action == "Delete"', 'action == "CheckNickname"', 'action == "CompleteIdentity"'):
    assert action in service
nickname_store = read("src/server/persistence/NicknameStore.luau")
assert "UpdateAsync" in nickname_store
assert "UseDataStoreInStudio" in nickname_store and "studioIndex" in nickname_store
assert "FilterStringAsync" in service and "CharacterNotOwned" in service
assert "Players.CharacterAutoLoads = false" in data
assert "AccountReady" in data and "CharacterReady" in data
assert client.index("CharacterLobbyController.start()") < client.index('GetAttribute("CharacterReady")')
assert "ResponsiveLayout.observe" in lobby and "DeleteConfirmation" in lobby
assert "IgnoreGuiInset = true" in lobby and "Size = UDim2.fromScale(1, 1)" in lobby
assert "geometryChanged" in lobby and "previousViewport" in lobby
assert "LastInputTypeChanged" in read("src/client/ui/ResponsiveLayout.luau")
assert "MobilePortrait" in lobby and "CreationModal" in lobby and 'Name = "Close"' in lobby
assert "Мой Roblox ник" in lobby and "Имя свободно" in lobby
assert "CharacterRequest" in project["tree"]["ReplicatedStorage"]["Remotes"]
server_bootstrap = read("src/server/main.server.luau")
assert server_bootstrap.index("Players.CharacterAutoLoads = false") < server_bootstrap.index('WaitForChild("LunaWorldPlayableBlockout"')
print("character lobby contract: PASS")
