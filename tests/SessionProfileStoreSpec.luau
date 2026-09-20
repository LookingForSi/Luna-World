--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local SessionProfileStore = require(ServerScriptService.Server.persistence.SessionProfileStore)

return function(TestRunner)
	TestRunner.run("studio session store persists canonical state within one server", function()
		local store = SessionProfileStore.new()
		local first = store:claim(101, "session-a", 0)
		assert(first.ok)
		if not first.ok then return end
		first.profile.Level = 2
		first.profile.XP = 25
		assert(store:save(101, "session-a", first.profile, 1).ok)
		assert(store:release(101, "session-a", first.profile, 2).ok)

		local second = store:claim(101, "session-b", 3)
		assert(second.ok)
		if not second.ok then return end
		assert(second.profile.Level == 2 and second.profile.XP == 25)
	end)

	TestRunner.run("studio session store rejects concurrent ownership", function()
		local store = SessionProfileStore.new()
		assert(store:claim(102, "session-a", 0).ok)
		local blocked = store:claim(102, "session-b", 1)
		assert(not blocked.ok and blocked.reason == "Busy")
	end)
end
