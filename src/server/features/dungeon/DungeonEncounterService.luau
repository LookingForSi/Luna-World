--!strict
local Players=game:GetService("Players")
local MobService=require(script.Parent.Parent.Parent.services.MobService)
local RunService=require(script.Parent.DungeonRunService)
local Service={}; local connections={}; local entityGroup:{[string]:number}={}; local remaining:{[number]:number}={}
local groups={
	{z=110,mobs={"selene_warden","selene_warden","selene_acolyte"}},
	{z=230,mobs={"ruin_sentinel"}},
	{z=350,mobs={"selene_warden","selene_acolyte","selene_acolyte"}},
	{z=470,mobs={"selenes_fallen_guardian"}},
}
local function openGate(index:number):() local root=workspace:FindFirstChild("RuinsOfSelene"); local gate=if root then root:FindFirstChild("AuthoritativeGate"..index) else nil; if gate then gate:Destroy() end end
function Service.start():()
	table.insert(connections,MobService.MobSpawned:Connect(function(model) local marker=model:GetAttribute("SpawnMarkerId"); local entity=model:GetAttribute("EntityId"); local group=if typeof(marker)=="string" then tonumber(string.match(marker,"selene_group_(%d+)")) else nil; if group and typeof(entity)=="string" then entityGroup[entity]=group end end))
	table.insert(connections,MobService.MobDied:Connect(function(_killer,_mobId,entityId) local group=entityGroup[entityId]; if not group or remaining[group]<=0 then return end; entityGroup[entityId]=nil; remaining[group]-=1; if remaining[group]==0 and RunService.recordEncounter(group) then if group<=3 then openGate(group) elseif RunService.completeBoss() then for _,player in Players:GetPlayers() do RunService.claimReward(player) end; local exit=workspace:FindFirstChild("RuinsOfSeleneExit",true); local prompt=if exit then exit:FindFirstChildOfClass("ProximityPrompt") else nil; if prompt then prompt.Enabled=true end end end end))
	for groupIndex,group in groups do remaining[groupIndex]=#group.mobs; for index,key in group.mobs do MobService.spawnConfigured(key,Vector3.new((index-2)*14,5,group.z),"selene_group_"..groupIndex,index) end end
end
function Service.stop():() for _,c in connections do c:Disconnect() end; table.clear(connections);table.clear(entityGroup);table.clear(remaining) end
return Service
