--!strict
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Rules=require(ReplicatedStorage.Shared.dungeon.DungeonRunRules)
local Config=require(ReplicatedStorage.Shared.dungeon.DungeonConfig)
local Progression=require(script.Parent.Parent.Parent.services.ProgressionService)
local Inventory=require(script.Parent.Parent.Parent.services.InventoryService)
local PlayerData=require(script.Parent.Parent.Parent.services.PlayerDataService)
local Store=require(script.Parent.DungeonHandoffStore)
local Diagnostics=require(script.Parent.DungeonDiagnostics)
local DungeonWorld=require(script.Parent.DungeonWorldService)
local Service={};local run:any=nil;local connections={};local characterConnections:{[Player]:RBXScriptConnection}={};local deathConnections:{[Player]:RBXScriptConnection}={};local characterGraceUntil:{[Player]:number}={};local oobCharacters:{[Model]:boolean}={};local wipeGeneration=0
local changed=Instance.new("BindableEvent");local wipe=Instance.new("BindableEvent");Service.Changed=changed.Event;Service.Wipe=wipe.Event
local event=ReplicatedStorage.Remotes:WaitForChild("DungeonEvent")::RemoteEvent
local objectives={"Очистите внешний зал","Победите Стража руин","Пройдите во внутреннее святилище","Победите Падшего Стража Селены","Подземелье завершено"}
local function log(name:string,fields:any?)Diagnostics.event(name,fields)end
local function broadcast(state:string,message:string?,extra:any?)local p=extra or {};p.state=state;p.message=message;if run then p.runId=run.runId;p.encounter=run.encounter;p.objective=objectives[math.min(run.encounter+1,#objectives)] end;for _,player in Players:GetPlayers() do if run and run.memberSet[player.UserId] then event:FireClient(player,p) end end end
local function transition(to:string):boolean if not run or not Rules.canTransition(run.state,to) then return false end;run.state=to;changed:Fire(Service.getSnapshot());return true end
local function checkpoint():BasePart?return DungeonWorld.getCheckpoint(run and run.encounter or 0)end
local function bindCharacter(player:Player,character:Model):()
	if deathConnections[player] then deathConnections[player]:Disconnect() end;local humanoid=character:WaitForChild("Humanoid",10);local root=character:WaitForChild("HumanoidRootPart",10);if not humanoid or not humanoid:IsA("Humanoid") then return end
	run.alive[player.UserId]=true;local cp=checkpoint();if cp and root and root:IsA("BasePart") then character:PivotTo(cp.CFrame+Vector3.new(0,4,0)) end
	characterGraceUntil[player]=os.clock()+1;oobCharacters[character]=nil
	deathConnections[player]=humanoid.Died:Connect(function()if not run or run.state=="COMPLETED" or run.state=="CLOSED" then return end;run.alive[player.UserId]=false;wipeGeneration+=1;local generation=wipeGeneration;task.delay(.25,function()if not run or generation~=wipeGeneration then return end;if Rules.allDead(run.participants,run.alive,run.connected) then run.resetGeneration+=1;log("PARTY_WIPE",{runId=run.runId,encounterId=run.encounter+1});broadcast("WIPE","Группа погибла. Возвращение к последней точке...");wipe:Fire(run.encounter+1,run.resetGeneration);for _,id in run.participants do local p=Players:GetPlayerByUserId(id);if p and run.connected[id] then task.delay(1,function()if p.Parent==Players then p:LoadCharacter() end end) end end end end)end)
end
function Service.create(contract:any):boolean
	if run then return run.runId==contract.runId end;local ok=Rules.validateParticipants(contract.memberUserIds,contract.leaderUserId);if not ok then return false end;local set={};for _,id in contract.memberUserIds do set[id]=true end
	run={runId=contract.runId,leaderUserId=contract.leaderUserId,participants=table.clone(contract.memberUserIds),memberSet=set,contract=contract,createdAt=os.time(),expiresAt=os.time()+Config.RunTtlSeconds,state="CREATED",encounter=0,bossDead=false,claimed={},arrived={},connected={},alive={},resetGeneration=0};transition("ENTERING");log("RUN_CREATED",{runId=run.runId,leaderUserId=run.leaderUserId});return true
end
function Service.admit(player:Player,contract:any):(boolean,string?)
	if not Service.create(contract) or run.runId~=contract.runId then return false,"WrongRun" end;if not run.memberSet[player.UserId] then return false,"NotParticipant" end
	run.arrived[player.UserId]=true;run.connected[player.UserId]=true;run.alive[player.UserId]=true;if run.state=="ENTERING" then transition("ACTIVE");log("ENCOUNTER_STARTED",{runId=run.runId,encounterId=1}) end
	characterConnections[player]=player.CharacterAdded:Connect(function(c)bindCharacter(player,c)end);if player.Character then bindCharacter(player,player.Character)end;broadcast("ACTIVE",nil);return true,nil
end
function Service.recordEncounter(index:number):boolean local n,ok=Rules.advanceEncounter(run and run.encounter or 0,index,false);if not ok then return false end;run.encounter=n;log("ENCOUNTER_COMPLETED",{runId=run.runId,encounterId=index});if index==3 then transition("BOSS");log("BOSS_STARTED",{runId=run.runId})end;changed:Fire(Service.getSnapshot());broadcast("ACTIVE",nil);return true end
function Service.completeBoss():boolean if not run or run.state~="BOSS" or run.bossDead then return false end;run.bossDead=true;run.encounter=4;transition("COMPLETED");log("DUNGEON_COMPLETED",{runId=run.runId});broadcast("COMPLETED","РУИНЫ СЕЛЕНЫ ПРОЙДЕНЫ",{reward={xp=Config.CompletionXP,luna=Config.CompletionLuna,itemId=Config.CompletionItemId}});return true end
function Service.claimReward(player:Player):boolean if not run or run.state~="COMPLETED" or not run.memberSet[player.UserId] then return false end;local ok,nextClaims=Rules.claim(run.claimed,player.UserId);if not ok then return false end;run.claimed=nextClaims;Progression.awardXP(player,Config.CompletionXP);PlayerData.mutate(player,function(profile)profile.Luna+=Config.CompletionLuna end);Inventory.grantItem(player,Config.CompletionItemId,1);log("REWARD_CLAIMED",{runId=run.runId,userId=player.UserId});return true end
function Service.getSnapshot():any if not run then return nil end;return {runId=run.runId,state=run.state,encounter=run.encounter,bossDead=run.bossDead,leaderUserId=run.leaderUserId,participants=table.clone(run.participants),resetGeneration=run.resetGeneration}end
function Service.getContract():any return run and run.contract or nil end
function Service.isParticipant(player:Player):boolean return run~=nil and run.memberSet[player.UserId]==true end
function Service.start():()
	table.insert(connections,Players.PlayerRemoving:Connect(function(p)if not run or not run.memberSet[p.UserId]then return end;run.connected[p.UserId]=nil;run.alive[p.UserId]=nil;characterGraceUntil[p]=nil;if run.state=="ACTIVE" or run.state=="BOSS" then Store.putRejoin(p.UserId,{schemaVersion=Config.SchemaVersion,userId=p.UserId,runId=run.runId,state=run.state,accessCode=run.contract.accessCode,leaderUserId=run.leaderUserId,memberUserIds=run.participants,expiresAt=os.time()+Config.RejoinTtlSeconds});if Rules.allDead(run.participants,run.alive,run.connected)then run.resetGeneration+=1;log("PARTY_WIPE",{runId=run.runId,encounterId=run.encounter+1});wipe:Fire(run.encounter+1,run.resetGeneration)end end;wipeGeneration+=1 end))
	table.insert(connections,RunService.Heartbeat:Connect(function()
		if run==nil or (run.state~="ACTIVE" and run.state~="BOSS" and run.state~="COMPLETED")then return end
		for _,player in Players:GetPlayers()do
			if not run.memberSet[player.UserId] or os.clock()<(characterGraceUntil[player]or 0)then continue end
			local character=player.Character;local humanoid=if character then character:FindFirstChildOfClass("Humanoid")else nil;local rootPart=if character then character:FindFirstChild("HumanoidRootPart")else nil
			if character and humanoid and humanoid.Health>0 and rootPart and rootPart:IsA("BasePart")and not DungeonWorld.isWithinBounds(rootPart.Position)and not oobCharacters[character]then
				oobCharacters[character]=true;log("PLAYER_OUT_OF_BOUNDS",{runId=run.runId,userId=player.UserId});humanoid.Health=0
			end
		end
	end))
end
function Service.stop():()for _,c in connections do c:Disconnect()end;for _,c in characterConnections do c:Disconnect()end;for _,c in deathConnections do c:Disconnect()end;table.clear(connections);table.clear(characterConnections);table.clear(deathConnections);table.clear(characterGraceUntil);table.clear(oobCharacters);if run then log("RUN_CLOSED",{runId=run.runId})end;run=nil end
return Service
