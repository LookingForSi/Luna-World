--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rules = require(ReplicatedStorage.Shared.world.DevCombinedWorldRules)

return function(TestRunner: any)
	TestRunner.run("DevCombined generates when root is absent or generator-owned", function()
		assert(Rules.resolve(0, nil) == "Generate")
		assert(Rules.resolve(1, "PlayableWorldBlockout") == "Generate")
	end)
	TestRunner.run("DevCombined reuses the accepted authored root", function()
		assert(Rules.resolve(1, "MoonfallAuthoredWorld") == "ReuseAuthored")
	end)
	TestRunner.run("DevCombined fails closed for collision and unknown ownership", function()
		local mode, reason = Rules.resolve(2, "PlayableWorldBlockout")
		assert(mode == nil and reason == "CompetingRoots")
		mode, reason = Rules.resolve(1, nil)
		assert(mode == nil and reason == "UnknownOwnership")
	end)
end
