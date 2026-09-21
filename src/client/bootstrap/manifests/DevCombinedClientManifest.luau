--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RuntimeManifest = require(ReplicatedStorage.Shared.core.runtime.RuntimeManifest)
local Components = require(script.Parent.Parent.adapters.ExistingClientComponents)

return RuntimeManifest.new("DevCombinedClient", {
	Components.stockHealthGui(),
	Components.characterLobby(),
	Components.gameplayAfterCharacterReady(),
})
