--!strict
local Players=game:GetService("Players")
local HttpService=game:GetService("HttpService")
local TeleportService=game:GetService("TeleportService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Config=require(ReplicatedStorage.Shared.dungeon.DungeonConfig)
local PlaceConfig=require(ReplicatedStorage.Shared.config.PlaceConfig)
local PlaceRole=require(ReplicatedStorage.Shared.core.runtime.PlaceRole)
local Rules=require(ReplicatedStorage.Shared.dungeon.DungeonHandoffRules)
local UnlockRules=require(ReplicatedStorage.Shared.dungeon.DungeonUnlockRules)
local TransferConfig=require(ReplicatedStorage.Shared.config.TransferConfig)
local PartyService=require(script.Parent.Parent.party.PartyService)
local PlayerDataService=require(script.Parent.Parent.Parent.services.PlayerDataService)
local SessionGuardService=require(script.Parent.Parent.Parent.session.SessionGuardService)
local IntentStore=require(script.Parent.Parent.Parent.core.transfer.MemoryStoreTransferIntentStore)
local Store=require(script.Parent.DungeonHandoffStore)
local Diagnostics=require(script.Parent.DungeonDiagnostics)
local Service={}; local connections={}; local pending:{[Player]:any}={}; local confirmations:{[Player]:any}={}; local prompt:ProximityPrompt?=nil; local promptConnection:RBXScriptConnection?=nil; local studioHandler:((Player,any)->())?=nil
local event=ReplicatedStorage.Remotes:WaitForChild("DungeonEvent")::RemoteEvent
local action=ReplicatedStorage.Remotes:WaitForChild("DungeonAction")::RemoteEvent
local intents=IntentStore.new()
local function send(player:Player,state:string,message:string?,extra:any?) local payload=extra or {};payload.state=state;payload.message=message;event:FireClient(player,payload) end
local function recover(player:Player,record:any,reason:string):()
	if pending[player]~=record then return end
	SessionGuardService.cancelHandoff({player})
	pending[player]=nil; for _,profile in record.profiles do intents:remove(profile.transferId) end
	if player.Parent==Players then PlayerDataService.recoverTransfer(player,true);send(player,"RETRY_AVAILABLE","Не удалось войти в подземелье. Попробуйте ещё раз.") end
	Diagnostics.reject("TRANSFER",{userId=player.UserId,reason=reason})
end
local function prepare(leader:Player,confirmationToken:any):()
	local confirmation=confirmations[leader];confirmations[leader]=nil
	if typeof(confirmationToken)~="string" or not confirmation or confirmation.token~=confirmationToken or os.clock()>confirmation.expiresAt then Diagnostics.reject("ENTRY_CONFIRMATION",{userId=leader.UserId,reason="ExpiredOrSpoofed"});send(leader,"RETRY_AVAILABLE","Подтверждение входа недействительно. Активируйте вход ещё раз.");return end
	if pending[leader] then return end; if not PlayerDataService.isReady(leader) then send(leader,"FAILED","Персонаж ещё не готов.");return end
	local snapshot=PartyService.getSnapshot(leader);local members=if snapshot then snapshot.memberUserIds else {leader.UserId};local leaderId=if snapshot then snapshot.leaderUserId else leader.UserId
	if leaderId~=leader.UserId then send(leader,"FAILED","Только лидер группы может начать подземелье.");return end
	send(leader,"PREPARING","Подготовка подземелья...")
	local players={};local partyUnlocked=false;for _,id in members do local p=Players:GetPlayerByUserId(id);if not p or not PlayerDataService.isReady(p) then send(leader,"FAILED","Не все участники готовы.");return end;local profile=PlayerDataService.getProfileCopy(p);partyUnlocked=partyUnlocked or (profile~=nil and UnlockRules.isUnlocked(profile.Quests));table.insert(players,p) end
	if not partyUnlocked then send(leader,"FAILED","Древняя печать ещё не разрушена.");return end
	if snapshot and PartyService.getSnapshot(leader).revision~=snapshot.revision then send(leader,"FAILED","Состав группы изменился. Попробуйте снова.");return end
	if RunService:IsStudio() and studioHandler then local now=os.time();local contract={schemaVersion=Config.SchemaVersion,kind="DungeonEntry",runId=HttpService:GenerateGUID(false),nonce=HttpService:GenerateGUID(false)..HttpService:GenerateGUID(false),sourceRole="World",destinationRole="Dungeon",leaderUserId=leaderId,memberUserIds=table.clone(members),profiles={},accessCode="STUDIO",issuedAt=now,expiresAt=now+Config.RunTtlSeconds};studioHandler(leader,contract);return end
	local destination=PlaceConfig.getPlaceId(game.GameId,PlaceRole.Dungeon);if not destination and not (RunService:IsStudio() and studioHandler) then send(leader,"FAILED","Dungeon Place ещё не настроен.");return end
	local runId=HttpService:GenerateGUID(false);local token=HttpService:GenerateGUID(false)..HttpService:GenerateGUID(false);local now=os.time();local profiles={};local prepared={}
	local accessCode="STUDIO";if destination then local ok,value=pcall(function() return TeleportService:ReserveServer(destination) end);if not ok then send(leader,"RETRY_AVAILABLE","Не удалось подготовить подземелье.");return end;accessCode=value end
	for _,p in players do
		local characterId=PlayerDataService.getActiveCharacterId(p);if not characterId then send(leader,"FAILED","Персонаж участника не выбран.");return end
		local transferId=HttpService:GenerateGUID(false);local released,why=PlayerDataService.beginTransfer(p);if not released then for _,old in prepared do PlayerDataService.recoverTransfer(old,true) end;send(leader,"RETRY_AVAILABLE","Не удалось сохранить прогресс группы.");Diagnostics.reject("PROFILE_RELEASE",{userId=p.UserId,reason=why});return end
		table.insert(prepared,p);local intent={transferVersion=TransferConfig.Version,transferId=transferId,userId=p.UserId,characterId=characterId,sourceRole="World",destinationRole="Dungeon",entryPointId="selene_entrance",expiresAt=now+Config.HandoffTtlSeconds};local made= intents:create(intent,Config.HandoffTtlSeconds);if not made then for _,old in prepared do PlayerDataService.recoverTransfer(old,true) end;send(leader,"RETRY_AVAILABLE","Не удалось подготовить переход.");return end
		profiles[tostring(p.UserId)]={transferId=transferId,characterId=characterId}
	end
	local current=PartyService.getSnapshot(leader);if snapshot and (not current or current.partyId~=snapshot.partyId or current.revision~=snapshot.revision)then for _,p in prepared do PlayerDataService.recoverTransfer(p,true)end;send(leader,"RETRY_AVAILABLE","Состав группы изменился. Попробуйте снова.");return end
	local contract={schemaVersion=Config.SchemaVersion,kind="DungeonEntry",runId=runId,nonce=token,sourceRole="World",destinationRole="Dungeon",leaderUserId=leaderId,memberUserIds=table.clone(members),profiles=profiles,accessCode=accessCode,issuedAt=now,expiresAt=now+Config.HandoffTtlSeconds}
	local stored=Store.put(token,contract);if not stored then for _,p in prepared do PlayerDataService.recoverTransfer(p,true) end;send(leader,"RETRY_AVAILABLE","Не удалось сохранить пропуск.");return end
	local record={token=token,profiles=profiles,players=players,runId=runId};for _,p in players do pending[p]=record;send(p,"TELEPORTING","Переход в Руины Селены...") end;Diagnostics.event("TRANSFER_PREPARED",{runId=runId,leaderUserId=leaderId,count=#players})
	local routingPayload,routingReason=SessionGuardService.attachRoutingPayload(Rules.routingPayload(token,contract),players);if not routingPayload then for _,p in players do recover(p,record,routingReason or "SessionGuardRoutingFailed") end;return end
	local handoffOk,handoffReason=SessionGuardService.beginHandoff(players);if not handoffOk then for _,p in players do recover(p,record,handoffReason or "SessionGuardHandoffFailed") end;return end
	local options=Instance.new("TeleportOptions");options.ReservedServerAccessCode=accessCode;options:SetTeleportData(routingPayload);local ok,err=pcall(function() TeleportService:TeleportAsync(destination::number,players,options) end);if not ok then for _,p in players do recover(p,record,tostring(err)) end end
end
local function tryRejoin(player: Player): ()
	if pending[player] or not PlayerDataService.isReady(player) then return end
	local ticket = Store.getRejoin(player.UserId)
	if not Rules.rejoinValid(ticket, os.time(), player.UserId) then return end
	local destination = PlaceConfig.getPlaceId(game.GameId, PlaceRole.Dungeon); if not destination then return end
	local characterId = PlayerDataService.getActiveCharacterId(player); if not characterId then return end
	local transferId = HttpService:GenerateGUID(false); local released = PlayerDataService.beginTransfer(player); if not released then return end
	local now=os.time(); local intent={transferVersion=TransferConfig.Version,transferId=transferId,userId=player.UserId,characterId=characterId,sourceRole="World",destinationRole="Dungeon",entryPointId="selene_entrance",expiresAt=now+Config.HandoffTtlSeconds}
	if not intents:create(intent,Config.HandoffTtlSeconds) then PlayerDataService.recoverTransfer(player,true); return end
	local token=HttpService:GenerateGUID(false)..HttpService:GenerateGUID(false); local profiles={[tostring(player.UserId)]={transferId=transferId,characterId=characterId}}
	local contract={schemaVersion=Config.SchemaVersion,kind="DungeonRejoin",runId=ticket.runId,nonce=token,sourceRole="World",destinationRole="Dungeon",leaderUserId=ticket.leaderUserId,memberUserIds=ticket.memberUserIds,profiles=profiles,accessCode=ticket.accessCode,issuedAt=now,expiresAt=now+Config.HandoffTtlSeconds}
	if not Store.put(token,contract) then PlayerDataService.recoverTransfer(player,true); return end
	local record={token=token,profiles=profiles,players={player},runId=ticket.runId};pending[player]=record;send(player,"TELEPORTING","Возвращение в активное подземелье...")
	local routingPayload,routingReason=SessionGuardService.attachRoutingPayload(Rules.routingPayload(token,contract),{player});if not routingPayload then recover(player,record,routingReason or "SessionGuardRoutingFailed");return end
	local handoffOk,handoffReason=SessionGuardService.beginHandoff({player});if not handoffOk then recover(player,record,handoffReason or "SessionGuardHandoffFailed");return end
	local options=Instance.new("TeleportOptions");options.ReservedServerAccessCode=ticket.accessCode;options:SetTeleportData(routingPayload);local ok=pcall(function()TeleportService:TeleportAsync(destination,{player},options)end);if not ok then recover(player,record,"RejoinTeleportFailed")end
end
function Service.setStudioHandler(handler:((Player,any)->())?):() studioHandler=handler end
function Service.bindEntrancePrompt(nextPrompt: ProximityPrompt?): ()
	if promptConnection then promptConnection:Disconnect();promptConnection=nil end
	prompt=nextPrompt
	if prompt then
		promptConnection=prompt.Triggered:Connect(function(player)
			if confirmations[player]and os.clock()-confirmations[player].issuedAt<Config.PromptDebounceSeconds then return end
			local token=HttpService:GenerateGUID(false);local now=os.clock();confirmations[player]={token=token,issuedAt=now,expiresAt=now+Config.ConfirmationTtlSeconds};local s=PartyService.getSnapshot(player);local count=if s then #s.memberUserIds else 1
			send(player,"CONFIRM_ENTRY",if s then string.format("Войти в Руины Селены группой? Участников: %d/4",count) else "Войти в Руины Селены?",{memberCount=count,confirmationToken=token})
		end)
	end
end
function Service.start():()
	table.insert(connections,action.OnServerEvent:Connect(function(player,payload)if typeof(payload)~="table" or payload.action~="ConfirmEntry" then return end;prepare(player,payload.confirmationToken) end))
	table.insert(connections,TeleportService.TeleportInitFailed:Connect(function(player,_result,message)local record=pending[player];if record then recover(player,record,message) end end))
	table.insert(connections,Players.PlayerRemoving:Connect(function(player)pending[player]=nil;confirmations[player]=nil end))
	table.insert(connections,PlayerDataService.CharacterReady:Connect(function(player) task.delay(.5,tryRejoin,player) end))
end
function Service.stop():()Service.bindEntrancePrompt(nil);for _,c in connections do c:Disconnect() end;table.clear(connections);table.clear(pending);table.clear(confirmations);studioHandler=nil end
return Service
