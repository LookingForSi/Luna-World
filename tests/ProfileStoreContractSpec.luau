--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local ProfileStoreContract = require(ServerScriptService.Server.persistence.ProfileStoreContract)
local InMemoryProfileStore = require(script.Parent.support.InMemoryProfileStore)

return function(TestRunner)
	TestRunner.run("profile store adapter exposes claim save and release only through the contract", function()
		local store = InMemoryProfileStore.new()
		ProfileStoreContract.assertValid(store)

		local first = store:claim(42, "session-a", 0)
		assert(first.ok)
		if not first.ok then
			return
		end
		first.profile.Settings.SoundVolume = 0.1
		assert(store:save(42, "session-a", first.profile, 1).ok)
		assert(store:release(42, "session-a", first.profile, 2).ok)

		local second = store:claim(42, "session-b", 3)
		assert(second.ok)
		if not second.ok then
			return
		end
		assert(second.profile.Settings.SoundVolume == 0.1)
	end)

	TestRunner.run("in memory profile store isolates active ownership", function()
		local store = InMemoryProfileStore.new()
		assert(store:claim(7, "session-a", 0).ok)
		local blocked = store:claim(7, "session-b", 1)
		assert(not blocked.ok and blocked.reason == "Busy")
	end)
end
