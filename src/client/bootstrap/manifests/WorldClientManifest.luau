--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RuntimeManifest = require(ReplicatedStorage.Shared.core.runtime.RuntimeManifest)
local Components = require(script.Parent.Parent.adapters.ExistingClientComponents)

return RuntimeManifest.new("WorldClient", {
	Components.stockHealthGui(),
	Components.gameplay(),
})
