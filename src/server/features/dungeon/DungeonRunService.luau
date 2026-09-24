--!strict
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Rules=require(ReplicatedStorage.Shared.dungeon.DungeonRunRules)
local Config=require(ReplicatedStorage.Shared.dungeon.DungeonConfig)
local ProgressionService=require(script.Parent.Parent.Parent.services.ProgressionService)
local InventoryService=require(script.Parent.Parent.Parent.services.InventoryService)
local PlayerDataService=require(script.Parent.Parent.Parent.services.PlayerDataService)
local Service={}
local run:any=nil; local connections={}
local function transition(to:string):boolean if not run or not Rules.canTransition(run.state,to) then return false end; run.state=to; return true end
function Service.create(contract:any):boolean
	if run then return run.runId==contract.runId end
	local ok=Rules.validateParticipants(contract.memberUserIds,contract.leaderUserId); if not ok then return false end
	run={runId=contract.runId,leaderUserId=contract.leaderUserId,participants=table.clone(contract.memberUserIds),createdAt=workspace:GetServerTimeNow(),state="CREATED",encounter=0,bossDead=false,claimed={},arrived={},connected={}}
	transition("ENTERING"); return true
end
function Service.admit(player:Player,contract:any):(boolean,string?)
	if not Service.create(contract) or run.runId~=contract.runId then return false,"WrongRun" end
	local member=false; for _,id in run.participants do member=member or id==player.UserId end; if not member then return false,"NotParticipant" end
	run.arrived[player.UserId]=true; run.connected[player.UserId]=true; if run.state=="ENTERING" then transition("ACTIVE") end; return true,nil
end
function Service.recordEncounter(index:number):boolean local nextValue,ok=Rules.advanceEncounter(run and run.encounter or 0,index,false); if ok then run.encounter=nextValue; if index==3 then transition("BOSS") end end; return ok end
function Service.completeBoss():boolean if not run or run.state~="BOSS" or run.bossDead then return false end; run.bossDead=true; transition("COMPLETED"); return true end
function Service.claimReward(player:Player):boolean
	if not run or run.state~="COMPLETED" then return false end; local member=false; for _,id in run.participants do member=member or id==player.UserId end; if not member then return false end
	local ok,nextClaims=Rules.claim(run.claimed,player.UserId); if not ok then return false end
	-- Reserve before mutations: a retry must never duplicate a partially delivered reward.
	run.claimed=nextClaims
	ProgressionService.awardXP(player,Config.CompletionXP)
	PlayerDataService.mutate(player,function(profile) profile.Luna += Config.CompletionLuna end)
	InventoryService.grantItem(player,Config.CompletionItemId,1)
	return true
end
function Service.getSnapshot():any if not run then return nil end; return {runId=run.runId,state=run.state,encounter=run.encounter,bossDead=run.bossDead,leaderUserId=run.leaderUserId,participants=table.clone(run.participants)} end
function Service.start():() table.insert(connections,Players.PlayerRemoving:Connect(function(p) if run then run.connected[p.UserId]=nil end end)) end
function Service.stop():() for _,c in connections do c:Disconnect() end; table.clear(connections); run=nil end
return Service
