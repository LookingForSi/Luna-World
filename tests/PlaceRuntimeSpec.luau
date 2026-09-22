--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlaceRole = require(ReplicatedStorage.Shared.core.runtime.PlaceRole)
local PlaceRuntime = require(ReplicatedStorage.Shared.core.runtime.PlaceRuntime)

return function(TestRunner)
	TestRunner.run("Studio defaults to DevCombined", function()
		assert(PlaceRuntime.resolve(0, 0, true, nil) == PlaceRole.DevCombined)
	end)

	TestRunner.run("Studio override resolves every supported role", function()
		for _, role in {
			PlaceRole.Lobby,
			PlaceRole.World,
			PlaceRole.Dungeon,
			PlaceRole.DevCombined,
		} do
			assert(PlaceRuntime.resolve(123, 456, true, role) == role)
		end
	end)

	TestRunner.run("production role resolution fails closed until deployment IDs exist", function()
		local ok = pcall(function()
			PlaceRuntime.resolve(123, 456, false, nil)
		end)
		assert(not ok)
	end)

	TestRunner.run("production cannot use a Studio override", function()
		local ok = pcall(function()
			PlaceRuntime.resolve(123, 456, false, PlaceRole.World)
		end)
		assert(not ok)
	end)
end
