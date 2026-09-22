--!strict
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")
local ArchetypeDefinitions = require(ReplicatedStorage.Shared.definitions.ArchetypeDefinitions)
local CharacterConfig = require(ReplicatedStorage.Shared.config.CharacterConfig)
local PersistenceConfig = require(ReplicatedStorage.Shared.config.PersistenceConfig)
local CharacterRules = require(ReplicatedStorage.Shared.characters.CharacterRules)
local NicknameRules = require(ReplicatedStorage.Shared.characters.NicknameRules)
local ProfileSchema = require(ReplicatedStorage.Shared.persistence.ProfileSchema)
local NicknameStore = require(script.Parent.Parent.persistence.NicknameStore)
local PlayerDataService = require(script.Parent.PlayerDataService)
local CharacterService = {}
local connections = {}
local started = false
local nicknameStore: any
local rate = {}
local transferHandler: ((Player, string) -> (boolean, string?))? = nil

function CharacterService.setTransferHandler(handler: ((Player, string) -> (boolean, string?))?): ()
	transferHandler = handler
end

local function looseStudioNicknames(): boolean
	return RunService:IsStudio() and not PersistenceConfig.UseDataStoreInStudio
end

local function studioTrim(raw: unknown): (string?, string?)
	if typeof(raw) ~= "string" then return nil, "InvalidType" end
	local trimmed = string.match(raw, "^%s*(.-)%s*$") or ""
	if trimmed == "" then return nil, "InvalidNickname" end
	-- Studio stub intentionally accepts spaces, Cyrillic and symbols so owner
	-- acceptance is never blocked by TextService/DataStore/naming policy.
	if #trimmed > 64 then return nil, "InvalidLength" end
	return trimmed, nil
end

local function normalizeNickname(raw: unknown): (string?, string?)
	if looseStudioNicknames() then
		local display, err = studioTrim(raw)
		if display == nil then return nil, err end
		return string.lower(display), nil
	end
	return NicknameRules.normalize(raw)
end

local function displayNickname(raw: unknown): (string?, string?)
	if looseStudioNicknames() then return studioTrim(raw) end
	if typeof(raw) ~= "string" then return nil, "InvalidType" end
	return NicknameRules.display(raw), nil
end

local function allowed(player: Player): boolean
	local now = os.clock()
	local state = rate[player]
	if state == nil or now - state.since >= CharacterConfig.RequestWindowSeconds then
		rate[player] = { since = now, count = 1 }
		return true
	end
	state.count += 1
	return state.count <= CharacterConfig.RequestsPerWindow
end
local function roster(player: Player): any
	local account = PlayerDataService.getAccountCopy(player)
	if account == nil then
		return nil
	end
	local characters = {}
	for _, id in account.CharacterOrder do
		local c = account.Characters[id]
		table.insert(characters, {
			characterId = id,
			nickname = c.Nickname,
			archetypeId = c.ArchetypeId,
			bodyType = c.BodyType,
			level = c.Level,
			xp = c.XP,
			luna = c.Luna,
			createdAt = c.CreatedAt,
			lastPlayedAt = c.LastPlayedAt,
			lastZoneId = c.LastZoneId,
			needsIdentity = c.NeedsIdentity,
			equipment = { Weapon = c.Equipment.Weapon, Head = c.Equipment.Head, Chest = c.Equipment.Chest },
		})
	end
	return {
		slotLimit = math.min(account.CharacterSlotLimit, CharacterConfig.CharacterSlotLimit),
		characters = characters,
		selectedCharacterId = account.SelectedCharacterId,
		settings = account.Settings,
		buildLabel = CharacterConfig.BuildLabel,
	}
end
local function filtered(player: Player, name: string): boolean
	if looseStudioNicknames() then
		return true
	end
	local ok, result = pcall(function()
		return TextService:FilterStringAsync(name, player.UserId, Enum.TextFilterContext.PrivateChat)
	end)
	if not ok then
		return false
	end
	local okText, text = pcall(function()
		return result:GetNonChatStringForBroadcastAsync()
	end)
	return okText and text == name
end
local function response(
	remote: RemoteEvent,
	player: Player,
	requestId: any,
	action: string,
	ok: boolean,
	reason: string?,
	data: any?
)
	remote:FireClient(player, { requestId = requestId, action = action, ok = ok, reason = reason, data = data })
