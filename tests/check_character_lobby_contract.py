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
assert "UpdateAsync" in read("src/server/persistence/NicknameStore.luau")
assert "FilterStringAsync" in service and "CharacterNotOwned" in service
assert "Players.CharacterAutoLoads = false" in data
assert "AccountReady" in data and "CharacterReady" in data
assert client.index("CharacterLobbyController.start()") < client.index('GetAttribute("CharacterReady")')
assert "ResponsiveLayout.observe" in lobby and "DeleteConfirmation" in lobby
assert "CharacterRequest" in project["tree"]["ReplicatedStorage"]["Remotes"]
print("character lobby contract: PASS")
