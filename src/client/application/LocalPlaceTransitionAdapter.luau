--!strict
local LocalPlaceTransitionAdapter = {}
function LocalPlaceTransitionAdapter.transition(characterId: string, onReady: (string) -> ()): ()
	assert(characterId ~= "", "characterId is required")
	onReady(characterId)
end
return table.freeze(LocalPlaceTransitionAdapter)
