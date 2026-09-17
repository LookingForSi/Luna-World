--!strict

local CombatTypes = require(script.Parent.Parent.types.CombatTypes)

-- All numbers in this file are working tuning values, not final balance.
local definitions: { [string]: CombatTypes.MobDefinition } = {
	young_wolf = {
		id = "mob_young_wolf",
		displayName = "Молодой волк",
		maxHealth = 70,
		rewardXP = 15,
		respawnSeconds = 5,
		aggressionMode = "Passive",
		rank = "Ordinary",
		attackKind = "Melee",
		detectionRadius = 25,
		aggroRadius = 20,
		reacquireRadius = 25,
		leashDistance = 60,
		attackRange = 10,
		chaseSpeed = 12,
		decisionIntervalSeconds = 0.25,
	},
	grey_wolf = {
		-- Preserve the Milestone 0 key and id while extending its data contract.
		id = "mob_grey_wolf",
		displayName = "Волк",
		maxHealth = 100,
		rewardXP = 25,
		respawnSeconds = 5,
		aggressionMode = "Aggressive",
		rank = "Ordinary",
		attackKind = "Melee",
		detectionRadius = 35,
		aggroRadius = 30,
		reacquireRadius = 40,
		leashDistance = 75,
		attackRange = 10,
		chaseSpeed = 14,
		decisionIntervalSeconds = 0.25,
	},
	spider = {
		id = "mob_spider",
		displayName = "Паук",
		maxHealth = 85,
		rewardXP = 20,
		respawnSeconds = 5,
		aggressionMode = "Aggressive",
		rank = "Ordinary",
		attackKind = "Ranged",
		detectionRadius = 30,
		aggroRadius = 25,
		reacquireRadius = 35,
		leashDistance = 70,
		attackRange = 35,
		chaseSpeed = 11,
		decisionIntervalSeconds = 0.3,
	},
}

return table.freeze(definitions)
