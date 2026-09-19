--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ProgressionConfig = require(ReplicatedStorage.Shared.config.ProgressionConfig)
local ProgressionRules = require(ReplicatedStorage.Shared.progression.ProgressionRules)
local CombatPresentationRules = require(ReplicatedStorage.Shared.combat.CombatPresentationRules)
local CombatPresentationService = require(script.Parent.CombatPresentationService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local ProgressionService = {}

local started = false
local profileReadyConnection: RBXScriptConnection? = nil

local function replicateProgression(player: Player, level: number, xp: number): ()
	player:SetAttribute(ProgressionConfig.LevelAttribute, level)
	player:SetAttribute(ProgressionConfig.ExperienceAttribute, xp)
	-- Compatibility for old M1 characterization. Removed at the M2 stabilization gate.
	player:SetAttribute("SessionXP", xp)
end

local function initializeFromProfile(player: Player): ()
	local profile = PlayerDataService.getProfileCopy(player)
	if profile == nil then return end
	replicateProgression(player, profile.Level, profile.XP)
end

function ProgressionService.start(): ()
	if started then return end
	started = true

	profileReadyConnection = PlayerDataService.ProfileReady:Connect(initializeFromProfile)
	for _, player in Players:GetPlayers() do
		if PlayerDataService.isReady(player) then initializeFromProfile(player) end
	end
end

function ProgressionService.stop(): ()
	if not started then return end
	started = false
	if profileReadyConnection ~= nil then
		profileReadyConnection:Disconnect()
		profileReadyConnection = nil
	end
end

function ProgressionService.awardXP(player: Player, amount: number): boolean
	if player.Parent ~= Players or not PlayerDataService.isReady(player) then return false end

	local appliedLevel: number? = nil
	local appliedXP: number? = nil
	local ok = PlayerDataService.mutate(player, function(profile)
		local result = ProgressionRules.applyXP(profile.Level, profile.XP, amount)
		profile.Level = result.level
		profile.XP = result.xp
		appliedLevel = result.level
		appliedXP = result.xp
	end)
	if not ok or appliedLevel == nil or appliedXP == nil then return false end

	replicateProgression(player, appliedLevel, appliedXP)
	return true
end

function ProgressionService._setLevelForStudio(player: Player, level: number): boolean
	assert(RunService:IsStudio(), "Studio level switch is unavailable outside Studio")
	if player.Parent ~= Players or not PlayerDataService.isReady(player) then return false end
	if level ~= level or level % 1 ~= 0 or level < 1 or level > ProgressionConfig.LevelCap then return false end

	local ok = PlayerDataService.mutate(player, function(profile)
		profile.Level = level
		profile.XP = 0
	end)
	if not ok then return false end
	replicateProgression(player, level, 0)
	return true
end

function ProgressionService.awardMobXP(player: Player, baseXP: number, mobLevel: number): number
	local profile = PlayerDataService.getProfileCopy(player)
	if profile == nil then return 0 end

	local reward = if profile.Level >= ProgressionConfig.LevelCap
		then 0
		else ProgressionRules.calculateMobXP(baseXP, profile.Level, mobLevel)
	if reward > 0 and not ProgressionService.awardXP(player, reward) then
		return 0
	end

	-- Publish even a zero reward so an over-levelled player can see that the kill
	-- produced no XP rather than assuming the progression system failed.
	CombatPresentationService.publishToPlayer(player, CombatPresentationRules.create(
		"Reward",
		HttpService:GenerateGUID(false),
		"player:" .. tostring(player.UserId),
		workspace:GetServerTimeNow(),
		{
			presentationKey = "xp",
			outcome = "Granted",
			amount = reward,
		}
	))
	return reward
end

return ProgressionService
