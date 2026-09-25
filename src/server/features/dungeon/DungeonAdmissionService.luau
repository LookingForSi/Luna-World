--!strict
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Rules=require(ReplicatedStorage.Shared.dungeon.DungeonHandoffRules)
local IntentRules=require(ReplicatedStorage.Shared.core.transfer.TransferIntentRules)
local Store=require(script.Parent.DungeonHandoffStore)
local IntentStore=require(script.Parent.Parent.Parent.core.transfer.MemoryStoreTransferIntentStore)
local PlayerData=require(script.Parent.Parent.Parent.services.PlayerDataService)
local DungeonRun=require(script.Parent.DungeonRunService)
local Diagnostics=require(script.Parent.DungeonDiagnostics)
local Service={};local connections={};local processing:{[Player]:boolean}={};local contracts:{[Player]:any}={};local intents=IntentStore.new()
local function payload(player:Player):any return player:GetJoinData().TeleportData end
function Service.admit(player:Player):(boolean,string?)
	local data=payload(player);if not Rules.isRoutingPayload(data,"Dungeon") then return false,"InvalidDungeonRouting" end
	local contract=Store.get(data.dungeonToken);local ok,reason=Rules.validate(contract,os.time(),"Dungeon",player.UserId);if not ok or data.runId~=contract.runId or contract.kind~="DungeonEntry" and contract.kind~="DungeonRejoin" then Diagnostics.reject("HANDOFF",{userId=player.UserId,reason=reason});return false,reason or "WrongKind" end
	contracts[player]=contract;Diagnostics.event("HANDOFF_ACCEPTED",{runId=contract.runId,userId=player.UserId});return true,nil
end
local function arrive(player:Player):()
	if processing[player] then return end;processing[player]=true;local contract=contracts[player];if not contract then local ok=Service.admit(player);if not ok then PlayerData.failSession(player,"DungeonAdmissionRejected");processing[player]=nil;return end;contract=contracts[player] end
	local profile=contract.profiles[tostring(player.UserId)];local intent,why=intents:consume(profile.transferId,{userId=player.UserId,characterId=profile.characterId,destinationRole="Dungeon",entryPointId="selene_entrance"})
	local valid=if intent then IntentRules.validate(intent,os.time(),"Dungeon") else false;if not valid then PlayerData.failSession(player,why or "ProfileIntentRejected");processing[player]=nil;return end
	local selected,reason=PlayerData.selectCharacter(player,profile.characterId);if not selected or not PlayerData.confirmArrival(player) then PlayerData.failSession(player,reason or "CharacterActivationFailed");processing[player]=nil;return end
	local admitted,runReason=DungeonRun.admit(player,contract);if not admitted then PlayerData.failSession(player,runReason or "RunAdmissionFailed");processing[player]=nil;return end
	Diagnostics.event(if contract.kind=="DungeonRejoin" then "REJOIN_ACCEPTED" else "PLAYER_ADMITTED",{runId=contract.runId,userId=player.UserId});processing[player]=nil
end
function Service.start():()PlayerData.setPreClaimValidator(Service.admit);table.insert(connections,PlayerData.AccountReady:Connect(arrive));for _,p in Players:GetPlayers() do if PlayerData.isAccountReady(p) then task.spawn(arrive,p) end end end
function Service.stop():()PlayerData.setPreClaimValidator(nil);for _,c in connections do c:Disconnect() end;table.clear(connections);table.clear(processing);table.clear(contracts) end
return Service
