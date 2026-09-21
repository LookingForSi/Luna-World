--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local RobloxProfileStore = require(ServerScriptService.Server.persistence.RobloxProfileStore)
local FakeDataStore = require(script.Parent.support.FakeDataStore)

return function(TestRunner)
	TestRunner.run("roblox profile store isolates Studio and production namespaces", function()
		assert(RobloxProfileStore.resolveStoreName(true) ~= RobloxProfileStore.resolveStoreName(false))
	end)

	TestRunner.run("claim save release round trip keeps canonical profile", function()
		local fake = FakeDataStore.new()
		local store = RobloxProfileStore.new(fake, function() end)

		local first = store:claim(42, "session-a", 100)
		assert(first.ok)
		if not first.ok then
			return
		end
		first.profile.Settings.SoundVolume = 0.15
		assert(store:save(42, "session-a", first.profile, 110).ok)

		local blocked = store:claim(42, "session-b", 120)
		assert(not blocked.ok and blocked.reason == "Busy")
		assert(store:release(42, "session-a", first.profile, 130).ok)

		local second = store:claim(42, "session-b", 140)
		assert(second.ok)
		if not second.ok then
			return
		end
		assert(second.profile.Settings.SoundVolume == 0.15)
	end)

	TestRunner.run("expired lease can be claimed but stale owner cannot overwrite it", function()
		local fake = FakeDataStore.new()
		local store = RobloxProfileStore.new(fake, function() end)
		local first = store:claim(7, "session-a", 0)
		assert(first.ok)
		local second = store:claim(7, "session-b", 300)
		assert(second.ok)
		if not first.ok then
			return
		end
		first.profile.Settings.SoundVolume = 0.99
		local staleSave = store:save(7, "session-a", first.profile, 301)
		assert(not staleSave.ok and staleSave.reason == "Conflict")
	end)

	TestRunner.run("invalid future profile is never replaced by an empty default", function()
		local fake = FakeDataStore.new()
		fake:seed("player:9", {
			Profile = { DataVersion = 999 },
			Lease = nil,
		})
		local store = RobloxProfileStore.new(fake, function() end)
		local result = store:claim(9, "session-a", 0)
		assert(not result.ok and result.reason == "InvalidProfile")
		local stored = fake:read("player:9")
		assert(stored.Profile.DataVersion == 999)
	end)

	TestRunner.run("bounded retry recovers from transient store failures", function()
		local fake = FakeDataStore.new()
		fake:failNext(2)
		local waits = 0
		local store = RobloxProfileStore.new(fake, function()
			waits += 1
		end)
		local result = store:claim(11, "session-a", 0)
		assert(result.ok)
		assert(fake.updateCalls == 3)
		assert(waits == 2)
	end)
end
