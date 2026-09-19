--!strict

local Workspace = game:GetService("Workspace")

local RAY_ORIGIN_Y = 320
local RAY_DISTANCE = 700

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { Workspace.Terrain }
params.IgnoreWater = true

local TerrainGrounding = {}

function TerrainGrounding.surfaceAt(authoredPosition: Vector3): (Vector3, boolean)
	local origin = Vector3.new(authoredPosition.X, RAY_ORIGIN_Y, authoredPosition.Z)
	local result = Workspace:Raycast(origin, Vector3.new(0, -RAY_DISTANCE, 0), params)

	if result ~= nil then
		return Vector3.new(authoredPosition.X, result.Position.Y, authoredPosition.Z), true
	end

	return authoredPosition, false
end

function TerrainGrounding.surfaceY(authoredPosition: Vector3): (number, boolean)
	local grounded, hit = TerrainGrounding.surfaceAt(authoredPosition)
	return grounded.Y, hit
end

return table.freeze(TerrainGrounding)
