--!strict

local Players = game:GetService("Players")

local ProgressionService = {}

local started = false
local playerAddedConnection: RBXScriptConnection? = nil

local function initializePlayer(player: Player): ()
	player:SetAttribute("SessionXP", 0)
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
	assert(amount >= 0, "XP reward must not be negative")
	if player.Parent == nil then
		return
	end

	local current = player:GetAttribute("SessionXP")
	local currentXP = if typeof(current) == "number" then current else 0
	player:SetAttribute("SessionXP", currentXP + amount)
end

return ProgressionService
