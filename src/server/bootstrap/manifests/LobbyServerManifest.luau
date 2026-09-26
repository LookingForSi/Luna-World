--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RuntimeManifest = require(ReplicatedStorage.Shared.core.runtime.RuntimeManifest)
local Components = require(script.Parent.Parent.adapters.ExistingServerComponents)

-- Gate A skeleton. Transfer service is introduced in Gate C.
return RuntimeManifest.new("LobbyServer", {
	Components.sessionGuard(),
	Components.playerData(),
	Components.placeTransfer(),
	Components.character(),
})
