--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RuntimeManifest = require(ReplicatedStorage.Shared.core.runtime.RuntimeManifest)
local Components = require(script.Parent.Parent.adapters.ExistingServerComponents)

return RuntimeManifest.new("DungeonServer", {
	Components.dungeonWorld(),
	Components.playerData(),
	Components.progression(),
	Components.party(),
	Components.partyNetwork(),
	Components.dungeonRun(),
	Components.dungeonAdmission(),
	Components.combat(),
	Components.regeneration(),
	Components.respawn(),
	Components.mobAbilities(),
	Components.mobAI(),
	Components.mobs(),
	Components.dungeonEncounters(),
	Components.killCredit(),
	Components.loot(),
	Components.worldDrops(),
	Components.inventoryNetwork(),
})
