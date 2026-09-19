--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local ProgressionConfig = require(ReplicatedStorage.Shared.config.ProgressionConfig)
local ProgressionRules = require(ReplicatedStorage.Shared.progression.ProgressionRules)
local CombatPresentationRules = require(ReplicatedStorage.Shared.combat.CombatPresentationRules)
local CombatPresentationService = require(script.Parent.CombatPresentationService)

local ProgressionService = {}

local started = false
local playerAddedConnection: RBXScriptConnection? = nil

local function initializePlayer(player: Player): ()
	if typeof(player:GetAttribute(ProgressionConfig.LevelAttribute)) ~= "number" then
		player:SetAttribute(ProgressionConfig.LevelAttribute, 1)
	end
	if typeof(player:GetAttribute(ProgressionConfig.ExperienceAttribute)) ~= "number" then
		player:SetAttribute(ProgressionConfig.ExperienceAttribute, 0)
	end
	-- Compatibility for the Milestone 1 HUD until the real level/XP row lands.
	player:SetAttribute("SessionXP", player:GetAttribute(ProgressionConfig.ExperienceAttribute) or 0)
end

function ProgressionService.start(): ()
	if started then
		return
	end
	started = true

	playerAddedConnection = Players.PlayerAdded:Connect(initializePlayer)
	for _, player in Players:GetPlayers() do
		initializePlayer(player)
	end
end

function ProgressionService.stop(): ()
	if not started then return end
	started = false
	if playerAddedConnection ~= nil then
		playerAddedConnection:Disconnect()
		playerAddedConnection = nil
	end
end

function ProgressionService.awardXP(player: Player, amount: number): ()
	if player.Parent == nil then
		return
	end

	local rawLevel = player:GetAttribute(ProgressionConfig.LevelAttribute)
	local rawXP = player:GetAttribute(ProgressionConfig.ExperienceAttribute)
	local level = if typeof(rawLevel) == "number" then rawLevel else 1
	local xp = if typeof(rawXP) == "number" then rawXP else 0
	if not ProgressionRules.isValidState(level, xp) then
		warn(string.format("Refusing XP award for invalid progression state on %s", player.Name))
		return
	end

	local result = ProgressionRules.applyXP(level, xp, amount)
	player:SetAttribute(ProgressionConfig.LevelAttribute, result.level)
	player:SetAttribute(ProgressionConfig.ExperienceAttribute, result.xp)
	player:SetAttribute("SessionXP", result.xp)
end

function ProgressionService.awardMobXP(player: Player, baseXP: number, mobLevel: number): number
	local rawLevel = player:GetAttribute(ProgressionConfig.LevelAttribute)
	local level = if typeof(rawLevel) == "number" then rawLevel else 1
	local reward = ProgressionRules.calculateMobXP(baseXP, level, mobLevel)
	if reward > 0 then
		ProgressionService.awardXP(player, reward)
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
	end
	return reward
end

return ProgressionService
