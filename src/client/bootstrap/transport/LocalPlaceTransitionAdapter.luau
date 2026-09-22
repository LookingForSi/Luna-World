--!strict

local LocalPlaceTransitionAdapter = {}

export type Adapter = {
	enterWorld: (characterId: string) -> (boolean, string?),
}

function LocalPlaceTransitionAdapter.new(selectCharacter: (string) -> ()): Adapter
	return table.freeze({
		enterWorld = function(characterId: string): (boolean, string?)
			if characterId == "" then
				return false, "InvalidCharacterId"
			end
			selectCharacter(characterId)
			return true, nil
		end,
	})
end

return table.freeze(LocalPlaceTransitionAdapter)
