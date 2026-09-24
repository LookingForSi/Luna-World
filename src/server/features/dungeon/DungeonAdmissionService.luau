--!strict
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Rules=require(ReplicatedStorage.Shared.dungeon.DungeonHandoffRules)
local Store=require(script.Parent.DungeonHandoffStore)
local RunService=require(script.Parent.DungeonRunService)
local Service={}; local connection:RBXScriptConnection?=nil
local function admit(player:Player):()
	local data=player:GetJoinData().TeleportData; if typeof(data)~="table" or typeof(data.token)~="string" then player:Kick("Dungeon admission required"); return end
	local contract=Store.get(data.token); local ok=Rules.validate(contract,workspace:GetServerTimeNow(),"Dungeon",player.UserId)
	if not ok or data.runId~=contract.runId or data.schemaVersion~=contract.schemaVersion then player:Kick("Invalid or expired dungeon admission"); return end
	local admitted=RunService.admit(player,contract); if not admitted then player:Kick("Dungeon run rejected admission") end
end
function Service.start():() connection=Players.PlayerAdded:Connect(admit); for _,p in Players:GetPlayers() do task.spawn(admit,p) end end
function Service.stop():() if connection then connection:Disconnect(); connection=nil end end
return Service
