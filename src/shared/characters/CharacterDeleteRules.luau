--!strict

local CharacterDeleteRules = {}

function CharacterDeleteRules.removeOwned(account: any, characterId: string): (boolean, unknown)
	local character = account.Characters[characterId]
	if character == nil then return false, nil end
	account.Characters[characterId] = nil
	local index = table.find(account.CharacterOrder, characterId)
	if index ~= nil then table.remove(account.CharacterOrder, index) end
	if account.SelectedCharacterId == characterId then account.SelectedCharacterId = nil end
	return true, character.Nickname
end

return table.freeze(CharacterDeleteRules)
