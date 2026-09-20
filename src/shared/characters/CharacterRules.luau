--!strict

local ArchetypeDefinitions = require(script.Parent.Parent.definitions.ArchetypeDefinitions)
local CharacterConfig = require(script.Parent.Parent.config.CharacterConfig)
local NicknameRules = require(script.Parent.NicknameRules)

local CharacterRules = {}

function CharacterRules.validateCreation(payload: unknown): (boolean, string?)
	if typeof(payload) ~= "table" then
		return false, "InvalidPayload"
	end
	local value: any = payload
	local _, nicknameError = NicknameRules.normalize(value.nickname)
	if nicknameError ~= nil then
		return false, nicknameError
	end
	if typeof(value.archetypeId) ~= "string" or ArchetypeDefinitions[value.archetypeId] == nil then
		return false, "InvalidArchetype"
	end
	if value.bodyType ~= "male" and value.bodyType ~= "female" then
		return false, "InvalidBodyType"
	end
	if value.appearancePresetId ~= nil and value.appearancePresetId ~= "default" then
		return false, "InvalidAppearance"
	end
	return true, nil
end

function CharacterRules.hasCapacity(count: number, storedLimit: number?): boolean
	return count < math.min(storedLimit or CharacterConfig.CharacterSlotLimit, CharacterConfig.CharacterSlotLimit)
end

return table.freeze(CharacterRules)
