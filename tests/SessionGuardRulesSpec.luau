--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rules = require(ReplicatedStorage.Shared.session.SessionGuardRules)

local SESSION_A = "11111111-1111-1111-1111-111111111111"
local SESSION_B = "22222222-2222-2222-2222-222222222222"

return function(TestRunner)
	TestRunner.run("session guard claim rules distinguish same session from another device", function()
		local active = Rules.makeRecord(SESSION_A, "job-a", 10, 45)
		assert(Rules.canClaim(nil, SESSION_A, 20))
		assert(Rules.canClaim(active, SESSION_A, 20))
		local allowed, reason = Rules.canClaim(active, SESSION_B, 20)
		assert(not allowed and reason == "Busy")
		assert(Rules.canClaim(active, SESSION_B, 55))
	end)

	TestRunner.run("session guard routing is scoped by Roblox user id", function()
		local payload = {
			experienceSessionIds = {
				["7"] = SESSION_A,
				["8"] = SESSION_B,
			},
		}
		assert(Rules.readRoutedSessionId(payload, 7) == SESSION_A)
		assert(Rules.readRoutedSessionId(payload, 8) == SESSION_B)
		assert(Rules.readRoutedSessionId(payload, 9) == nil)
		assert(Rules.readRoutedSessionId({ experienceSessionIds = { ["7"] = "short" } }, 7) == nil)
	end)
end
