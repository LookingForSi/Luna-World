--!strict

local CharacterConfig = require(script.Parent.Parent.config.CharacterConfig)
local ProfileSchema = require(script.Parent.ProfileSchema)
local PersistenceTypes = require(script.Parent.Parent.types.PersistenceTypes)

local AccountSchema = {}
AccountSchema.DataVersion = 3

local function deepClone(value: any): any
	if typeof(value) ~= "table" then
		return value
	end
	local result = {}
	for key, child in value do
		result[deepClone(key)] = deepClone(child)
	end
	return result
end

function AccountSchema.createDefault(): PersistenceTypes.AccountProfile
	return {
		DataVersion = AccountSchema.DataVersion,
		CharacterSlotLimit = CharacterConfig.CharacterSlotLimit,
		CharacterOrder = {},
		Characters = {},
		SelectedCharacterId = nil,
		Settings = { UiScale = 1, TextScale = 1, SoundVolume = 1 },
	}
end

function AccountSchema.clone(account: PersistenceTypes.AccountProfile): PersistenceTypes.AccountProfile
	return deepClone(account) :: PersistenceTypes.AccountProfile
end

function AccountSchema.validateCurrent(raw: unknown): (boolean, string?)
	if typeof(raw) ~= "table" then
		return false, "account must be a table"
	end
	local account: any = raw
	if account.DataVersion ~= AccountSchema.DataVersion then
		return false, "account DataVersion is not current"
	end
	if typeof(account.CharacterSlotLimit) ~= "number" or account.CharacterSlotLimit < 1 then
		return false, "invalid character slot limit"
	end
	if typeof(account.CharacterOrder) ~= "table" or typeof(account.Characters) ~= "table" then
		return false, "invalid character roster"
	end
	if
		#account.CharacterOrder > account.CharacterSlotLimit
		or #account.CharacterOrder > CharacterConfig.CharacterSlotLimit
	then
		return false, "character slot limit exceeded"
	end
	local seen = {}
	for _, characterId in account.CharacterOrder do
		if
			typeof(characterId) ~= "string"
			or seen[characterId]
			or typeof(account.Characters[characterId]) ~= "table"
		then
			return false, "invalid character order"
		end
		seen[characterId] = true
		local character = account.Characters[characterId]
		if character.CharacterId ~= characterId then
			return false, "character id mismatch"
		end
		if
			typeof(character.CreatedAt) ~= "number"
			or typeof(character.LastPlayedAt) ~= "number"
			or typeof(character.NeedsIdentity) ~= "boolean"
		then
			return false, "invalid character metadata"
		end
		if character.BodyType ~= nil and character.BodyType ~= "male" and character.BodyType ~= "female" then
			return false, "invalid body type"
		end
		if character.Nickname ~= nil and typeof(character.Nickname) ~= "string" then
			return false, "invalid nickname"
		end
		local gameplay = ProfileSchema.clone(character)
		gameplay.DataVersion = ProfileSchema.DataVersion
		local valid, reason = ProfileSchema.validateCurrent(gameplay)
		if not valid then
			return false, reason
		end
	end
	for characterId in account.Characters do
		if not seen[characterId] then
			return false, "unordered character"
		end
	end
	if account.SelectedCharacterId ~= nil and account.Characters[account.SelectedCharacterId] == nil then
		return false, "selected character is missing"
	end
	if typeof(account.Settings) ~= "table" then
		return false, "invalid settings"
	end
	return true, nil
end

return table.freeze(AccountSchema)
