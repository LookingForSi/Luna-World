--!strict

local PlaceRole = require(script.Parent.Parent.core.runtime.PlaceRole)

export type Deployment = {
	gameId: number,
	roles: { [number]: PlaceRole.PlaceRole },
}

local deployments: { Deployment } = {}

-- Deployment IDs intentionally remain empty until physical test/production
-- Places are created in Gate D. Studio uses the explicit DevCombined default.
local PlaceConfig = {
	StudioDefaultRole = PlaceRole.DevCombined,
	Deployments = deployments,
}

function PlaceConfig.getPlaceId(gameId: number, role: PlaceRole.PlaceRole): number?
	for _, deployment in deployments do
		if deployment.gameId == gameId then
			for placeId, configuredRole in deployment.roles do
				if configuredRole == role then return placeId end
			end
		end
	end
	return nil
end

return table.freeze(PlaceConfig)
