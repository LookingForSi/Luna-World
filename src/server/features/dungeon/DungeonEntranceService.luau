--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.dungeon.DungeonConfig)
local UnlockRules = require(ReplicatedStorage.Shared.dungeon.DungeonUnlockRules)
local WorldLayout = require(ReplicatedStorage.Shared.world.WorldLayout)
local TerrainGrounding = require(script.Parent.Parent.Parent.world.TerrainGrounding)
local KillCreditService = require(script.Parent.Parent.party.KillCreditService)
local PlayerDataService = require(script.Parent.Parent.Parent.services.PlayerDataService)
local DungeonTransferService = require(script.Parent.DungeonTransferService)
local Diagnostics = require(script.Parent.DungeonDiagnostics)
local dungeonEvent = ReplicatedStorage.Remotes:WaitForChild("DungeonEvent") :: RemoteEvent

local Service = {}
local connections: { RBXScriptConnection } = {}
local portalStone: Part? = nil
local sessionUnlocked = false

local function worldRoot(): Instance?
	return workspace:FindFirstChild("LunaWorldPlayableBlockout")
end

local function findOrCreateAnchor(): BasePart
	local root = worldRoot()
	assert(root ~= nil, "Moonfall world root is missing for Ruins of Selene entrance")
	local existing = root:FindFirstChild("RuinsOfSeleneEntranceSpawn", true)
	if existing ~= nil then
		assert(existing:IsA("BasePart"), "RuinsOfSeleneEntranceSpawn must be a BasePart")
		return existing
	end
	local surface, hit = TerrainGrounding.surfaceAt(WorldLayout.RuinsOfSeleneEntranceQuery)
	assert(hit, "RuinsOfSeleneEntranceSpawn could not resolve the Terrain surface")
	local anchor = Instance.new("Part")
	anchor.Name = "RuinsOfSeleneEntranceSpawn"
	anchor.Size = Vector3.new(4, 0.5, 4)
	anchor.Position = surface + Vector3.new(0, 0.19, 0)
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor:SetAttribute("Purpose", "DungeonEntranceAnchor")
	anchor.Parent = root
	return anchor
end

local function createPortal(): ()
	if portalStone ~= nil and portalStone.Parent ~= nil then return end
	local anchor = findOrCreateAnchor()
	local stone = Instance.new("Part")
	stone.Name = Config.EntrancePromptName
	stone.Size = Vector3.new(8, 14, 6)
	stone.CFrame = anchor.CFrame * CFrame.new(0, stone.Size.Y * 0.5 - 1, 0)
	stone.Anchored = true
	stone.Material = Enum.Material.Slate
	stone.Color = Color3.fromRGB(83, 91, 132)
	stone:SetAttribute("UnlockedBy", UnlockRules.QuestId)
	stone.Parent = anchor.Parent
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(135, 164, 255)
	light.Range = 24
	light.Brightness = 1.5
	light.Parent = stone
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Войти"
	prompt.ObjectText = "Лунный камень — Ruins of Selene"
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = stone
	portalStone = stone
	DungeonTransferService.bindEntrancePrompt(prompt)
	Diagnostics.event("ENTRANCE_UNLOCKED", { questId = UnlockRules.QuestId })
end

local function refreshPlayer(player: Player): ()
	local profile = PlayerDataService.getProfileCopy(player)
	local unlocked = profile ~= nil and UnlockRules.isUnlocked(profile.Quests)
	local wasUnlocked = player:GetAttribute("RuinsOfSeleneUnlocked") == true
	player:SetAttribute("RuinsOfSeleneUnlocked", unlocked)
	if unlocked then
		sessionUnlocked = true
		createPortal()
		if not wasUnlocked then
			dungeonEvent:FireClient(player, {
				state = "ENTRANCE_UNLOCKED",
				message = "Страж повержен. Древняя печать разрушена — на Ancient Approach появился лунный камень.",
			})
		end
	end
end

function Service.start(): ()
	findOrCreateAnchor()
	table.insert(connections, PlayerDataService.ProfileReady:Connect(refreshPlayer))
	table.insert(connections, PlayerDataService.ProfileChanged:Connect(refreshPlayer))
	table.insert(connections, KillCreditService.KillResolved:Connect(function(context)
		if context.mobId ~= "mob_moonbound_warden" then return end
		task.defer(function()
			for _, player in context.eligiblePlayers do refreshPlayer(player) end
		end)
	end))
	for _, player in Players:GetPlayers() do if PlayerDataService.isReady(player) then refreshPlayer(player) end end
end

function Service.stop(): ()
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
	DungeonTransferService.bindEntrancePrompt(nil)
	if portalStone ~= nil then portalStone:Destroy(); portalStone = nil end
	sessionUnlocked = false
end

return Service
