--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AccountSchema = require(ReplicatedStorage.Shared.persistence.AccountSchema)
local PersistenceConfig = require(ReplicatedStorage.Shared.config.PersistenceConfig)
local CombatConfig = require(ReplicatedStorage.Shared.config.CombatConfig)
local CharacterConfig = require(ReplicatedStorage.Shared.config.CharacterConfig)
local ProfileSchema = require(ReplicatedStorage.Shared.persistence.ProfileSchema)
local PersistenceTypes = require(ReplicatedStorage.Shared.types.PersistenceTypes)
local ProfileStoreContract = require(script.Parent.Parent.persistence.ProfileStoreContract)
local RobloxProfileStore = require(script.Parent.Parent.persistence.RobloxProfileStore)
local SessionProfileStore = require(script.Parent.Parent.persistence.SessionProfileStore)

local PlayerDataService = {}
export type AccountState = "Loading" | "AccountReady" | "CharacterReady" | "Saving" | "Released" | "Error"
type Session = {
	state: AccountState,
	token: string,
	account: PersistenceTypes.AccountProfile?,
	activeCharacterId: string?,
	generation: number,
}

local sessions: { [Player]: Session } = {}
local started = false
local serviceGeneration = 0
local store: ProfileStoreContract.Store? = nil
local connections: { RBXScriptConnection } = {}
local accountReadyEvent, characterReadyEvent, profileChangedEvent =
	Instance.new("BindableEvent"), Instance.new("BindableEvent"), Instance.new("BindableEvent")
PlayerDataService.AccountReady = accountReadyEvent.Event
PlayerDataService.CharacterReady = characterReadyEvent.Event
-- Compatibility name intentionally means gameplay-ready, never merely account-loaded.
PlayerDataService.ProfileReady = characterReadyEvent.Event
PlayerDataService.ProfileChanged = profileChangedEvent.Event

local function setState(player: Player, session: Session, state: AccountState): ()
	session.state = state
	player:SetAttribute("ProfileState", state)
	player:SetAttribute("AccountReady", state == "AccountReady" or state == "CharacterReady")
	player:SetAttribute("CharacterReady", state == "CharacterReady")
end

local function defaultStore(): ProfileStoreContract.Store
	if RunService:IsStudio() and not PersistenceConfig.UseDataStoreInStudio then
		return SessionProfileStore.new()
	end
	return RobloxProfileStore.new()
end

local function loadPlayer(player: Player, generation: number): ()
	if player.Parent ~= Players or generation ~= serviceGeneration or store == nil then
		return
	end
	local session: Session = {
		state = "Loading",
		token = HttpService:GenerateGUID(false),
		account = nil,
		activeCharacterId = nil,
		generation = generation,
	}
	sessions[player] = session
	setState(player, session, "Loading")
	local result = (store :: ProfileStoreContract.Store):claim(player.UserId, session.token, os.time())
	if sessions[player] ~= session or player.Parent ~= Players then
		return
	end
	if not result.ok then
		setState(player, session, "Error")
		warn("Account load failed for " .. player.Name .. ": " .. result.reason)
		return
	end
	local valid, reason = AccountSchema.validateCurrent(result.profile)
	if not valid then
		setState(player, session, "Error")
		warn("Account validation failed for " .. player.Name .. ": " .. tostring(reason))
		return
	end
	session.account = result.profile
	setState(player, session, "AccountReady")
	player:SetAttribute("DataVersion", result.profile.DataVersion)
	accountReadyEvent:Fire(player)
end

local function snapshot(session: Session): PersistenceTypes.AccountProfile?
	return if session.account then AccountSchema.clone(session.account) else nil
end
local function save(player: Player, release: boolean): boolean
	local session, activeStore = sessions[player], store
	if session == nil or session.account == nil or activeStore == nil then
		return false
	end
	local account = snapshot(session) :: PersistenceTypes.AccountProfile
	if release then
		setState(player, session, "Saving")
	end
	local result = if release
		then activeStore:release(player.UserId, session.token, account, os.time())
		else activeStore:save(player.UserId, session.token, account, os.time())
	if not result.ok then
		setState(player, session, "Error")
		warn("Account save failed for " .. player.Name .. ": " .. result.reason)
		return false
	end
	if release then
		session.account = nil
		session.activeCharacterId = nil
		setState(player, session, "Released")
	end
	return true
end

local function releasePlayer(player: Player): ()
	if sessions[player] then
		save(player, true)
		sessions[player] = nil
	end
end

