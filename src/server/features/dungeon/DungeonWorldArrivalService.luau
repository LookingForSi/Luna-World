--!strict
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Rules=require(ReplicatedStorage.Shared.dungeon.DungeonHandoffRules)
local IntentRules=require(ReplicatedStorage.Shared.core.transfer.TransferIntentRules)
local Config=require(ReplicatedStorage.Shared.dungeon.DungeonConfig)
local Store=require(script.Parent.DungeonHandoffStore)
local IntentStore=require(script.Parent.Parent.Parent.core.transfer.MemoryStoreTransferIntentStore)
local PlayerData=require(script.Parent.Parent.Parent.services.PlayerDataService)
local PartyService=require(script.Parent.Parent.party.PartyService)
local Diagnostics=require(script.Parent.DungeonDiagnostics)
local Service={};local contracts:{[Player]:any}={};local connections={};local intents=IntentStore.new();local sessions:{[string]:any}={}
function Service.isPayload(player:Player):boolean return Rules.isRoutingPayload(player:GetJoinData().TeleportData,"World")end
function Service.admit(player:Player):(boolean,string?)local data=player:GetJoinData().TeleportData;local contract=Store.get(data.dungeonToken);local ok,reason=Rules.validate(contract,os.time(),"World",player.UserId);if not ok or contract.kind~="DungeonReturn"then Diagnostics.reject("RETURN_HANDOFF",{userId=player.UserId,reason=reason});return false,reason or "WrongKind"end;contracts[player]=contract;return true,nil end
local function reconstruct(contract:any):()local id=contract.runId;if sessions[id]then return end;sessions[id]=true;task.delay(Config.PartyReconstructionDelaySeconds,function()local ok=PartyService.restoreTrusted(id,contract.leaderUserId,contract.memberUserIds);if not ok then sessions[id]=nil end end)end
local function arrive(player:Player):()local contract=contracts[player];if not contract then return end;local p=contract.profiles[tostring(player.UserId)];local intent,why=intents:consume(p.transferId,{userId=player.UserId,characterId=p.characterId,destinationRole="World",entryPointId="luna_village"});if not intent then PlayerData.failSession(player,why or "ReturnIntentMissing");return end;local valid=IntentRules.validate(intent,os.time(),"World");if not valid then PlayerData.failSession(player,"ReturnIntentInvalid");return end;local selected,reason=PlayerData.selectCharacter(player,p.characterId);if not selected or not PlayerData.confirmArrival(player)then PlayerData.failSession(player,reason or "ReturnActivationFailed");return end;reconstruct(contract);Store.removeRejoin(player.UserId);Diagnostics.event("RETURN_COMPLETED",{runId=contract.runId,userId=player.UserId})end
function Service.start():()table.insert(connections,PlayerData.AccountReady:Connect(arrive));for _,p in Players:GetPlayers()do if PlayerData.isAccountReady(p)then task.spawn(arrive,p)end end end
function Service.stop():()for _,c in connections do c:Disconnect()end;table.clear(connections);table.clear(contracts);table.clear(sessions)end
return Service
