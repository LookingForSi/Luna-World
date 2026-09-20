--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local QuestDefinitions = require(ReplicatedStorage.Shared.definitions.QuestDefinitions)
local NpcDefinitions = require(ReplicatedStorage.Shared.definitions.NpcDefinitions)
local TravelDefinitions = require(ReplicatedStorage.Shared.definitions.TravelDefinitions)
local QuestRules = require(ReplicatedStorage.Shared.quests.QuestRules)
local TravelRules = require(ReplicatedStorage.Shared.travel.TravelRules)
local WorldLayout = require(ReplicatedStorage.Shared.world.WorldLayout)
local MobService = require(script.Parent.MobService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ProgressionService = require(script.Parent.ProgressionService)

local QuestService = {}
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local acceptRemote = remotes:WaitForChild("QuestAcceptRequest") :: RemoteEvent
local turnInRemote = remotes:WaitForChild("QuestTurnInRequest") :: RemoteEvent
local snapshotRequest = remotes:WaitForChild("QuestSnapshotRequest") :: RemoteEvent
local snapshotEvent = remotes:WaitForChild("QuestSnapshot") :: RemoteEvent
local resultEvent = remotes:WaitForChild("QuestActionResult") :: RemoteEvent
local dialogueEvent = remotes:WaitForChild("DialogueOpen") :: RemoteEvent
local connections: { RBXScriptConnection } = {}
local generation = 0
local started = false
local lastRequest: { [Player]: number } = {}

local function poi(id: string): Vector3?
	for _, value in WorldLayout.PointsOfInterest do if value.id == id then return value.position end end
	return nil
end

local function npcPosition(npcId: string): Vector3?
	local definition = NpcDefinitions[npcId]
	if definition == nil then return nil end
	local world = workspace:FindFirstChild("LunaWorldPlayableBlockout")
	local model = if world then world:FindFirstChild(definition.modelName, true) else nil
	if model and model:IsA("Model") then return model:GetPivot().Position end
	local base = poi(definition.poiId)
	return if base ~= nil then base + (definition.positionOffset or Vector3.zero) else nil
end

local function nearLivingNpc(player: Player, npcId: string): boolean
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local position = npcPosition(npcId)
	return root ~= nil and root:IsA("BasePart") and humanoid ~= nil and humanoid.Health > 0 and position ~= nil and (root.Position - position).Magnitude <= 18
end

local function objectiveSnapshot(objective: any, progress: number): any
	return { id=objective.id, displayText=objective.displayText, kind=objective.kind, required=objective.required, progress=progress, mobId=objective.mobId, npcId=objective.npcId, poiId=objective.poiId, waypointPoiId=objective.waypointPoiId }
end

local function createSnapshot(player: Player): any
	local profile = PlayerDataService.getProfileCopy(player)
	local values = {}
	if profile == nil then return { quests=values, markers={} } end
	for questId, record in profile.Quests do
		if record.State == "Completed" then continue end
		local definition = QuestDefinitions[questId]
		local objectives = {}
		for _, objective in definition.objectives do table.insert(objectives, objectiveSnapshot(objective, record.Progress[objective.id] or 0)) end
		table.insert(values, {
			id=questId,
			displayName=definition.displayName,
			description=definition.description,
			state=record.State,
			turnInNpcId=definition.turnInNpcId,
			rewardXP=definition.rewardXP,
			rewardLuna=definition.rewardLuna,
			objectives=objectives,
		})
	end
	table.sort(values, function(a,b) return a.id < b.id end)
	local markerByNpc = {}
	for questId, definition in QuestDefinitions do
		local record = profile.Quests[questId]
		if record and record.State == "ReadyToTurnIn" then
			markerByNpc[definition.turnInNpcId] = "?"
		elseif record and record.State == "Active" then
			for _, objective in definition.objectives do
				if objective.kind == "TalkToNpc"
					and objective.npcId ~= nil
					and (record.Progress[objective.id] or 0) < objective.required
				then
					markerByNpc[objective.npcId] = "?"
				end
			end
		elseif QuestRules.isAvailable(profile.Quests, questId) and markerByNpc[definition.giverNpcId] == nil then
			markerByNpc[definition.giverNpcId] = "!"
		end
	end
	local markers = {}; for npcId, symbol in markerByNpc do table.insert(markers,{npcId=npcId,symbol=symbol}) end
	return { quests=values, markers=markers }
end

function QuestService.push(player: Player): () snapshotEvent:FireClient(player, createSnapshot(player)) end

local function mutateCredit(player: Player, kind: string, targetId: string): { string }
	local changed = {}
	if not PlayerDataService.isReady(player) then return changed end
	PlayerDataService.mutate(player, function(profile) changed = QuestRules.credit(profile, kind, targetId) end)
	if #changed > 0 then QuestService.push(player) end
	return changed
end

local function finish(player: Player, questId: string, npcId: string): (boolean, string?)
	local ok, reason = false, nil
	local mutated, mutationReason = PlayerDataService.mutate(player, function(profile) ok, reason = QuestRules.turnIn(profile, questId, npcId) end)
	if not mutated then return false, mutationReason end
	if ok then ProgressionService.syncFromProfile(player); QuestService.push(player) end
	return ok, reason
end

function QuestService.openNpc(player: Player, npcId: string): ()
	if NpcDefinitions[npcId] == nil or not PlayerDataService.isReady(player) or not nearLivingNpc(player, npcId) then return end
	local changed = mutateCredit(player, "TalkToNpc", npcId)
	for _, questId in changed do
		local definition = QuestDefinitions[questId]
		if definition.autoTurnIn and definition.turnInNpcId == npcId then finish(player, questId, npcId) end
	end
	local profile = PlayerDataService.getProfileCopy(player)
	if profile == nil then return end
	local topics = {}
	local message: string? = nil
	for questId, definition in QuestDefinitions do
		local record = profile.Quests[questId]
		if QuestRules.isAvailable(profile.Quests, questId) and definition.giverNpcId == npcId then
			if message == nil then message = "Есть дело, с которым нужна помощь." end
			table.insert(topics, {
				kind="AcceptQuest",
				questId=questId,
				text="Квест",
				title=definition.displayName,
				description=definition.description,
				rewardXP=definition.rewardXP,
				rewardLuna=definition.rewardLuna,
			})
		elseif record and record.State == "ReadyToTurnIn" and definition.turnInNpcId == npcId and not definition.autoTurnIn then
			if message == nil then message = "Похоже, ты справился." end
			table.insert(topics, {
				kind="TurnInQuest",
				questId=questId,
				text="Квест",
				title=definition.displayName,
				description=definition.description,
				rewardXP=definition.rewardXP,
				rewardLuna=definition.rewardLuna,
			})
		end
	end

	for travelId, definition in TravelDefinitions do
		if TravelRules.isUnlocked(profile.Quests, definition) then
			local destinationNpcId = TravelRules.destinationNpcId(definition, npcId)
			local destination = if destinationNpcId ~= nil then NpcDefinitions[destinationNpcId] else nil
			if destination ~= nil then
				table.insert(topics, {
					kind="Travel",
					travelId=travelId,
					text="Телепорт",
					destinationNpcId=destinationNpcId,
					destinationName=destination.displayName,
					routeName=definition.displayName,
					costLuna=TravelRules.costLuna(definition),
				})
			end
		end
	end
	dialogueEvent:FireClient(player, {
		npcId=npcId,
		displayName=NpcDefinitions[npcId].displayName,
		message=message,
		topics=topics,
	})
end

local function validId(value: unknown): boolean return typeof(value)=="string" and #value > 0 and #value <= 64 end
local function handle(player: Player, action: string, ...: unknown): ()
	if select("#", ...) ~= 2 then return end
	local questId, npcId = select(1,...), select(2,...)
	if not validId(questId) or not validId(npcId) or QuestDefinitions[questId :: string] == nil or NpcDefinitions[npcId :: string] == nil then return end
	local now=workspace:GetServerTimeNow(); if lastRequest[player] and now-lastRequest[player]<0.1 then return end; lastRequest[player]=now
	if not PlayerDataService.isReady(player) or not nearLivingNpc(player, npcId :: string) then resultEvent:FireClient(player,{action=action,ok=false,reason="TooFar"}); return end
	local ok, reason = false, nil
	if action == "Accept" then
		local mutated, mutationReason = PlayerDataService.mutate(player,function(profile) ok,reason=QuestRules.accept(profile,questId :: string,npcId :: string) end)
		if not mutated then ok=false;reason=mutationReason end
	else ok,reason=finish(player,questId :: string,npcId :: string) end
	resultEvent:FireClient(player,{action=action,questId=questId,ok=ok,reason=reason})
	if ok then QuestService.push(player) end
end

function QuestService.start(): ()
	if started then return end; started=true; generation+=1; local own=generation
	table.insert(connections,acceptRemote.OnServerEvent:Connect(function(player,...) handle(player,"Accept",...) end))
	table.insert(connections,turnInRemote.OnServerEvent:Connect(function(player,...) handle(player,"TurnIn",...) end))
	table.insert(connections,snapshotRequest.OnServerEvent:Connect(function(player,...) if select("#",...)==0 and PlayerDataService.isReady(player) then QuestService.push(player) end end))
	table.insert(connections,MobService.MobDied:Connect(function(killer,mobId) if killer then mutateCredit(killer,"KillMob",mobId) end end))
	table.insert(connections,PlayerDataService.ProfileReady:Connect(function(player) QuestService.push(player) end))
	table.insert(connections,Players.PlayerRemoving:Connect(function(player) lastRequest[player]=nil end))
	task.spawn(function() while started and generation==own do task.wait(0.5); for _,player in Players:GetPlayers() do
		local profile=PlayerDataService.getProfileCopy(player); local character=player.Character; local root=if character then character:FindFirstChild("HumanoidRootPart") else nil; local humanoid=if character then character:FindFirstChildOfClass("Humanoid") else nil
		if profile and root and root:IsA("BasePart") and humanoid and humanoid.Health>0 then for questId,record in profile.Quests do if record.State=="Active" then for _,objective in QuestDefinitions[questId].objectives do if objective.kind=="ReachLocation" and (record.Progress[objective.id] or 0)<objective.required then local position=poi(objective.poiId); if position and (root.Position-position).Magnitude<=objective.radius then mutateCredit(player,"ReachLocation",objective.poiId) end end end end end end
	end end end)
end
function QuestService.stop(): () if not started then return end;started=false;generation+=1;for _,c in connections do c:Disconnect() end;table.clear(connections);table.clear(lastRequest) end
return QuestService
