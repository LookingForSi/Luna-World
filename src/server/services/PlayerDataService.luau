--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PersistenceConfig = require(ReplicatedStorage.Shared.config.PersistenceConfig)
local ProfileSchema = require(ReplicatedStorage.Shared.persistence.ProfileSchema)
local PersistenceTypes = require(ReplicatedStorage.Shared.types.PersistenceTypes)
local ProfileStoreContract = require(script.Parent.Parent.persistence.ProfileStoreContract)
local RobloxProfileStore = require(script.Parent.Parent.persistence.RobloxProfileStore)
local SessionProfileStore = require(script.Parent.Parent.persistence.SessionProfileStore)

local PlayerDataService = {}

export type ProfileState = "Loading" | "Ready" | "Saving" | "Released" | "Error"

type Session = {
	state: ProfileState,
	token: string,
	profile: PersistenceTypes.Profile?,
	generation: number,
}

local sessions: { [Player]: Session } = {}
local started = false
local serviceGeneration = 0
local store: ProfileStoreContract.Store? = nil
local playerAddedConnection: RBXScriptConnection? = nil
local playerRemovingConnection: RBXScriptConnection? = nil
local profileReadyEvent = Instance.new("BindableEvent")
local profileChangedEvent = Instance.new("BindableEvent")

PlayerDataService.ProfileReady = profileReadyEvent.Event
PlayerDataService.ProfileChanged = profileChangedEvent.Event

local function now(): number
	return os.time()
end

local function createDefaultStore(): ProfileStoreContract.Store
	if RunService:IsStudio() and not PersistenceConfig.UseDataStoreInStudio then
		return SessionProfileStore.new()
	end
	return RobloxProfileStore.new()
end

local function setState(player: Player, session: Session, state: ProfileState): ()
	session.state = state
	player:SetAttribute("ProfileState", state)
end

local function loadPlayer(player: Player, generation: number): ()
	if player.Parent ~= Players or generation ~= serviceGeneration then return end
	local activeStore = store
	if activeStore == nil then return end

	local token = HttpService:GenerateGUID(false)
	local session: Session = {
		state = "Loading",
		token = token,
		profile = nil,
		generation = generation,
	}
	sessions[player] = session
	setState(player, session, "Loading")

	local result = activeStore:claim(player.UserId, token, now())
	if sessions[player] ~= session or generation ~= serviceGeneration or player.Parent ~= Players then
		if result.ok then
			activeStore:release(player.UserId, token, result.profile, now())
		end
		return
	end

	if not result.ok then
		setState(player, session, "Error")
		warn(string.format("Player profile load failed for %s: %s", player.Name, result.reason))
		if not RunService:IsStudio() then
			player:Kick("Не удалось загрузить данные персонажа. Попробуйте войти снова.")
		end
		return
	end

	local valid, reason = ProfileSchema.validateCurrent(result.profile)
	if not valid then
		setState(player, session, "Error")
		warn(string.format("Player profile validation failed for %s: %s", player.Name, reason or "unknown"))
		if not RunService:IsStudio() then
			player:Kick("Данные персонажа не прошли проверку. Вход остановлен для защиты сохранения.")
		end
		return
	end

	session.profile = result.profile
	setState(player, session, "Ready")
	player:SetAttribute("DataVersion", result.profile.DataVersion)
	profileReadyEvent:Fire(player)
end

local function saveSession(player: Player, release: boolean): boolean
	local session = sessions[player]
	local activeStore = store
	if session == nil or activeStore == nil or session.profile == nil then return false end
	if session.state ~= "Ready" and session.state ~= "Saving" then return false end

	setState(player, session, "Saving")
	local result = if release
		then activeStore:release(player.UserId, session.token, session.profile, now())
		else activeStore:save(player.UserId, session.token, session.profile, now())

	if not result.ok then
		setState(player, session, "Error")
		warn(string.format("Player profile %s failed for %s: %s", if release then "release" else "save", player.Name, result.reason))
		return false
	end

	if release then
		setState(player, session, "Released")
		session.profile = nil
	else
		setState(player, session, "Ready")
	end
	return true
end

local function releasePlayer(player: Player): ()
	local session = sessions[player]
	if session == nil then return end
	if session.profile ~= nil and (session.state == "Ready" or session.state == "Saving") then
		saveSession(player, true)
	end
	sessions[player] = nil
end

local function autosaveLoop(generation: number): ()
	task.spawn(function()
		while started and generation == serviceGeneration do
			task.wait(PersistenceConfig.AutosaveSeconds)
			if not started or generation ~= serviceGeneration then return end
			for player, session in sessions do
				if player.Parent == Players and session.state == "Ready" and session.profile ~= nil then
					saveSession(player, false)
				end
			end
		end
	end)
end

function PlayerDataService.start(storeOverride: ProfileStoreContract.Store?): ()
	if started then return end
	started = true
	serviceGeneration += 1
	local generation = serviceGeneration
	store = storeOverride or createDefaultStore()
	ProfileStoreContract.assertValid(store)

	playerAddedConnection = Players.PlayerAdded:Connect(function(player)
		task.spawn(loadPlayer, player, generation)
	end)
	playerRemovingConnection = Players.PlayerRemoving:Connect(releasePlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(loadPlayer, player, generation)
	end
	autosaveLoop(generation)
end

function PlayerDataService.stop(): ()
	if not started then return end
	started = false
	serviceGeneration += 1
	if playerAddedConnection ~= nil then playerAddedConnection:Disconnect(); playerAddedConnection = nil end
	if playerRemovingConnection ~= nil then playerRemovingConnection:Disconnect(); playerRemovingConnection = nil end

	local players = {}
	for player in sessions do table.insert(players, player) end
	for _, player in players do releasePlayer(player) end
	table.clear(sessions)
	store = nil
end

function PlayerDataService.getState(player: Player): ProfileState?
	local session = sessions[player]
	return if session ~= nil then session.state else nil
end

function PlayerDataService.isReady(player: Player): boolean
	local session = sessions[player]
	return session ~= nil and session.state == "Ready" and session.profile ~= nil
end

function PlayerDataService.getProfileCopy(player: Player): PersistenceTypes.Profile?
	local session = sessions[player]
	if session == nil or session.state ~= "Ready" or session.profile == nil then return nil end
	return ProfileSchema.clone(session.profile)
end

function PlayerDataService.mutate(
	player: Player,
	callback: (PersistenceTypes.Profile) -> ()
): (boolean, string?)
	local session = sessions[player]
	if session == nil or session.state ~= "Ready" or session.profile == nil then
		return false, "ProfileNotReady"
	end

	local before = ProfileSchema.clone(session.profile)
	local ok, err = pcall(callback, session.profile)
	if not ok then
		session.profile = before
		return false, "MutationFailed"
	end
	local valid, reason = ProfileSchema.validateCurrent(session.profile)
	if not valid then
		session.profile = before
		return false, reason or "InvalidProfile"
	end

	profileChangedEvent:Fire(player)
	return true, nil
end

function PlayerDataService.saveNow(player: Player): boolean
	return saveSession(player, false)
end

return PlayerDataService
