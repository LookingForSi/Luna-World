--!strict

local CharacterConfig = require(script.Parent.Parent.config.CharacterConfig)

local NicknameRules = {}

function NicknameRules.normalize(raw: unknown): (string?, string?)
	if typeof(raw) ~= "string" then
		return nil, "InvalidType"
	end
	local trimmed = string.match(raw, "^%s*(.-)%s*$") or ""
	if #trimmed < CharacterConfig.NicknameMinLength or #trimmed > CharacterConfig.NicknameMaxLength then
		return nil, "InvalidLength"
	end
	if string.match(trimmed, "^[A-Za-z][A-Za-z0-9]*([_-]?[A-Za-z0-9]+)*$") == nil then
		return nil, "InvalidCharacters"
	end
	return string.lower(trimmed), nil
end

function NicknameRules.display(raw: string): string
	return string.match(raw, "^%s*(.-)%s*$") or raw
end

return table.freeze(NicknameRules)
