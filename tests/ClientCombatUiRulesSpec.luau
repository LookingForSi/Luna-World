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

	TestRunner.run("desktop target forgiveness covers diagonals without exceeding its radius", function()
		local offsets = Rules.getPointerProbeOffsets(18)
		assert(#offsets == 9 and offsets[1] == Vector2.zero)
		local hasPositiveDiagonal = false
		local hasNegativeDiagonal = false
		for _, offset in offsets do
			assert(offset.Magnitude <= 18.001)
			if offset.X > 0 and offset.Y > 0 then hasPositiveDiagonal = true end
			if offset.X < 0 and offset.Y < 0 then hasNegativeDiagonal = true end
		end
		assert(hasPositiveDiagonal and hasNegativeDiagonal)
	end)
end
