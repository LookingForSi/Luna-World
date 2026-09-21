--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RuntimeManifest = require(ReplicatedStorage.Shared.core.runtime.RuntimeManifest)
local Components = require(script.Parent.Parent.adapters.ExistingServerComponents)

return RuntimeManifest.new("DevCombinedServer", {
	Components.worldBootstrap(),
	Components.worldSpawnAnchor(),
	Components.economy(),
	Components.playerData(),
	Components.character(),
	Components.progression(),
	Components.combat(),
	Components.regeneration(),
	Components.respawn(),
	Components.studioDebug(),
	Components.mobAbilities(),
	Components.mobAI(),
	Components.mobs(),
	Components.loot(),
	Components.worldDrops(),
	Components.inventoryNetwork(),
	Components.economyNetwork(),
	Components.economyWorld(),
	Components.quests(),
	Components.travel(),
	Components.npcWorld(),
})
