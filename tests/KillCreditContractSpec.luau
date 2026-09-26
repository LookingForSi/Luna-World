--!strict

local Rules = require(game.ReplicatedStorage.Shared.party.KillCreditRules)

return function(TestRunner)
	TestRunner.run("kill eligibility excludes far dead and not-ready party members", function()
		local eligible = Rules.resolveEligible({
			{ value="killer", ready=true, alive=true, position=Vector3.zero },
			{ value="near", ready=true, alive=true, position=Vector3.new(120, 0, 0) },
			{ value="far", ready=true, alive=true, position=Vector3.new(121, 0, 0) },
			{ value="dead", ready=true, alive=false, position=Vector3.zero },
			{ value="loading", ready=false, alive=true, position=Vector3.zero },
		}, Vector3.zero, 120)
		assert(table.concat(eligible, ",") == "killer,near")
	end)
end
