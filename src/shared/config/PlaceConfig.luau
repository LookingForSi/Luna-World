--!strict

local PlaceRole = require(script.Parent.Parent.core.runtime.PlaceRole)

export type Deployment = {
	gameId: number,
	roles: { [number]: PlaceRole.PlaceRole },
}

local deployments: { Deployment } = {
	{
		gameId = 10767283011,
		roles = {
			[81197415020315] = PlaceRole.Lobby,
			[133570003635782] = PlaceRole.World,
			[72524197323645] = PlaceRole.Dungeon,
		},
	},
}

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
