--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.dungeon.DungeonConfig)
local Layout = require(ReplicatedStorage.Shared.dungeon.DungeonLayout)
local CombatConfig = require(ReplicatedStorage.Shared.config.CombatConfig)
local MobService = require(script.Parent.Parent.Parent.services.MobService)
local DungeonRun = require(script.Parent.DungeonRunService)
local DungeonWorld = require(script.Parent.DungeonWorldService)
local Diagnostics = require(script.Parent.DungeonDiagnostics)

local Service = {}
local connections: { RBXScriptConnection } = {}
local entityGroup: { [string]: number } = {}
local remaining: { [number]: number } = {}
local activeGeneration: { [number]: number } = {}
local activeMarker: { [number]: string } = {}
local guardian: Model? = nil
local telegraph: Part? = nil
local guardianEnraged = false

local groups = {
	{ mobs = { "selene_warden", "selene_warden", "selene_acolyte" } },
	{ mobs = { "ruin_sentinel" } },
	{ mobs = { "selene_warden", "selene_acolyte", "selene_acolyte" } },
	{ mobs = { "selenes_fallen_guardian" } },
}

local function clearTelegraph(): ()
	if telegraph ~= nil then telegraph:Destroy(); telegraph = nil end
end

local function removeGroup(groupIndex: number): ()
	local marker = activeMarker[groupIndex]
	if marker ~= nil then MobService.removeConfigured(marker); activeMarker[groupIndex] = nil end
	for entityId, index in entityGroup do
		if index == groupIndex then entityGroup[entityId] = nil end
	end
end

local function spawnGroup(groupIndex: number): ()
	removeGroup(groupIndex)
	activeGeneration[groupIndex] = (activeGeneration[groupIndex] or 0) + 1
	remaining[groupIndex] = #groups[groupIndex].mobs
	local marker = string.format("selene_group_%d_generation_%d", groupIndex, activeGeneration[groupIndex])
	activeMarker[groupIndex] = marker

	guardian = nil
	guardianEnraged = false
	clearTelegraph()
	local center = Layout.EncounterPositions[groupIndex]
	for index, key in groups[groupIndex].mobs do
		local localPosition = center + Vector3.new((index - 2) * 14, 0, 0)
		local model = MobService.spawnConfigured(key, DungeonWorld.toWorld(localPosition), marker, index)
		if key == "selenes_fallen_guardian" then
			guardian = model
			if model ~= nil then
				model:SetAttribute("DungeonBossPhase", "BASE")
				model:SetAttribute("DungeonResetGeneration", activeGeneration[groupIndex])
			end
		end
	end
	Diagnostics.event("ENCOUNTER_STARTED", { encounterId = groupIndex })
end

local function resetEncounter(groupIndex: number, _resetGeneration: number): ()
	local snapshot = DungeonRun.getSnapshot()
	if snapshot == nil or snapshot.state == "COMPLETED" then return end
	if groupIndex <= 3 then DungeonWorld.setGateClosed(groupIndex, true) end
	spawnGroup(groupIndex)
end

function Service.start(): ()
	table.insert(connections, MobService.MobSpawned:Connect(function(model)
		local marker = model:GetAttribute("SpawnMarkerId")
		local entityId = model:GetAttribute("EntityId")
		local group = if typeof(marker) == "string" then tonumber(string.match(marker, "selene_group_(%d+)_generation_%d+")) else nil
		if group ~= nil and typeof(entityId) == "string" and activeMarker[group] == marker then
			entityGroup[entityId] = group
		end
	end))

	table.insert(connections, MobService.MobDied:Connect(function(_killer, _mobId, entityId)
		local group = entityGroup[entityId]
		if group == nil or (remaining[group] or 0) <= 0 then return end
		entityGroup[entityId] = nil
		remaining[group] -= 1
		if remaining[group] ~= 0 or not DungeonRun.recordEncounter(group) then return end

		removeGroup(group)
		if group <= 3 then
			DungeonWorld.setGateClosed(group, false)
			spawnGroup(group + 1)
		elseif DungeonRun.completeBoss() then
			clearTelegraph()
			for _, player in Players:GetPlayers() do DungeonRun.claimReward(player) end
			local dungeonRoot = DungeonWorld.getRoot()
			local exit = if dungeonRoot ~= nil then dungeonRoot:FindFirstChild(Config.ExitPromptName) else nil
			local prompt = if exit ~= nil then exit:FindFirstChildOfClass("ProximityPrompt") else nil
			if prompt ~= nil then prompt.Enabled = true end
		end
	end))

	table.insert(connections, DungeonRun.Wipe:Connect(resetEncounter))
	table.insert(connections, RunService.Heartbeat:Connect(function()
		if guardian == nil or guardian.Parent == nil then clearTelegraph(); return end
		local humanoid = guardian:FindFirstChildOfClass("Humanoid")
		local bossRoot = guardian:FindFirstChild("HumanoidRootPart")
		if humanoid == nil or bossRoot == nil or not bossRoot:IsA("BasePart") then return end
		if not guardianEnraged and humanoid.MaxHealth > 0 and humanoid.Health / humanoid.MaxHealth <= Config.EnrageHealthFraction then
			guardianEnraged = true
			guardian:SetAttribute("DungeonBossPhase", "ENRAGED")
			guardian:SetAttribute(CombatConfig.MobOutgoingDamageMultiplierAttribute, 1.45)
			Diagnostics.event("BOSS_ENRAGED", {})
			local event = ReplicatedStorage.Remotes.DungeonEvent :: RemoteEvent
			event:FireAllClients({ state="BOSS_ENRAGED", message="Падший Страж Селены впал в ярость!" })
		end
		local windup = guardian:GetAttribute(CombatConfig.MobActionStateAttribute) == "Windup"
		if windup and telegraph == nil then
			telegraph = Instance.new("Part")
			telegraph.Name = "GuardianDangerZone"
			telegraph.Shape = Enum.PartType.Cylinder
			telegraph.Size = Vector3.new(0.25, Config.AoERadius * 2, Config.AoERadius * 2)
			telegraph.CFrame = CFrame.new(bossRoot.Position - Vector3.new(0, bossRoot.Size.Y / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
			telegraph.Anchored = true
			telegraph.CanCollide = false
			telegraph.Material = Enum.Material.Neon
			telegraph.Color = Color3.fromRGB(190, 55, 75)
			telegraph.Transparency = 0.45
			telegraph.Parent = DungeonWorld.getRoot()
		elseif not windup then
			clearTelegraph()
		end
	end))

	spawnGroup(1)
end

function Service.stop(): ()
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
	for index = 1, 4 do removeGroup(index) end
	table.clear(entityGroup)
	table.clear(remaining)
	table.clear(activeGeneration)
	guardian = nil
	guardianEnraged = false
	clearTelegraph()
end

return Service
