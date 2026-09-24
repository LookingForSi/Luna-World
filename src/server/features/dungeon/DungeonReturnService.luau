--!strict
local Players=game:GetService("Players")
local HttpService=game:GetService("HttpService")
local TeleportService=game:GetService("TeleportService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Config=require(ReplicatedStorage.Shared.dungeon.DungeonConfig)
local TransferConfig=require(ReplicatedStorage.Shared.config.TransferConfig)
local PlaceConfig=require(ReplicatedStorage.Shared.config.PlaceConfig)
local PlaceRole=require(ReplicatedStorage.Shared.core.runtime.PlaceRole)
local Rules=require(ReplicatedStorage.Shared.dungeon.DungeonHandoffRules)
local PlayerData=require(script.Parent.Parent.Parent.services.PlayerDataService)
local IntentStore=require(script.Parent.Parent.Parent.core.transfer.MemoryStoreTransferIntentStore)
local DungeonRun=require(script.Parent.DungeonRunService)
local Store=require(script.Parent.DungeonHandoffStore)
local Diagnostics=require(script.Parent.DungeonDiagnostics)
local Service={};local connection:RBXScriptConnection?=nil;local failure:RBXScriptConnection?=nil;local pending:{[Player]:any}={};local intents=IntentStore.new();local returnInProgress=false
local event=ReplicatedStorage.Remotes:WaitForChild("DungeonEvent")::RemoteEvent
local action=ReplicatedStorage.Remotes:WaitForChild("DungeonAction")::RemoteEvent
local function recover(player:Player,record:any):()if pending[player]~=record then return end;pending[player]=nil;returnInProgress=false;local p=record.profiles[tostring(player.UserId)];if p then intents:remove(p.transferId)end;if player.Parent==Players then PlayerData.recoverTransfer(player,true);event:FireClient(player,{state="RETURN_RETRY",message="Не удалось вернуться в Moonfall. Попробуйте снова."})end end
local function begin(player:Player):()
	if returnInProgress then return end
	local snapshot=DungeonRun.getSnapshot();local source=DungeonRun.getContract();if not snapshot or snapshot.state~="COMPLETED" or not DungeonRun.isParticipant(player) then return end;if pending[player]then return end
	returnInProgress=true
	local destination=PlaceConfig.getPlaceId(game.GameId,PlaceRole.World);if not destination then returnInProgress=false;event:FireClient(player,{state="FAILED",message="Moonfall Place не настроен."});return end
	local current={};for _,candidate in Players:GetPlayers()do if DungeonRun.isParticipant(candidate)and PlayerData.isReady(candidate)then table.insert(current,candidate)end end;if #current==0 then returnInProgress=false;return end
	local token=HttpService:GenerateGUID(false)..HttpService:GenerateGUID(false);local now=os.time();local profiles={};local prepared={}
	for _,candidate in current do local characterId=PlayerData.getActiveCharacterId(candidate);if not characterId then continue end;local transferId=HttpService:GenerateGUID(false);local ok=PlayerData.beginTransfer(candidate);if not ok then for _,old in prepared do PlayerData.recoverTransfer(old,true)end;returnInProgress=false;return end;table.insert(prepared,candidate);local intent={transferVersion=TransferConfig.Version,transferId=transferId,userId=candidate.UserId,characterId=characterId,sourceRole="Dungeon",destinationRole="World",entryPointId="luna_village",expiresAt=now+Config.ReturnTtlSeconds};if not intents:create(intent,Config.ReturnTtlSeconds)then for _,old in prepared do PlayerData.recoverTransfer(old,true)end;returnInProgress=false;return end;profiles[tostring(candidate.UserId)]={transferId=transferId,characterId=characterId}end
	local contract={schemaVersion=Config.SchemaVersion,kind="DungeonReturn",runId=snapshot.runId,nonce=token,sourceRole="Dungeon",destinationRole="World",leaderUserId=source.leaderUserId,memberUserIds=source.memberUserIds,profiles=profiles,issuedAt=now,expiresAt=now+Config.ReturnTtlSeconds};if not Store.put(token,contract,Config.ReturnTtlSeconds)then for _,old in prepared do PlayerData.recoverTransfer(old,true)end;returnInProgress=false;return end
	local record={profiles=profiles};for _,candidate in current do pending[candidate]=record;event:FireClient(candidate,{state="RETURNING",message="Возвращение в Moonfall..."})end;Diagnostics.event("RETURN_STARTED",{runId=snapshot.runId,count=#current})
	local options=Instance.new("TeleportOptions");options:SetTeleportData(Rules.routingPayload(token,contract));local ok=pcall(function()TeleportService:TeleportAsync(destination,current,options)end);if not ok then for _,candidate in current do recover(candidate,record)end end
end
local actionConnection:RBXScriptConnection?=nil
function Service.start():()local exit=workspace:WaitForChild(Config.ExitPromptName,15);local prompt=if exit then exit:FindFirstChildOfClass("ProximityPrompt")else nil;if prompt then connection=prompt.Triggered:Connect(begin)end;actionConnection=action.OnServerEvent:Connect(function(player,payload)if typeof(payload)=="table"and payload.action=="Return"then begin(player)end end);failure=TeleportService.TeleportInitFailed:Connect(function(player)local record=pending[player];if record then recover(player,record)end end)end
function Service.stop():()if connection then connection:Disconnect()end;if actionConnection then actionConnection:Disconnect()end;if failure then failure:Disconnect()end;table.clear(pending)end
return Service
