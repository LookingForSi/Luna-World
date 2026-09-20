--!strict
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local NpcDefinitions=require(ReplicatedStorage.Shared.definitions.NpcDefinitions)
local WorldLayout=require(ReplicatedStorage.Shared.world.WorldLayout)
local QuestService=require(script.Parent.QuestService)
local EconomyNetworkService=require(script.Parent.EconomyNetworkService)
local service={}; local folder: Folder?=nil; local connections={}
local function position(id:string):Vector3 for _,p in WorldLayout.PointsOfInterest do if p.id==id then return p.position end end;error("Missing NPC POI "..id) end
local function makeModel(parent:Instance,definition:any):Model
	local world=workspace:FindFirstChild("LunaWorldPlayableBlockout"); local existing=if world then world:FindFirstChild(definition.modelName,true) else nil
	if existing and existing:IsA("Model") then return existing end
	local model=Instance.new("Model");model.Name=definition.modelName;model:SetAttribute("NpcId",definition.id)
	local body=Instance.new("Part");body.Name="Body";body.Anchored=true;body.Size=Vector3.new(2.5,5,2.5);body.Color=Color3.fromRGB(104,91,72);body.Position=position(definition.poiId)+(definition.positionOffset or Vector3.zero)+Vector3.new(0,2.5,0);body.Parent=model;model.PrimaryPart=body;model.Parent=parent;return model
end
function service.start():()
	if folder then return end;folder=Instance.new("Folder");folder.Name="NpcInteractions";folder.Parent=workspace
	for npcId,definition in NpcDefinitions do if definition.economy then continue end;local model=makeModel(folder,definition);model:SetAttribute("NpcId",npcId);local target=model:FindFirstChild("Head") or model:FindFirstChild("Body") or model.PrimaryPart;if not target then continue end
		local prompt=Instance.new("ProximityPrompt");prompt.Name="TalkPrompt";prompt.ActionText="Поговорить";prompt.ObjectText=definition.displayName;prompt.MaxActivationDistance=14;prompt.RequiresLineOfSight=false;prompt.KeyboardKeyCode=Enum.KeyCode.E;prompt.GamepadKeyCode=Enum.KeyCode.ButtonA;prompt.Parent=target
		table.insert(connections,prompt.Triggered:Connect(function(player) if definition.economy then EconomyNetworkService.openFor(player,definition.economy) else QuestService.openNpc(player,npcId) end end))
	end
end
function service.stop():() for _,c in connections do c:Disconnect() end;table.clear(connections);if folder then folder:Destroy();folder=nil end end
return service
