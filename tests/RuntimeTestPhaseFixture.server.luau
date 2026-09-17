--!strict

-- Test-project-only stabilization between the manual lifecycle contract and the
-- skill runtime contract. The lifecycle test deliberately reuses one Grey Wolf
-- across several cancellation cases; depending on scheduler timing, a final
-- accepted basic attack can resolve just before the phase boundary and leave the
-- shared fixture damaged. Restore that fixture at the boundary so the following
-- skill-runtime contract starts from deterministic health without changing live
-- game behavior.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MobDefinitions = require(ReplicatedStorage.Shared.definitions.MobDefinitions)
local MobService = require(ServerScriptService.Server.services.MobService)

local lifecycleComplete = ReplicatedStorage
	:WaitForChild("TestRemotes")
	:WaitForChild("ManualAttackLifecycleComplete") :: RemoteEvent

local pendingGreyWolfResetUntil = 0

local function restoreGreyWolf(model: Model): boolean
	local definition = MobService.getDefinition(model)
	if definition == nil or definition.id ~= MobDefinitions.grey_wolf.id then return false end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then return false end
	humanoid.Health = humanoid.MaxHealth
	return true
end

local function restoreExistingGreyWolf(): boolean
	for _, model in MobService.getAll() do
		if restoreGreyWolf(model) then return true end
	end
	return false
end

lifecycleComplete.OnServerEvent:Connect(function()
	if restoreExistingGreyWolf() then
		pendingGreyWolfResetUntil = 0
		return
	end
	-- If the fixture crossed the death boundary immediately before this event,
	-- restore the normal MobService respawn when it appears instead of spawning a
	-- second test-only mob or mutating production respawn rules.
	pendingGreyWolfResetUntil = os.clock() + 8
end)

MobService.MobSpawned:Connect(function(model)
	if os.clock() > pendingGreyWolfResetUntil then return end
	if restoreGreyWolf(model) then pendingGreyWolfResetUntil = 0 end
end)
