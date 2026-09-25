--!strict
local RunService=game:GetService("RunService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local PlaceRole=require(ReplicatedStorage.Shared.core.runtime.PlaceRole)
local DungeonTransfer=require(script.Parent.DungeonTransferService)
local DungeonWorld=require(script.Parent.DungeonWorldService)
local DungeonRun=require(script.Parent.DungeonRunService)
local Encounters=require(script.Parent.DungeonEncounterService)
local Diagnostics=require(script.Parent.DungeonDiagnostics)
local Service={};local active=false;local exitConnection:RBXScriptConnection?=nil
local function close():()if not active then return end;active=false;local destination=workspace:FindFirstChild("LunaVillageSpawn",true);Encounters.stop();DungeonRun.stop();DungeonWorld.stop();if destination and destination:IsA("BasePart")then for _,player in game:GetService("Players"):GetPlayers()do if player.Character then player.Character:PivotTo(destination.CFrame+Vector3.new(0,4,0))end end end;Diagnostics.event("RETURN_COMPLETED",{mode="DevCombined"})end
local function enter(_leader:Player,contract:any):()
	if active then return end;active=true;DungeonWorld.start();DungeonRun.start();for _,player in game:GetService("Players"):GetPlayers()do for _,id in contract.memberUserIds do if player.UserId==id then DungeonRun.admit(player,contract)end end end;Encounters.start();local exit=workspace:FindFirstChild("RuinsOfSeleneExit",true);local prompt=if exit then exit:FindFirstChildOfClass("ProximityPrompt")else nil;if prompt then exitConnection=prompt.Triggered:Connect(function(player)if DungeonRun.isParticipant(player)and DungeonRun.getSnapshot().state=="COMPLETED"then close()end end)end
end
function Service.start():()assert(RunService:IsStudio(),"DevCombined dungeon adapter is Studio-only");DungeonTransfer.setStudioHandler(enter)end
function Service.stop():()DungeonTransfer.setStudioHandler(nil);if exitConnection then exitConnection:Disconnect();exitConnection=nil end;close()end
return Service
