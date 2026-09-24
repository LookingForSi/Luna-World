--!strict
local CollectionService=game:GetService("CollectionService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Config=require(ReplicatedStorage.Shared.dungeon.DungeonConfig)
local RespawnConfig=require(ReplicatedStorage.Shared.config.RespawnConfig)
local Service={};local root:Folder?=nil
local function part(parent:Instance,name:string,size:Vector3,position:Vector3,color:Color3):Part local p=Instance.new("Part");p.Name=name;p.Size=size;p.Position=position;p.Anchored=true;p.Color=color;p.Parent=parent;return p end
function Service.start():()
	if workspace:FindFirstChild("RuinsOfSelene")then return end;root=Instance.new("Folder");root.Name="RuinsOfSelene";root.Parent=workspace;local stone=Color3.fromRGB(62,65,78)
	for i=0,4 do local z=i*120;part(root,"Floor"..i,Vector3.new(80,4,100),Vector3.new(0,-2,z),stone);part(root,"WallL"..i,Vector3.new(4,28,100),Vector3.new(-42,12,z),stone);part(root,"WallR"..i,Vector3.new(4,28,100),Vector3.new(42,12,z),stone)end
	for i=1,3 do local gate=part(root,"AuthoritativeGate"..i,Vector3.new(76,24,4),Vector3.new(0,10,i*120-60),Color3.fromRGB(80,55,95));gate:SetAttribute("EncounterGate",i)end
	for i,z in {0,70,190,310}do local cp=part(root,"Checkpoint"..(i-1),Vector3.new(10,1,10),Vector3.new(0,1,z),Color3.fromRGB(70,105,125));cp.Transparency=.5;cp.CanCollide=false;cp:SetAttribute(RespawnConfig.SettlementIdAttribute,"dungeon_selene");cp:SetAttribute(RespawnConfig.AnchorIdAttribute,"selene_checkpoint_"..(i-1));CollectionService:AddTag(cp,RespawnConfig.AnchorTag)end
	local spawn=Instance.new("SpawnLocation");spawn.Name="DungeonEntranceSpawn";spawn.Size=Vector3.new(10,1,10);spawn.Position=Vector3.new(0,1,0);spawn.Anchored=true;spawn.Neutral=true;spawn.Parent=root
	local exit=part(root,Config.ExitPromptName,Vector3.new(12,1,12),Vector3.new(0,1,490),Color3.fromRGB(90,120,150));local prompt=Instance.new("ProximityPrompt");prompt.ActionText="Вернуться в Moonfall";prompt.ObjectText="Выход";prompt.Enabled=false;prompt.MaxActivationDistance=12;prompt.Parent=exit
end
function Service.stop():()if root then root:Destroy();root=nil end end
return Service
