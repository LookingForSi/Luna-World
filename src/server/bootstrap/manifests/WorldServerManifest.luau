--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RuntimeManifest = require(ReplicatedStorage.Shared.core.runtime.RuntimeManifest)
local Components = require(script.Parent.Parent.adapters.ExistingServerComponents)

-- Gate A skeleton. Production arrival/activation replaces CharacterService in
-- later gates. Runtime world generation is intentionally absent here.
return RuntimeManifest.new("WorldServer", {
	Components.worldSpawnAnchor(),
	Components.economy(),
	Components.placeArrival("World"),
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
	Components.economyNetwork(),
	Components.economyWorld(),
	Components.quests(),
	Components.travel(),
	Components.npcWorld(),
})