function PlayerDataService.start(override: ProfileStoreContract.Store?): ()
	if started then
		return
	end
	started = true
	serviceGeneration += 1
	store = override or defaultStore()
	ProfileStoreContract.assertValid(store)
	Players.CharacterAutoLoads = false
	table.insert(
		connections,
		Players.PlayerAdded:Connect(function(player)
			task.spawn(loadPlayer, player, serviceGeneration)
		end)
	)
	table.insert(connections, Players.PlayerRemoving:Connect(releasePlayer))
	for _, player in Players:GetPlayers() do
		task.spawn(loadPlayer, player, serviceGeneration)
	end
	task.spawn(function()
		local generation = serviceGeneration
		while started and generation == serviceGeneration do
			task.wait(PersistenceConfig.AutosaveSeconds)
			for player, session in sessions do
				if
					player.Parent == Players and (session.state == "AccountReady" or session.state == "CharacterReady")
				then
					save(player, false)
				end
			end
		end
	end)
end

function PlayerDataService.stop(): ()
	if not started then
		return
	end
	started = false
	serviceGeneration += 1
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	local players = {}
	for player in sessions do
		table.insert(players, player)
	end
	for _, player in players do
		releasePlayer(player)
	end
	store = nil
end

function PlayerDataService.getState(player: Player): AccountState?
	local s = sessions[player]
	return if s then s.state else nil
end
function PlayerDataService.isAccountReady(player: Player): boolean
	local s = sessions[player]
	return s ~= nil and s.account ~= nil and (s.state == "AccountReady" or s.state == "CharacterReady")
end
function PlayerDataService.isReady(player: Player): boolean
	local s = sessions[player]
	return s ~= nil and s.state == "CharacterReady" and s.activeCharacterId ~= nil and s.account ~= nil
end
function PlayerDataService.getAccountCopy(player: Player): PersistenceTypes.AccountProfile?
	local s = sessions[player]
	return if s and s.account then AccountSchema.clone(s.account) else nil
end
function PlayerDataService.getActiveCharacterId(player: Player): string?
	local s = sessions[player]
	return if s then s.activeCharacterId else nil
end
function PlayerDataService.getProfileCopy(player: Player): PersistenceTypes.Profile?
	local s = sessions[player]
	if not PlayerDataService.isReady(player) or s == nil or s.account == nil then
		return nil
	end
	return ProfileSchema.clone(s.account.Characters[s.activeCharacterId :: string])
end
function PlayerDataService.mutate(player: Player, callback: (PersistenceTypes.Profile) -> ()): (boolean, string?)
	local s = sessions[player]
	if not PlayerDataService.isReady(player) or s == nil or s.account == nil then
		return false, "CharacterNotReady"
	end
	local id = s.activeCharacterId :: string
	local before = AccountSchema.clone(s.account)
	local ok = pcall(callback, s.account.Characters[id])
	local valid, reason = AccountSchema.validateCurrent(s.account)
	if not ok or not valid then
		s.account = before
		return false, if not ok then "MutationFailed" else reason
	end
	profileChangedEvent:Fire(player)
	return true, nil
end
function PlayerDataService.mutateAccount(
	player: Player,
	callback: (PersistenceTypes.AccountProfile) -> ()
): (boolean, string?)
	local s = sessions[player]
	if s == nil or s.account == nil or not PlayerDataService.isAccountReady(player) then
		return false, "AccountNotReady"
	end
	local before = AccountSchema.clone(s.account)
	local ok = pcall(callback, s.account)
	local valid, reason = AccountSchema.validateCurrent(s.account)
	if not ok or not valid then
		s.account = before
		return false, if not ok then "MutationFailed" else reason
	end
	return true, nil
end
function PlayerDataService.selectCharacter(player: Player, characterId: string): (boolean, string?)
	local s = sessions[player]
	if s == nil or s.account == nil or s.state ~= "AccountReady" then
		return false, "AccountNotReady"
	end
	local character = s.account.Characters[characterId]
	if character == nil then
		return false, "CharacterNotOwned"
	end
	if character.NeedsIdentity then
		return false, "IdentityIncomplete"
	end
	s.activeCharacterId = characterId
	s.account.SelectedCharacterId = characterId
	character.LastPlayedAt = os.time()

	-- Runtime identity must be projected before CharacterReady/LoadCharacter.
	-- Combat, HUD and starter-gear systems read these attributes during the
	-- initial CharacterAdded lifecycle.
	player:SetAttribute("ActiveCharacterId", characterId)
	player:SetAttribute(CombatConfig.ArchetypeAttribute, character.ArchetypeId)
	player:SetAttribute(CharacterConfig.NicknameAttribute, character.Nickname or player.DisplayName)
	player:SetAttribute(CharacterConfig.BodyTypeAttribute, character.BodyType or "male")
	player:SetAttribute(CharacterConfig.AppearancePresetAttribute, character.AppearancePresetId or "default")

	setState(player, s, "CharacterReady")
	characterReadyEvent:Fire(player)
	player:LoadCharacter()
	return true, nil
end
function PlayerDataService.saveNow(player: Player): boolean
	return save(player, false)
end
return PlayerDataService
