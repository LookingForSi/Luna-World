--!strict

local PlaceRole = require(script.Parent.PlaceRole)
local PlaceConfig = require(script.Parent.Parent.Parent.config.PlaceConfig)

local PlaceRuntime = {}

local function resolveConfiguredRole(placeId: number, gameId: number): PlaceRole.PlaceRole?
	for _, deployment in PlaceConfig.Deployments do
		if deployment.gameId == gameId then
			local role = deployment.roles[placeId]
			if role ~= nil then
				return PlaceRole.assertValid(role)
			end
			return nil
		end
	end
	return nil
end

function PlaceRuntime.resolve(
	placeId: number,
	gameId: number,
	isStudio: boolean,
	override: PlaceRole.PlaceRole?
): PlaceRole.PlaceRole
	if override ~= nil then
		local role = PlaceRole.assertValid(override)
		assert(isStudio, "PlaceRole override is allowed only in Studio")
		return role
	end

	if isStudio then
		return PlaceRole.assertValid(PlaceConfig.StudioDefaultRole)
	end

	local configured = resolveConfiguredRole(placeId, gameId)
	assert(
		configured ~= nil,
		string.format("No production PlaceRole configured for GameId=%d PlaceId=%d", gameId, placeId)
	)
	return configured
end

function PlaceRuntime.isLobby(role: PlaceRole.PlaceRole): boolean
	return role == PlaceRole.Lobby
end

function PlaceRuntime.isWorld(role: PlaceRole.PlaceRole): boolean
	return role == PlaceRole.World
end

function PlaceRuntime.isDungeon(role: PlaceRole.PlaceRole): boolean
	return role == PlaceRole.Dungeon
end

function PlaceRuntime.isDevCombined(role: PlaceRole.PlaceRole): boolean
	return role == PlaceRole.DevCombined
end

return table.freeze(PlaceRuntime)
