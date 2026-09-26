--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local Store = require(ServerScriptService.Server.session.MemoryStoreSessionGuardStore)

local SESSION_A = "11111111-1111-1111-1111-111111111111"
local SESSION_B = "22222222-2222-2222-2222-222222222222"

local function fakeMap()
	local values = {}
	return {
		UpdateAsync = function(_self, key, transform, _ttl)
			local nextValue = transform(values[key])
			values[key] = nextValue
			return nextValue
		end,
	}
end

return function(TestRunner)
	TestRunner.run("session guard store rejects a second logical session", function()
		local store = Store.new(fakeMap())
		assert(store:claim(7, SESSION_A, "job-a", 100, 10, 45))
		local ok, reason = store:claim(7, SESSION_B, "job-b", 100, 20, 45)
		assert(not ok and reason == "Busy")
	end)

	TestRunner.run("same logical session can move jobs without stale source release winning", function()
		local store = Store.new(fakeMap())
		assert(store:claim(7, SESSION_A, "job-a", 100, 10, 45))
		assert(store:claim(7, SESSION_A, "job-b", 200, 20, 45))
		local released, reason = store:release(7, SESSION_A, "job-a")
		assert(not released and reason == "Moved")
		assert(store:renew(7, SESSION_A, "job-b", 200, 25, 45))
		assert(store:release(7, SESSION_A, "job-b"))
		assert(store:claim(7, SESSION_B, "job-c", 300, 30, 45))
	end)
end
