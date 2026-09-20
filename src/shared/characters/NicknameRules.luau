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
	-- Keep the live-game policy deliberately simple and capture-free.
	-- Lua string.match returns captures when the pattern contains them; the old
	-- repeated capture therefore returned nil for perfectly valid names such as
	-- "Astrafox". Validate the pieces explicitly instead.
	if string.match(trimmed, "^[A-Za-z][A-Za-z0-9_-]*$") == nil
		or string.match(trimmed, "[_-]$") ~= nil
		or string.match(trimmed, "[_-][_-]") ~= nil
	then
		return nil, "InvalidCharacters"
	end
	return string.lower(trimmed), nil
end

function NicknameRules.display(raw: string): string
	return string.match(raw, "^%s*(.-)%s*$") or raw
end

return table.freeze(NicknameRules)
