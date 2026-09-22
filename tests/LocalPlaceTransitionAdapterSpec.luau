--!strict

return function(TestRunner)
	local adapterModule = game:GetService("StarterPlayer").StarterPlayerScripts.Client.bootstrap.transport.LocalPlaceTransitionAdapter
	local LocalPlaceTransitionAdapter = require(adapterModule)

	TestRunner.run("local transition forwards only the selected character id", function()
		local selected: string? = nil
		local adapter = LocalPlaceTransitionAdapter.new(function(characterId)
			selected = characterId
		end)
		local ok = adapter.enterWorld("hero-1")
		assert(ok)
		assert(selected == "hero-1")
	end)

	TestRunner.run("local transition rejects an empty character id", function()
		local calls = 0
		local adapter = LocalPlaceTransitionAdapter.new(function(_characterId)
			calls += 1
		end)
		local ok, reason = adapter.enterWorld("")
		assert(not ok)
		assert(reason == "InvalidCharacterId")
		assert(calls == 0)
	end)
end
