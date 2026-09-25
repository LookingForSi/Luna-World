--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Layout = require(ReplicatedStorage.Shared.dungeon.DungeonLayout)

return function(TestRunner: any)
	TestRunner.run("Selene rooms form one continuous floor", function()
		assert(Layout.Rooms[1].startZ == Layout.RouteMinZ + 5)
		for index = 2, #Layout.Rooms do
			assert(Layout.Rooms[index - 1].endZ == Layout.Rooms[index].startZ)
		end
		assert(Layout.Rooms[#Layout.Rooms].endZ <= Layout.RouteMaxZ)
	end)

	TestRunner.run("each required encounter precedes the gate it unlocks", function()
		for index = 1, 3 do
			assert(Layout.EncounterPositions[index].Z < Layout.GateZ[index])
			if index > 1 then assert(Layout.EncounterPositions[index].Z > Layout.GateZ[index - 1]) end
		end
		assert(Layout.EncounterPositions[4].Z > Layout.GateZ[3])
		assert(Layout.EncounterPositions[4].Z < Layout.ExitPosition.Z)
	end)

	TestRunner.run("DevCombined origin is isolated from Moonfall", function()
		assert(Layout.DevCombinedOffset.Magnitude > 8000)
		assert(Layout.OutOfBoundsY < Layout.FloorY)
	end)
end
