from pathlib import Path
import json

ROOT = Path(__file__).parents[1]
def read(path): return (ROOT / path).read_text()

account = read("src/shared/persistence/AccountSchema.luau")
migration = read("src/shared/persistence/MigrationRules.luau")
service = read("src/server/services/CharacterService.luau")
data = read("src/server/services/PlayerDataService.luau")
client = read("src/client/main.client.luau")
client_adapter = read("src/client/bootstrap/adapters/ExistingClientComponents.luau")
client_application = read("src/client/bootstrap/ClientApplication.luau")
dev_client_manifest = read("src/client/bootstrap/manifests/DevCombinedClientManifest.luau")
lobby = read("src/client/features/lobby/CharacterLobbyController.luau")
project = json.loads(read("default.project.json"))

assert "DataVersion = 3" in account
for field in ("CharacterOrder", "Characters", "SelectedCharacterId", "CharacterSlotLimit"):
    assert field in account and field in migration
for action in ('action == "Create"', 'action == "Select"', 'action == "Delete"', 'action == "CheckNickname"', 'action == "CompleteIdentity"', 'action == "UpdateSettings"'):
    assert action in service
nickname_store = read("src/server/persistence/NicknameStore.luau")
assert "UpdateAsync" in nickname_store
assert "UseDataStoreInStudio" in nickname_store and "studioIndex" in nickname_store
assert "FilterStringAsync" in service and "CharacterNotOwned" in service
assert "Players.CharacterAutoLoads = false" in data
assert "AccountReady" in data and "CharacterReady" in data
assert "ClientApplication.new" in client
assert dev_client_manifest.index("Components.characterLobby()") < dev_client_manifest.index("Components.gameplay()")
assert 'GetAttribute("CharacterReady")' in client_application and "startGameplay()" in client_adapter
assert "ResponsiveLayout.observe" in lobby and "DeleteConfirmation" in lobby
assert "IgnoreGuiInset = true" in lobby and "Size = UDim2.fromScale(1, 1)" in lobby
assert "geometryChanged" in lobby and "previousViewport" in lobby
assert "LastInputTypeChanged" in read("src/client/ui/ResponsiveLayout.luau")
assert "MobilePortrait" in lobby and "CreationModal" in lobby and 'Name = "Close"' in lobby
assert "Мой Roblox ник" in lobby and "Имя свободно" in lobby
assert "Class_" in lobby and "Body_" in lobby and "refreshClassButtons" in lobby and "refreshBodyButtons" in lobby
assert "SettingsButton" not in lobby and "SettingsModal" not in lobby
assert "Studio: любое непустое имя" in lobby and "Имя доступно в Studio" in lobby
assert "palette.accent" in lobby and "palette.moon" in lobby and "palette.gold" not in lobby
assert "looseStudioNicknames" in service and "PersistenceConfig.UseDataStoreInStudio" in service
assert 'CharacterRules.validateCreation(p, looseStudioNicknames())' in service
combat_config = read("src/shared/config/CombatConfig.luau")
character_config = read("src/shared/config/CharacterConfig.luau")
respawn = read("src/server/services/RespawnService.luau")
combat = read("src/server/features/combat/CombatCoordinator.luau")
hud = read("src/client/ui/CombatHud.luau")
assert 'NicknameAttribute = "CharacterNickname"' in character_config
assert "player:SetAttribute(CombatConfig.ArchetypeAttribute, character.ArchetypeId)" in data
assert "player:SetAttribute(CharacterConfig.NicknameAttribute, character.Nickname or player.DisplayName)" in data
assert data.index("player:SetAttribute(CombatConfig.ArchetypeAttribute, character.ArchetypeId)") < data.index('setState(player, s, "CharacterReady")')
assert "humanoid.DisplayName = nickname" in respawn
assert "Character Lobby owns the first spawn" in respawn
assert "Never manufacture the default knight before Character Lobby selection" in combat
assert "initializeReadyPlayer" in combat
assert "CharacterConfig.NicknameAttribute" in hud and "updatePlayerName" in hud
assert "CharacterRequest" in project["tree"]["ReplicatedStorage"]["Remotes"]
server_bootstrap = read("src/server/main.server.luau")
server_adapter = read("src/server/bootstrap/adapters/ExistingServerComponents.luau")
assert server_bootstrap.index("Players.CharacterAutoLoads = false") < server_bootstrap.index("ServerBootstrap.start(manifest)")
assert "MoonfallAuthoringContract.RootName" in server_adapter
print("character lobby contract: PASS")
