from pathlib import Path
adapter=Path('src/client/bootstrap/adapters/ExistingClientComponents.luau').read_text()
assert 'features.lobby.CharacterLobbyController' in adapter
assert 'features.quests.QuestController' in adapter
for path in ('lobby/CharacterLobbyScreen','lobby/CharacterCreationModal','lobby/CharacterDeleteModal','lobby/LegacyIdentityModal','quests/QuestJournalScreen','quests/QuestOfferModal','quests/NpcDialogueModal','quests/TravelConfirmModal','quests/WorldMapScreen','quests/QuestNavigationPresenter'):
 assert Path('src/client/features',path+'.luau').exists()
print('Client feature ownership seams: PASS')
