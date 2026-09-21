--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RuntimeManifest = require(ReplicatedStorage.Shared.core.runtime.RuntimeManifest)
local Components = require(script.Parent.Parent.adapters.ExistingServerComponents)

-- Gate A skeleton only. DungeonSession/arrival components are added in Gate G.
return RuntimeManifest.new("DungeonServer", {
	Components.playerData(),
	Components.progression(),
	Components.combat(),
	Components.regeneration(),
	Components.respawn(),
	Components.mobAbilities(),
	Components.mobAI(),
	Components.mobs(),
	Components.loot(),
	Components.worldDrops(),
	Components.inventoryNetwork(),
})
