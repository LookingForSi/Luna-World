--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rules = require(ReplicatedStorage.Shared.combat.ClientCombatUiRules)

return function(TestRunner)
	TestRunner.run("client skill slots are archetype-specific copies", function()
		local knight = Rules.getSkills("knight")
		assert(table.concat(knight, ",") == "power_strike,shield_bash,defensive_stance")
		knight[1] = "forged"
		assert(Rules.getSkills("knight")[1] == "power_strike")
		assert(#Rules.getSkills("unknown") == 0)
	end)

	TestRunner.run("friendly player target ids are canonical and strict", function()
		assert(Rules.canonicalPlayerTargetId(42) == "player:42")
		assert(Rules.canonicalPlayerTargetId(-1) == "player:-1")
		assert(Rules.canonicalPlayerTargetId(0) == nil)
		assert(Rules.canonicalPlayerTargetId(1.5) == nil)
		assert(Rules.canonicalPlayerTargetId(0 / 0) == nil)
		assert(Rules.canonicalPlayerTargetId(math.huge) == nil)
		assert(Rules.canonicalPlayerTargetId("42") == nil)
	end)

	TestRunner.run("GUI navigation suppresses only gamepad combat callbacks", function()
		assert(Rules.shouldIgnoreForGuiNavigation("Gamepad1", true))
		assert(not Rules.shouldIgnoreForGuiNavigation("Gamepad1", false))
		assert(not Rules.shouldIgnoreForGuiNavigation("Keyboard", true))
		assert(not Rules.shouldIgnoreForGuiNavigation("MouseButton1", true))
	end)

	TestRunner.run("client renders only known server rejection codes", function()
		assert(Rules.getRejectionText("OutOfRange") == "Цель слишком далеко")
		assert(Rules.getRejectionText("forged") == nil)
		assert(Rules.getRejectionText({}) == nil)
	end)

	TestRunner.run("touch forgiveness probes stay bounded", function()
		local offsets = Rules.getTouchProbeOffsets(24)
		assert(#offsets == 5 and offsets[1] == Vector2.zero)
		for _, offset in offsets do assert(offset.Magnitude <= 24) end
	end)

	TestRunner.run("screen target forgiveness measures distance to an expanded silhouette rectangle", function()
		local minimum = Vector2.new(100, 100)
		local maximum = Vector2.new(200, 200)
		assert(Rules.screenRectDistance(Vector2.new(150, 150), minimum, maximum, 0) == 0)
		assert(Rules.screenRectDistance(Vector2.new(215, 150), minimum, maximum, 20) == 0)
		assert(math.abs(Rules.screenRectDistance(Vector2.new(230, 150), minimum, maximum, 20) - 10) < 0.001)
	end)
end
