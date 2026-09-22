--!strict

-- Gate C supplies the authoritative server transfer request. Gate B deliberately
-- exposes only a client presentation boundary and never invokes platform teleport APIs.
local TeleportTransitionAdapter = {}

export type Adapter = {
	enterWorld: (characterId: string) -> (boolean, string?),
}

function TeleportTransitionAdapter.new(requestTransfer: (string) -> ()): Adapter
	return table.freeze({
		enterWorld = function(characterId: string): (boolean, string?)
			if characterId == "" then
				return false, "InvalidCharacterId"
			end
			requestTransfer(characterId)
			return true, nil
		end,
	})
end

return table.freeze(TeleportTransitionAdapter)
