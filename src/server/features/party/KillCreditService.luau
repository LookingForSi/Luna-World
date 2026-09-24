--!strict

local MobService = require(script.Parent.Parent.Parent.services.MobService)
local PartyService = require(script.Parent.PartyService)
local RewardLedger = require(script.Parent.RewardLedger)

local KillCreditService = {}
local resolvedEvent = Instance.new("BindableEvent")
KillCreditService.KillResolved = resolvedEvent.Event
local connection: RBXScriptConnection? = nil
local started = false
local rewardLedger = RewardLedger.new(4096)

local function onMobDied(killer: Player?, mobId: string, entityId: string, deathPosition: Vector3): ()
	if not rewardLedger:mark(entityId) then return end
	if killer == nil then return end
	local eligiblePlayers = PartyService.resolveEligibleMembers(killer, deathPosition)
	resolvedEvent:Fire({
		killer = killer,
		mobId = mobId,
		entityId = entityId,
		deathPosition = deathPosition,
		eligiblePlayers = eligiblePlayers,
		lootRecipient = PartyService.selectLootRecipient(killer, eligiblePlayers),
	})
end

function KillCreditService.start(): ()
	if started then return end
	started = true
	connection = MobService.MobDied:Connect(onMobDied)
end

function KillCreditService.stop(): ()
	if not started then return end
	started = false
	if connection then connection:Disconnect(); connection = nil end
	rewardLedger:clear()
end

return KillCreditService