end
function CharacterService.start(storeOverride: any?): ()
	if started then
		return
	end
	started = true
	nicknameStore = storeOverride or NicknameStore.new()
	local remotes = ReplicatedStorage.Remotes
	local request = remotes.CharacterRequest
	local result = remotes.CharacterResult
	table.insert(
		connections,
		request.OnServerEvent:Connect(function(player, ...)
			if select("#", ...) ~= 1 or typeof((...)) ~= "table" or not allowed(player) then
				return
			end
			local p: any = (...)
			local action = p.action
			local id = p.requestId
			if action == "Roster" then
				if not PlayerDataService.isAccountReady(player) then
					response(result, player, id, action, false, "AccountNotReady")
				else
					response(result, player, id, action, true, nil, roster(player))
				end
				return
			end
			if action == "CheckNickname" then
				local canonical, err = normalizeNickname(p.nickname)
				if not canonical then
					response(result, player, id, action, false, err)
					return
				end
				local free, reason = nicknameStore:check(canonical)
				response(result, player, id, action, free, reason or (if free then nil else "NicknameTaken"))
				return
			end
			if action == "Select" then
				if typeof(p.characterId) ~= "string" then
					response(result, player, id, action, false, "InvalidCharacterId")
					return
				end
				local ok, reason
				if transferHandler ~= nil then
					ok, reason = PlayerDataService.prepareTransferCharacter(player, p.characterId)
					if ok then
						ok, reason = (transferHandler :: any)(player, p.characterId)
					end
				else
					ok, reason = PlayerDataService.selectCharacter(player, p.characterId)
					if ok and RunService:IsStudio() then
						-- DevCombined has no destination server. Keep arrival as a separate
						-- authoritative seam so production confirms it only after intent validation.
						ok, reason = PlayerDataService.confirmArrival(player)
					end
				end
				end
				response(result, player, id, action, ok, reason)
				return
			end
			if action == "CompleteIdentity" then
				local valid, reason = CharacterRules.validateCreation(p, looseStudioNicknames())
				if not valid or typeof(p.characterId) ~= "string" then
					response(result, player, id, action, false, reason or "InvalidCharacterId")
					return
				end
				local account = PlayerDataService.getAccountCopy(player)
				local existing = if account then account.Characters[p.characterId] else nil
				if existing == nil then
					response(result, player, id, action, false, "CharacterNotOwned")
					return
				end
				if not existing.NeedsIdentity then
					response(result, player, id, action, false, "IdentityAlreadyComplete")
					return
				end
				local canonical, canonicalError = normalizeNickname(p.nickname)
				if canonical == nil then
					response(result, player, id, action, false, canonicalError or "InvalidNickname")
					return
				end
				local display = displayNickname(p.nickname)
				if display == nil then
					response(result, player, id, action, false, "InvalidNickname")
					return
				end
				if not filtered(player, display) then
					response(result, player, id, action, false, "Filtered")
					return
				end
				local reserved, reserveReason =
					nicknameStore:reserve(canonical, { userId = player.UserId, characterId = p.characterId })
				if not reserved then
					response(result, player, id, action, false, reserveReason)
					return
				end
				local ok, mutationReason = PlayerDataService.mutateAccount(player, function(value)
					local c = value.Characters[p.characterId]
					if c == nil or not c.NeedsIdentity then
						error("identity changed")
					end
					c.Nickname = display
					c.ArchetypeId = p.archetypeId
					c.BodyType = p.bodyType
					c.AppearancePresetId = p.appearancePresetId or "default"
					c.NeedsIdentity = false
				end)
				if not ok then
					nicknameStore:release(canonical, { userId = player.UserId, characterId = p.characterId })
					response(result, player, id, action, false, mutationReason)
					return
				end
				response(result, player, id, action, true, nil, roster(player))
				return
			end
			if action == "Create" then
				local valid, reason = CharacterRules.validateCreation(p, looseStudioNicknames())
				if not valid then
					response(result, player, id, action, false, reason)
					return
				end
				local canonical, canonicalError = normalizeNickname(p.nickname)
				if canonical == nil then
					response(result, player, id, action, false, canonicalError or "InvalidNickname")
					return
				end
				local display = displayNickname(p.nickname)
				if display == nil then
					response(result, player, id, action, false, "InvalidNickname")
					return
				end
				if not filtered(player, display) then
					response(result, player, id, action, false, "Filtered")
					return
				end
				local account = PlayerDataService.getAccountCopy(player)
				if
					account == nil
					or not CharacterRules.hasCapacity(#account.CharacterOrder, account.CharacterSlotLimit)
				then
					response(result, player, id, action, false, "SlotLimit")
					return
				end
				local characterId = HttpService:GenerateGUID(false)
				local reserved, reserveReason =
					nicknameStore:reserve(canonical, { userId = player.UserId, characterId = characterId })
				if not reserved then
					response(result, player, id, action, false, reserveReason)
					return
				end
				local ok, mutationReason = PlayerDataService.mutateAccount(player, function(value)
					if not CharacterRules.hasCapacity(#value.CharacterOrder, value.CharacterSlotLimit) then
						error("slot limit")
					end
					local c: any = ProfileSchema.createDefault()
					c.CharacterId = characterId
					c.Nickname = display
					c.BodyType = p.bodyType
					c.AppearancePresetId = p.appearancePresetId or "default"
					c.ArchetypeId = p.archetypeId
					c.CreatedAt = os.time()
					c.LastPlayedAt = 0
					c.LastZoneId = "luna_village"
					c.NeedsIdentity = false
					value.Characters[characterId] = c
					table.insert(value.CharacterOrder, characterId)
				end)
				if not ok then
					nicknameStore:release(canonical, { userId = player.UserId, characterId = characterId })
					response(result, player, id, action, false, mutationReason)
					return
				end
				response(result, player, id, action, true, nil, roster(player))
				return
			end
			if action == "UpdateSettings" then
				local uiScale = tonumber(p.uiScale)
				local textScale = tonumber(p.textScale)
				local soundVolume = tonumber(p.soundVolume)
				if uiScale == nil or textScale == nil or soundVolume == nil then
					response(result, player, id, action, false, "InvalidSettings")
					return
				end
				local ok, reason = PlayerDataService.mutateAccount(player, function(value)
					value.Settings.UiScale = math.clamp(uiScale, 0.8, 1.2)
					value.Settings.TextScale = math.clamp(textScale, 0.85, 1.25)
					value.Settings.SoundVolume = math.clamp(soundVolume, 0, 1)
				end)
				response(result, player, id, action, ok, reason, if ok then roster(player) else nil)
				return
			end
			if action == "Delete" then
				if typeof(p.characterId) ~= "string" or typeof(p.confirmation) ~= "string" then
					response(result, player, id, action, false, "InvalidRequest")
					return
				end
				local account = PlayerDataService.getAccountCopy(player)
				local c = if account then account.Characters[p.characterId] else nil
				if c == nil then
					response(result, player, id, action, false, "CharacterNotOwned")
					return
				end
				if p.confirmation ~= CharacterConfig.DeleteConfirmationPrefix .. tostring(c.Nickname) then
					response(result, player, id, action, false, "ConfirmationMismatch")
					return
				end
				local canonical = normalizeNickname(c.Nickname)
				local ok, why = PlayerDataService.mutateAccount(player, function(value)
					value.Characters[p.characterId] = nil
					local i = table.find(value.CharacterOrder, p.characterId)
					if i then
						table.remove(value.CharacterOrder, i)
					end
					if value.SelectedCharacterId == p.characterId then
						value.SelectedCharacterId = nil
					end
				end)
				if not ok then
					response(result, player, id, action, false, why)
					return
				end
				if not PlayerDataService.saveNow(player) then
					response(result, player, id, action, false, "StoreError")
					return
				end
				local released, releaseReason =
					nicknameStore:release(canonical, { userId = player.UserId, characterId = p.characterId })
				response(result, player, id, action, released, releaseReason, roster(player))
				return
			end
			response(result, player, id, tostring(action), false, "UnknownAction")
		end)
	)
	table.insert(
		connections,
		Players.PlayerRemoving:Connect(function(p)
			rate[p] = nil
		end)
	)
end
function CharacterService.stop(): ()
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	table.clear(rate)
	nicknameStore = nil
	transferHandler = nil
	started = false
end
return CharacterService
