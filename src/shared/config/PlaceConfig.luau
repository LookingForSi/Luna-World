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

return table.freeze(PlaceConfig)
