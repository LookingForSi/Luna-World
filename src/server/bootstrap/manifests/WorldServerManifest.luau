--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RuntimeManifest = require(ReplicatedStorage.Shared.core.runtime.RuntimeManifest)
local Components = require(script.Parent.Parent.adapters.ExistingServerComponents)

-- Production Moonfall consumes authored Workspace content. Runtime world
-- generation is intentionally absent; MoonfallWorldRuntime validates and owns
-- traversal recovery for the baked world.
return RuntimeManifest.new("WorldServer", {
	Components.moonfallWorldRuntime(),
	Components.worldSpawnAnchor(),
	Components.economy(),
	Components.placeArrival("World"),
	Components.playerData(),
	Components.party(),
	Components.partyNetwork(),
	Components.dungeonTransfer(),
	Components.progression(),
	Components.combat(),
	Components.regeneration(),
	Components.respawn(),
	Components.mobAbilities(),
	Components.mobAI(),
	Components.mobs(),
	Components.killCredit(),
	Components.loot(),
	Components.worldDrops(),
	Components.inventoryNetwork(),
	Components.economyNetwork(),
	Components.economyWorld(),
	Components.quests(),
	Components.travel(),
	Components.npcWorld(),
})
